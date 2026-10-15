#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint hardware_triggers.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'hardware_triggers'
  s.version          = '0.0.1'
  s.summary          = 'Physical key Triggers as Input Events, Press Patterns and bound actions.'
  s.description      = <<-DESC
Bluetooth shutter buttons, keyboard-mode remotes and volume rockers as a stream of key events with press pattern recognition and app-defined bindings.
                       DESC
  s.homepage         = 'https://github.com/ceesjannolen/hardware_triggers'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Cees-Jan Nolen' => 'ceesjannolen@live.nl' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.frameworks = 'AVFoundation', 'MediaPlayer'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'hardware_triggers_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
