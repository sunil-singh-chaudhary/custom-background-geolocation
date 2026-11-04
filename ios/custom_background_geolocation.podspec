Pod::Spec.new do |s|
  s.name             = 'custom_background_geolocation'
  s.version          = '1.0.1'
  s.summary          = 'Production-grade native background geolocation and geofencing engine.'
  s.description      = 'Zero-drain background geolocation and geofencing engine for Flutter with offline SQLite buffer.'
  s.homepage         = 'https://github.com/sunil-singh-chaudhary/custom-background-geolocation'
  s.license          = { :type => 'MIT' }
  s.author           = { 'esimrights.in' => 'contact@esimrights.in' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version    = '5.0'
  s.frameworks       = 'CoreLocation', 'CoreMotion', 'Network'
  s.libraries        = 'sqlite3'
end
