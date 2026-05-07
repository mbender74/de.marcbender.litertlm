Pod::Spec.new do |s|

    s.name         = "TitaniumLiteRTLM"
    s.version      = "1.0.0"
    s.summary      = "Titanium module for LiteRTLM - On-device LLM inference."

    s.description  = <<-DESC
                     The TitaniumLiteRTLM Titanium module provides full access to the
                     Google LiteRTLM SDK for on-device large language model inference
                     on iOS devices.
                     DESC

    s.homepage     = "https://github.com/marcbender/TitaniumLiteRTLM"
    s.license      = { :type => "Apache 2.0", :file => "LICENSE" }
    s.author       = 'Marc Bender'

    s.platform     = :ios
    s.ios.deployment_target = '13.0'

    s.source       = { :git => "", :path => "." }

    s.ios.weak_frameworks = 'UIKit', 'Foundation'

    s.ios.dependency 'TitaniumKit'

    s.public_header_files = 'Classes/*.h'
    s.source_files = 'Classes/*.{h,m,swift}'

    # Add the XCFramework to the pod
    s.vendored_frameworks = 'platform/LiteRTLM.xcframework'

    # Swift version
    s.swift_version = '5.0'
end
