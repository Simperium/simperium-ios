$:.unshift(File.join(File.dirname(__FILE__), 'lib'))

require 'simperium/version'

spec = Gem::Specification.new do |s|
  s.name = 'simperium'
  s.version = Simperium::VERSION
  s.summary = 'Ruby bindings for the Simperium API'
  s.description = 'Simperium moves data instantly and automatically everywhere it\'s needed.  See https://simperium.com for details.'
  s.authors = ['Ray Ventura']
  s.email = ['ray@simperium.com']
  s.homepage = 'https://simperium.com/docs/reference'
  s.require_paths = %w{lib}

  s.add_dependency('rest-client', '~> 1.4')
  s.add_dependency('uuid')
  s.add_dependency('json')
  
  s.files = `git ls-files`.split("\n")
  s.require_paths = ['lib']
end