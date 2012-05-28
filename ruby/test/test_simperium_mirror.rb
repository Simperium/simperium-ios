require 'test/unit'
require File.expand_path('../../lib/simperium/listener-mirror', __FILE__)

@admin_key = ENV['SIMPERIUM_CLIENT_TEST_ADMINKEY']
@appname = ENV['SIMPERIUM_CLIENT_TEST_APPNAME']

class TestMirror < Test::Unit::TestCase
	def test_simperium_mirror
		Listener::mirror(@appname, @admin_key, 'todo')
	end
end
