# react-native-rsa-turbo.podspec
require 'json'
package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name          = package['name']                      # "react-native-rsa-turbo"
  s.version       = package['version']                   # "0.1.4"
  s.summary       = package['description'] || "RSA TurboModule for React Native"
  s.homepage      = package['homepage'] || package.dig('repository','url')
  s.license       = package['license'] || "MIT"
  s.author        = package['author'] || { "Author" => "info@example.com" }
  s.source        = { :git => package.dig('repository','url'), :tag => "v#{s.version}" }

  s.platforms     = { :ios => "12.0" }
  s.requires_arc  = true
  s.static_framework = true

  # iOS sources
  s.source_files  = "ios/**/*.{h,m,mm}"

  # C++ (nếu dùng .mm) – an toàn để bật C++17
  s.pod_target_xcconfig = {
    "CLANG_CXX_LANGUAGE_STANDARD" => "c++17",
    "CLANG_CXX_LIBRARY" => "libc++"
  }

  # RN core
  s.dependency "React-Core"

  # Hỗ trợ New Architecture (TurboModule) khi app bật RCT_NEW_ARCH_ENABLED=1
  if ENV['RCT_NEW_ARCH_ENABLED'] == '1'
    s.compiler_flags = "-DRCT_NEW_ARCH_ENABLED=1"
  s.pod_target_xcconfig = {
  "HEADER_SEARCH_PATHS" => "$(PODS_ROOT)/Headers/Public/React-Codegen"
}

    s.dependency "React-Codegen"
    s.dependency "FBReactNativeSpec"
    s.dependency "RCTRequired"
    s.dependency "RCTTypeSafety"
    s.dependency "ReactCommon/turbomodule/core"
    s.dependency "ReactCommon/turbomodule/bridging"
    s.dependency "React-jsi"
  end
end
