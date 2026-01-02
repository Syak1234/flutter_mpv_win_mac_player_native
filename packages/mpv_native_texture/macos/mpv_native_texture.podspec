#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint mpv_native_texture.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'mpv_native_texture'
  s.version          = '0.0.1'
  s.summary          = 'MPV native texture player for Flutter macOS'
  s.description      = <<-DESC
MPV-based video player using native textures for Flutter macOS applications.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.14'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.compiler_flags = '-I/usr/local/include -I/opt/homebrew/include'
  s.swift_version = '5.0'
  s.frameworks = 'OpenGL', 'CoreVideo', 'AppKit', 'Cocoa', 'IOSurface'
  s.vendored_libraries = Dir.glob('Libs/*.dylib')
end
