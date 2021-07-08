Pod::Spec.new do |spec|
spec.name         = "Intdash"
  spec.version      = "1.1.2"
  spec.summary      = "intdash SDK for Swift"
  spec.homepage     = "https://github.com/aptpod/intdash-swift"

  spec.license      = { :type => "Apache License, Version 2.0" }
  spec.author       = { "aptpod" => "ueno@aptpod.co.jp" }

  spec.ios.deployment_target = "12.0"
  spec.osx.deployment_target = "10.10"
  spec.source       = { :git => "https://github.com/aptpod/intdash-swift.git", :tag => "v#{spec.version}" }

  spec.vendored_frameworks = "Intdash.xcframework"
  spec.requires_arc = true

end
