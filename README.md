# mpv_native_texture_demo

This is a Windows-only Flutter demo that renders **libmpv** into a Flutter `Texture` using the mpv render API.

## What you must provide (one file)

Due to licensing and size, this repo does **not** ship mpv binaries. You must supply:

- `mpv-2.dll` (libmpv runtime)

### Where to put `mpv-2.dll`

Place it in either location:

1. **Recommended** (auto-copy):
   - `packages/mpv_native_texture/windows/third_party/mpv/bin/mpv-2.dll`

   The plugin’s CMake will copy it into your build output folder...
