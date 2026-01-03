# TODO List - mpv_native_texture Unified API

## Task: Create unified MpvNativeTextureController for Windows & macOS

### Steps:
1. [x] Analyze the codebase and understand the current structure
2. [x] Create unified `MpvNativeTextureController` class
3. [x] Create unified `MpvNativeTextureView` widget  
4. [x] Update `main.dart` to use the unified API
5. [ ] Rebuild and test

### Completed Changes:
- Created `packages/mpv_native_texture/lib/mpv_native_texture.dart` with unified API
- Updated `lib/main.dart` to use `MpvNativeTextureController` and `MpvNativeTextureView`
- mpv-2.dll is already present in `packages/mpv_native_texture/windows/third_party/mpv/bin/`
- All required macOS dylibs (71 files) are present in `packages/mpv_native_texture/macos/Libs/`

### Next Steps:
1. [x] Run `flutter clean`
2. [x] Run `flutter pub get`
3. [x] Run `flutter build windows --debug`
4. [x] Build succeeded!

### Usage:
Now you can use the unified API:
```dart
import 'package:mpv_native_texture/mpv_native_texture.dart';

// Create controller (works on both Windows and macOS)
final controller = await MpvNativeTextureController.create();

// Display video
MpvNativeTextureView(controller: controller)
```

