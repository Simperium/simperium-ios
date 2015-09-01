Pod::Spec.new do |s|
  s.name         = "Simperium-OSX"
  s.version      = File.read("Simperium/SPEnvironment.m").split("NSString* const SPLibraryVersion = @\"").last.split("\"").first
  s.summary      = "Simperium libraries."
  s.description  = "Simperium is a simple way for developers to move data as it changes, instantly and automatically."
  s.homepage     = "https://github.com/Simperium/simperium-ios"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { "Simperium" => "contact@simperium.com" }

  # Sources
  #
  s.source     = { :git => "https://github.com/Simperium/simperium-ios.git", :tag => "v" << s.version.to_s }
  s.osx.deployment_target = '10.8'
  s.source_files = 'Simperium/*.{h,m}', 'Simperium-OSX/**/*.{h,m}', 'External/JRSwizzle/*', 'External/SPReachability/*', 'External/SocketRocket/*', 'External/SSKeychain/*'
  s.exclude_files = 'Simperium/SPAuthenticationViewController.{h,m}', 'Simperium/SPWebViewController.{h,m}', 'Simperium/SPAuthenticationButton.{h,m}'

  # Required by SocketRocket
  s.libraries = "icucore"
  s.requires_arc = true

  # Dependencies
  #
  s.dependency 'Google-Diff-Match-Patch'
end
