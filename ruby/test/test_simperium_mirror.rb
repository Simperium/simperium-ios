require 'test/unit'
require 'simperium/listener-export-mongohq'

@admin_key = ENV['SIMPERIUM_CLIENT_TEST_ADMINKEY']
@appname = ENV['SIMPERIUM_CLIENT_TEST_APPNAME']

class TestMirror < Test::Unit::TestCase
	def test_simperium_mirror
		Listener::mirror(@appname, @admin_key, 'todo')
	end
end
