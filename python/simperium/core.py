import os
import uuid
import urllib
import urllib2
import httplib
import json


class Auth(object):
    """
    example use:

        >>> from simperium.core import Auth
        >>> auth = Auth('myapp', 'cbbae31841ac4d44a93cd82081a5b74f')
        >>> Auth.create('john@company.com', 'secret123')
        'db3d2a64abf711e0b63012313d001a3b'
    """
    def __init__(self, appname, api_key, host=None, scheme='https'):
        if not host:
            host = os.environ.get('SIMPERIUM_AUTHHOST', 'auth.simperium.com')
        self.appname = appname
        self.api_key = api_key
        self.host = host
        self.scheme = scheme

    def _request(self, url, data=None, headers=None, method=None):
        url = '%s://%s/1/%s' % (self.scheme, self.host, url)
        if not headers:
            headers = {}
        if data:
            data = urllib.urlencode(data)
        request = urllib2.Request(url, data, headers=headers)
        if method:
            request.get_method = lambda: method
        response = urllib2.urlopen(request)
        return response

    def create(self, username, password):
        data = {
            'client_id': self.api_key,
            'username': username,
            'password': password, }
        try:
            response = self._request(self.appname+'/create/', data)
            return json.loads(response.read())['access_token']
        except urllib2.HTTPError:
            return None

    def authorize(self, username, password):
        data = {
            'client_id': self.api_key,
            'username': username,
            'password': password, }
        response = self._request(self.appname+'/authorize/', data)
        return json.loads(response.read())['access_token']


