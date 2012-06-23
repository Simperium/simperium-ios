require 'rubygems'
require 'test/unit'
require 'uuid'
require 'simperium'

@@api_key = ENV['SIMPERIUM_CLIENT_TEST_APIKEY']
@@appname = ENV['SIMPERIUM_CLIENT_TEST_APPNAME']

# cache user create to cut down on the number of users created by the test suite
@@_auth_token = nil
def get_auth_token
    if @@_auth_token.nil?
        auth = Simperium::Auth.new(@@appname, @@api_key)
        uuid = UUID.new
        username = uuid.generate(:compact) + '@foo.com'
        password = uuid.generate(:compact)
        @@_auth_token = auth.create(username, password)
    end
    return @@_auth_token
end

class TestSimperiumRuby < Test::Unit::TestCase
    def test_auth_create
        get_auth_token
    end

    def test_bucket_get
        uuid = UUID.new
        bucket = Simperium::Bucket.new(@@appname, get_auth_token, uuid.generate(:compact))
        bucket.post('item1', {'x'=> 1})
        assert_equal(bucket.get('item1'), {'x' => 1})
    end

    def test_bucket_index
        uuid = UUID.new
        bucket = Simperium::Bucket.new(@@appname, get_auth_token, uuid.generate(:compact))
        (0..2).each { |i| bucket.post("item#{i}", {'x' => i}) }
        
        got = bucket.index(:data=>false,  :mark=>nil, :limit=>2, :since=>nil)
        want = {
            'current' => got['current'],
            'mark' => got['mark'],
            'index' => [
                {'id' => 'item2', 'v' => 1},
                {'id' => 'item1', 'v' => 1}] }
        assert_equal(want, got)

        got2 = bucket.index(:data=>false, :mark=>got['mark'], :limit=>2, :since=>nil)
        want2 = {
            'current'=> got['current'],
            'index' => [
                {'id' => 'item0', 'v' => 1}] }
    end

    def test_bucket_post
        uuid = UUID.new
        bucket = Simperium::Bucket.new(@@appname, get_auth_token, uuid.generate(:compact))
        bucket.post('item1', {'a'=>1})
        assert_equal(bucket.get('item1'), {'a'=>1})

        bucket.post('item1', {'b'=>2})
        assert_equal(bucket.get('item1'), {'a'=>1, 'b'=>2})

        bucket.post('item1', {'c'=>3}, :replace=>true)
        assert_equal(bucket.get('item1'), {'c'=>3})
    end

    def test_user_get
        user = Simperium::SPUser.new(@@appname, get_auth_token)
        user.post({'x'=> 1})
        assert_equal(user.get, {'x'=> 1})
    end

    def test_api_getitem
        api = Simperium::Api.new(@@appname, get_auth_token)
        assert_instance_of(Simperium::Bucket, api['bucket'], "api[bucket] should be an instance of Bucket")
    end

    def test_api_getattr
        api = Simperium::Api.new(@@appname, get_auth_token)
        assert_instance_of(Simperium::Bucket, api.bucket, "api.bucket should be an instance of Bucket")
    end

    def test_api_user
        api = Simperium::Api.new(@@appname, get_auth_token)
        assert_instance_of(Simperium::SPUser, api.spuser, "api.user should be an instance of User")
    end
end
