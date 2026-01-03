# mpv_native_texture (macOS)

This folder contains the macOS native implementation for the `mpv_native_texture` plugin.

## Setup Instructions

To use this plugin on macOS, you need the `libmpv` shared library. You have two options for installation:

### Option 1: Install via Homebrew (Recommended)

Installing via Homebrew is the easiest way to manage dependencies.

```bash
brew install mpv
```

The build system will automatically look for `libmpv` in common Homebrew paths (e.g., `/usr/local/lib` or `/opt/homebrew/lib`).

### Option 2: Manual Library Placement

If you prefer not to use Homebrew, you can manually place the required `.dylib` files.

1.  Download the `libmpv.2.dylib` and all its dependencies (search for them on [mpv.io](https://mpv.io) or other build sources).
2.  Place all `.dylib` files (approximately 71 files including `libavcodec`, `libavformat`, etc.) in the following directory:
    `packages/mpv_native_texture/macos/Libs/`

### List of Required Libraries
A complete setup requires approximately 71 files. These are automatically detected by the build system if placed in the `Libs/` folder. Key libraries include:
- `libmpv.2.dylib`
- `libavcodec.61.dylib`, `libavdevice.61.dylib`, `libavfilter.10.dylib`, `libavformat.61.dylib`, `libavutil.59.dylib`, `libswresample.5.dylib`, `libswscale.5.dylib`
- `libass.9.dylib`, `libfreetype.6.dylib`, `libfribidi.0.dylib`, `libharfbuzz.0.dylib`, `libfontconfig.1.dylib`
- `libplacebo.338.dylib`, `libshaderc_shared.1.dylib`, `libvulkan.1.dylib`
- `libbluray.2.dylib`, `libarchive.13.dylib`, `libzmq.5.dylib`, `libmujs.dylib`
- ... and many supporting libraries (Total: 71 files).

### Configuration Details

The plugin uses `CocoaPods` for dependency management on macOS. The `mpv_native_texture.podspec` file is configured to:
-   **Header Search Paths**: Includes `/usr/local/include` and `/opt/homebrew/include` to support Homebrew installations.
-   **Vendored Libraries**: Automatically includes any `.dylib` files found in the `Libs/` directory.

```ruby
# From mpv_native_texture.podspec
s.vendored_libraries = Dir.glob('Libs/*.dylib')
```

## Troubleshooting

### "Library not loaded: libmpv.2.dylib"
This error occurs when the macOS linker cannot find the `libmpv` library at runtime.
-   **If using Homebrew**: Ensure `brew install mpv` completed successfully.
-   **If using manual placement**: Ensure `libmpv.2.dylib` and **all its dependencies** are present in the `Libs/` folder. macOS libraries often depend on other libraries (e.g., FFmpeg, Lua, etc.). All these must be present if not installed system-wide.
-   **Architecture Mismatch**: Ensure the `.dylib` files match your Mac's architecture (Intel `x86_64` vs. Apple Silicon `arm64`).

### Permissions/Sandboxing
If your app crashes when trying to load the library, ensure that "Disable Library Validation" is checked in your Xcode Project settings under `Signing & Capabilities` -> `App Sandbox` (if enabled) or that you have the appropriate entitlements.
