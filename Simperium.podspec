Pod::Spec.new do |s|
  s.name         = "Simperium"
  s.version      = "0.5.0"
  s.summary      = "Simperium framework"
  s.homepage     = "https://github.com/Simperium/simperium-ios"
  s.author       = { "Simperium" => "contact@simperium.com" }

  s.source       = { :git => "https://github.com/Simperium/simperium-ios.git", :tag => "v{s.version}" }

  s.ios.deployment_target = '5.0'
  s.osx.deployment_target = '10.7'
  
  s.source_files = 'Classes/*.{h,m}' , 'External/**/*.{h,m}'
  s.exclude_files = 'External/Reachability/SPReachability.*'
  s.osx.source_files = 'Classes/OSX/*.{h,m}'
  s.ios.source_files = 'Classes/iOS/*.{h,m}'

  s.ios.exclude_files = 'External/OSX/*'
  s.osx.exclude_files = 'External/iOS/*'
  
  # s.public_header_files = 'Classes/**/*.h'

  s.resources = 'Resources/*'
  s.ios.resources = 'Resources/iOS/*'
  s.osx.resources = 'Resources/OSX/*'




  s.requires_arc = true
  s.compiler_flags = '-DOS_OBJECT_USE_OBJC=0'

  s.subspec 'noarc' do |subs|
    subs.source_files = 'External/Reachability/SPReachability.*'
    subs.requires_arc = false
  end

  # If you need to specify any other build settings, add them to the
  # xcconfig hash.
  #
  # s.xcconfig = { 'HEADER_SEARCH_PATHS' => '$(SDKROOT)/usr/include/libxml2' }

  s.dependency 'JRSwizzle'
  s.dependency 'ASIHTTPRequest', '~> 1.8.1'
  s.dependency 'JSONKit'
  s.dependency 'CocoaLumberjack'
  s.dependency 'Google-Diff-Match-Patch'
  s.dependency 'SocketRocket'

end


