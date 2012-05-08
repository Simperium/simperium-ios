Introduction
============
Welcome to the python client for simperium!

Using the python client you'll be able to add useful server side components to
your simperium applications.  You can think of these components as lego blocks.
Each component can listen to the change stream passing through your application,
and then perform actions as appropriate.  For example, a component could
send push notifications when new documents are created or changed.  Components
can even potentially introduce new changes, which are then fed to other
components.

Getting started
===============
To get started, first log into [https://simperium.com](https://simperium.com) and
create a new application.  Copy down the new app's name, api key and admin key.

Next install the python client:

    $ sudo pip install simperium

Start python and import the lib:

    $ python
    >>> from simperium.core import Auth, Api

We'll need to create a user to be able to store data:

    >>> auth = Auth(yourappname, yourapikey)
    >>> token = auth.create('joe@example.com', 'secret')
    >>> token
    '25c11ad089dd4c18b84f24bc18c58fe2'

We can now store and retrieve data from simperium.  Data is stored in buckets.
For example, we could store a list of todo items in a todo bucket.  When you
store items, you need to give them a unique identifier.  Uuids are usually a
good choice.

    >>> import uuid
    >>> api = Api(yourappname, token)
    >>> todo1_id = uuid.uuid4().hex
    >>> api.todo.post(todo1_id,
                      {'text': 'Read general theory of love', 'done': False})

We can retrieve this item:

    >>> api.todo.get(todo1_id)
    {'text': 'Read general theory of love', 'done': False}

Store another todo:

    >>> api.todo.post(uuid.uuid4().hex,
                      {'text': 'Watch battle royale', 'done': False})

You can retrieve an index of all of a buckets items:

    >>> api.todo.index()
    {
        'count': 2,
        'index': [
            {'id': 'f6b680f8504c4e31a0e54a95401ffca0', 'v': 1},
            {'id': 'c0d07bb7c46e48e693653425eca93af9', 'v': 1}],
        'current': '4f8507b8faf44720dfc432b1',}

Retrieve all the docuemnts in the index:

    >>> [api.todo.get(x['id'] for x in api.todo.index()['index']]
    [
        {'text': 'Read general theory of love', 'done': False},
        {'text': 'Watch battle royale', 'done': False}]

It's also possible to get the data for each document in the index with data=True:

    >>> api.todo.index(data=True)
    {
        'count': 2,
        'index': [
            {'id': 'f6b680f8504c4e31a0e54a95401ffca0', 'v': 1,
                'd': {'text': 'Read general theory of love', 'done': False},},
            {'id': 'c0d07bb7c46e48e693653425eca93af9', 'v': 1,
                'd': {'text': 'Watch battle royale', 'done': False},}],
        'current': '4f8507b8faf44720dfc432b1'}

To update fields in an item, post the updated fields.  They'll be merged
with the current document:

    >>> api.todo.post(todo1_id, {'done': True})
    >>> api.todo.get(todo1_id)
    {'text': 'Read general theory of love', 'done': True}

Simperium items are versioned.  It's possible to go back in time and retrieve
previous versions of documents:

    >>> api.todo.get(todo1_id, version=1)
    {'text': 'Read general theory of love', 'done': False}

Of course, you can delete items:

    >>> api.todo.delete(todo1_id)
    >>> api.todo.get(todo1_id) == None
    True
    >>> api.todo.index()['count']
    1

Leave this shell session running.  We'll use it in the next section to generate
changes.

A basic global listener
=======================
Now let's play with a basic global listener, which will be able to hear all
changes passing through your application.

Open a new window and grab a copy of the example basic listener:

    $ curl -O https://raw.github.com/Simperium/simperium-python/master/examples/listener-basic
    $ chmod +x ./listener-basic
    $ ./listener-basic
    usage: ./listener-basic <appname> <admin_key> <bucket>

Run the listener using your admin key you made a copy of before:

    $ ./listener-basic yourappname youradminkey todo

Note that a number of changes are immediately shown. These are the changes that
were generated as you were working through the last section.  Now that the
listener has caught up with the latest change, it pauses until more changes are
injected into the system.

Let's generate a new change:

    >>> api.todo.post(uuid.uuid4().hex,
                      {'text': 'Create a startup to kill email', 'done': False})

You should see a change similiar to the following on the basic listener:

    {'ccid': 'a59be5364ba6419b9fff39ef307baa01', 'o': 'M', 'cv':
    '4f851105faf44720dfc4ce51', 'clientid': 'python-client', 'ev': 1, 'id':
    'feee427e66f8edebc8e30d1fbe1f4a81/ce0f1a6d96de434eaba1940c8b8568a3', 'd':
    {'text': 'Create a startup to kill email', 'done': False}}
    ---

Check out the listener-push-notifications example to see how to send push
notifications from a listener.  You can do anything you like here though. You
could maintain a local mirror of your data in elastic search for high
performance searching, send emails as a result of changes, access your user's
data to track premium upgrades, maintain game state.  One of our favorite uses
is maintaining a blog based on changes to notes in your simperium powered
Simplenote account. (link to simpleblog demo).

The possibilities are endless.  

Deploying a global listener to heroku
=====================================
Global listeners are small bite sized components that you can assemble like
lego blocks.  We find heroku's adhoc deployment infrastructure perfect for
deploying these components in a robust, cost effective way, that will easily scale
up as required.

If you haven't already, sign up for a heroku account, and follow the instructions for
Prerequisites and Local Workstation Setup here:
[https://devcenter.heroku.com/articles/python](https://devcenter.heroku.com/articles/python).

In order to be able to deploy to heroku, we need to store the listener in git.
Create the directory to use for the git repo:

    $ mkdir hellosimperium && cd hellosimperium

Create a Virtualenv (v0.7):

    $ virtualenv venv --distribute
    New python executable in venv/bin/python
    Installing distribute...............done.
    Installing pip...............done.

To activate the new environment, you'll need to source it:

    $ source venv/bin/activate

Let heroku know we need a copy of the simperium python client:

    $ echo git+https://github.com/Simperium/simperium-python.git > requirements.txt

Re-grab a copy of the example basic global listener:

    $ curl -O https://raw.github.com/Simperium/simperium-python/master/examples/listener-basic

Create the Procfile to tell heroku how to run the global listener. Note
yourappname and youradminkey are the same as you used in the previous section:

    $ echo "worker: python listener-basic yourappname youradminkey todo" > Procfile

Create a .gitignore file to exclude Virtualenv artifacts from source control
tracking:

    $ echo -e "venv\n*.pyc" > .gitignore

Let's put it into Git:

    $ git init
    $ git status

You should see:

    # Untracked files:
    #   (use "git add <file>..." to include in what will be committed)
    #
    #       .gitignore
    #       Procfile
    #       listener-basic
    #       requirements.txt

Commit!

    $ git add .
    $ git commit -m "initial"

Create the heroku app on the Cedar stack:

    $ heroku create --stack cedar
    Creating stark-window-524... done, stack is cedar
    http://stark-window-524.herokuapp.com/ | git@heroku.com:stark-window-524.git
    Git remote heroku added

Deploy your code:

    $ git push heroku master

Spin up a worker to run your global listener:

    $ heroku scale worker=1
    Scaling worker processes... done, now running 1

Let's check the state of the app's processes:

    $ heroku ps
    Process       State               Command
    ------------  ------------------  ------------------------------
    worker.1      up for 10s          python listener-basic lent-credit-..

Tail the logs:

    $ heroku logs --tail

Again you should see all of the changes you've made to date. Try experimenting
with creating, changing and removing a few more items in the console, and watch
the changes pass through the heroku logs.
