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
  s.source_files = 'Simperium/*.{h,m}', 'Simperium-OSX/**/*.{h,m}'
  s.exclude_files = 'Simperium/SPAuthenticationViewController.{h,m}', 'Simperium/SPWebViewController.{h,m}', 'Simperium/SPAuthenticationButton.{h,m}', 'Simperium/UIDevice+Simperium.{h,m}', 'Simperium/UIViewController+Simperium.{h,m}'

  # Settings
  s.requires_arc = true

  # Subspecs: DiffMatchPatch
  s.subspec "DiffMatchPach" do |dmp|
    dmp.source_files = "External/diffmatchpatch/*.{h,c,m}"
    dmp.requires_arc = false
    dmp.compiler_flags = '-fno-objc-arc'
  end

  # Subspecs: JRSwizzle
  s.subspec "JRSwizzle" do |jrs|
    jrs.source_files = "External/jrswizzle/*.{h,m}"
  end

  # Subspecs: SocketRocket
  s.subspec "SocketRocket" do |sr|
    sr.source_files = "External/SocketRocket/*.{h,m}"
    sr.libraries = "icucore"
  end

  # Subspecs: SPReachability
  s.subspec "SPReachability" do |spr|
    spr.source_files = "External/SPReachability/*.{h,m}"
  end

  # Subspecs: SSKeychain
  s.subspec "SSKeychain" do |ssk|
    ssk.source_files = "External/SSKeychain/*.{h,m}"
  end
end
