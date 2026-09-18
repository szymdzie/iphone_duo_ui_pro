#
# Run `pod lib lint iphone_duo_ui_pro.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'iphone_duo_ui_pro'
  s.version          = '0.1.1'
  s.summary          = 'Fold-aware Flutter widgets for iPhone Duo.'
  s.description      = <<-DESC
Native bridge that reports iPhone Duo reserved regions, hinge state, UIKit size
classes and the vertical bar edge to Flutter.
                       DESC
  s.homepage         = 'https://github.com/szymdzie/iphone_duo_ui_pro'
  s.license          = { :file => '../LICENSE' }
  s.author           = 'Szymon Dziedzic'
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'

  # iPhone Duo APIs ship with the iOS 27.1 SDK. Until every build machine has
  # Xcode 27.1, those call sites stay behind the DUO_SDK_27_1 flag — see README.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