class Bucket(object):
    """
    example use:

        >>> from simperium.core import Bucket
        >>> bucket = Bucket('myapp', 'db3d2a64abf711e0b63012313d001a3b', 'mybucket')
        >>> bucket.set('item2', {'age': 23})
        True
        >>> bucket.set('item2', {'age': 25})
        True
        >>> bucket.get('item2')
        {'age': 25}
        >>> bucket.get('item2', version=1)
        {'age': 23}
    """
    def __init__(self, appname, auth_token, bucket,
            userid=None,
            host=None,
            scheme='https',
            clientid=None):

        if not host:
            host = os.environ.get('SIMPERIUM_APIHOST', 'api.simperium.com')

        self.userid = userid
        self.host = host
        self.scheme = scheme
        self.appname = appname
        self.bucket = bucket
        self.auth_token = auth_token
        if clientid:
            self.clientid = clientid
        else:
            self.clientid = 'py-%s' % uuid.uuid4().hex

    def _auth_header(self):
        headers = {'Authorization': 'BEARER %s' % self.auth_token}
        if self.userid:
            headers['X-Simperium-User'] = self.userid
        return headers

    def _gen_ccid(self):
        return uuid.uuid4().hex

    def _request(self, url, data=None, headers=None, method=None, timeout=None):
        url = '%s://%s/1/%s' % (self.scheme, self.host, url)
        if not headers:
            headers = {}
        request = urllib2.Request(url, data, headers=headers)
        if method:
            request.get_method = lambda: method
        response = urllib2.urlopen(request, timeout=timeout)
        return response

    def index(self, data=False, mark=None, limit=None, since=None):
        """
        retrieve a page of the latest versions of a buckets documents
        ordered by most the most recently modified.

        @mark:    mark the documents returned to be modified after the
                  given cv
        @limit:   limit page size to this number.  max 1000, default 100.
        @since:   limit page to documents changed since the given cv.
        @data:    include the current data state of each  document in the
                  result. by default data is not included.

        returns: {
            'current':  head cv of the most recently modified document,
            'mark':     cv to use to pull the next page of documents. only
                        included in the repsonse if there are remaining pages
                        to fetch.
            'count':    the total count of documents available,

            'index': [{
                'id':  id of the document,
                'v:    current version of the document,
                'd':   optionally current data of the document, if
                       data is requested
                }, {....}],
            }
        """
        url = '%s/%s/index' % (self.appname, self.bucket)

        args = {}
        if data:
            args['data'] = '1'
        if mark:
            args['mark'] = str(mark)
        if limit:
            args['limit'] = str(limit)
        if since:
            args['since'] = str(since)
        args = urllib.urlencode(args)
        url += '?'+args

        response = self._request(url, headers=self._auth_header())
        return json.loads(response.read())

    def get(self, item, default=None, version=None):
        """retrieves either the latest version of item from this bucket, or the
            specific version requested"""
        url = '%s/%s/item/%s' % (self.appname, self.bucket, item)
        if version:
            url += '/%s' % version
        try:
            response = self._request(url, headers=self._auth_header())
        except urllib2.HTTPError, e:
            if getattr(e, 'code') == 404:
                return default
            raise

        return json.loads(response.read())

    def post(self, item, data, version=None, ccid=None, include_response=False):
        """posts the supplied data to item

            returns a unique change id on success, or None, if the post was not
            successful
        """
        if not ccid:
            ccid = self._gen_ccid()
        url = '%s/%s/item/%s' % (self.appname, self.bucket, item)
        if version:
            url += '/%s' % version
        url += '?clientid=%s&ccid=%s' % (self.clientid, ccid)
        if include_response:
            url += '&response=1'
        data = json.dumps(data)
        try:
            response = self._request(url, data, headers=self._auth_header())
        except urllib2.HTTPError:
            return None
        if include_response:
            return item, json.loads(response.read())
        else:
            return item

    def new(self, data, ccid=None):
        return self.post(uuid.uuid4().hex, data, ccid=ccid)

    def set(self, item, data, **kw):
        return self.post(item, data, **kw)

    def delete(self, item, version=None):
        """deletes the item from bucket"""
        ccid = self._gen_ccid()
        url = '%s/%s/item/%s' % (self.appname, self.bucket, item)
        if version:
            url += '/%s' % version
        url += '?clientid=%s&ccid=%s' % (self.clientid, ccid)
        response = self._request(url, headers=self._auth_header(), method='DELETE')
        if not response.read().strip():
            return ccid

    def changes(self, cv=None, timeout=None):
        """retrieves updates for this bucket for this user

            @cv: if supplied only updates that occurred after this
                change version are retrieved.

            @timeout: the call will wait for updates if not are immediately
                available.  by default it will wait indefinately.  if a timeout
                is supplied an empty list will be return if no updates are made
                before the timeout is reached.
        """
        url = '%s/%s/changes?clientid=%s' % (
            self.appname, self.bucket, self.clientid)
        if cv is not None:
            url += '&cv=%s' % cv
        headers = self._auth_header()
        try:
            response = self._request(url, headers=headers, timeout=timeout)
        except urllib2.URLError, e:
            if 'timed out' in str(e) or 'Connection refused' in str(e) or \
                    getattr(e, 'code', None) == 504:
                return []
            raise
        except httplib.BadStatusLine:
            return []
        return json.loads(response.read())

    def all(self, cv=None, data=False, username=False, most_recent=False, timeout=None):
        """retrieves *all* updates for this bucket, regardless of the user
            which made the update.

            @cv: if supplied only updates that occurred after this
                change version are retrieved.

            @data: if True, also include the lastest version of the data for
                changed entity

            @username: if True, also include the username that created the
                change

            @most_recent: if True, then only the most recent change for each
                document in the current page will be returned. e.g. if a
                document has been recently changed 3 times, only the latest of
                those 3 changes will be returned.

            @timeout: the call will wait for updates if not are immediately
                available.  by default it will wait indefinately.  if a timeout
                is supplied an empty list will be return if no updates are made
                before the timeout is reached.
        """
        url = '%s/%s/all?clientid=%s' % (
            self.appname, self.bucket, self.clientid)
        if cv is not None:
            url += '&cv=%s' % cv
        if username:
            url += '&username=1'
        if data:
            url += '&data=1'
        if most_recent:
            url += '&most_recent=1'
        headers = self._auth_header()
        try:
            response = self._request(url, headers=headers, timeout=timeout)
        except urllib2.URLError, e:
            if 'timed out' in str(e) or 'Connection refused' in str(e) or \
                    getattr(e, 'code', None) == 504:
                return []
            raise
        except httplib.BadStatusLine:
            return []
        return json.loads(response.read())


class User(object):
    """
    example use:

        >>> from simperium.core import User
        >>> user = User('myapp', 'db3d2a64abf711e0b63012313d001a3b')
        >>> bucket.post({'age': 23})
        True
        >>> bucket.get()
        {'age': 23}
    """
    def __init__(self, appname, auth_token,
            host=None,
            scheme='https',
            clientid=None):

        self.bucket = Bucket(appname, auth_token, 'user',
            host=host,
            scheme=scheme,
            clientid=clientid)

        url = '%s/%s' % (appname, 'user')
        response = self.bucket._request(url, headers=self.bucket._auth_header())
        response = json.loads(response.read())
        self.userid = response['userid']

    def get(self):
        return self.bucket.get(self.userid)

    def post(self, data):
        self.bucket.post(self.userid, data)


class Api(object):
    def __init__(self, appname, auth_token, **kw):
        self.appname = appname
        self.token = auth_token
        self._kw = kw

    def __getattr__(self, name):
        return Api.__getitem__(self, name)

    def __getitem__(self, name):
        if name == 'user':
            return User(self.appname, self.token, **self._kw)
        return Bucket(self.appname, self.token, name, **self._kw)


class Admin(Api):
    def __init__(self, appname, admin_token, **kw):
        self.appname = appname
        self.token = admin_token
        self._kw = kw

    def as_user(self, userid):
        return Api(self.appname, self.token, userid=userid, **self._kw)
