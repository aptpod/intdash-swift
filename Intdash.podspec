Pod::Spec.new do |spec|
spec.name         = "Intdash"
  spec.version      = "1.0.0"
  spec.summary      = "intdash SDK for Swift"
  spec.homepage     = "https://github.com/aptpod/intdash-swift"
  spec.documentation_url = "https://docs.intdash.jp/sdk/swift/v#{spec.version}" 

  spec.license      = { :type => "Apache License, Version 2.0", :file => "LICENSE" }
  spec.author       = { "aptpod" => "ueno@aptpod.co.jp" }

  spec.ios.deployment_target = "12.0"
  spec.osx.deployment_target = "10.10"
  spec.source       = { :git => "https://github.com/aptpod/intdash-swift.git", :tag => "v#{spec.version}" }

  spec.vendored_frameworks = "Intdash.xcframework"
  spec.requires_arc = true
  spec.swift_version  = "4.0"

end
