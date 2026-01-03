# MPV Native Texture Demo

A Flutter demo application that renders **libmpv** video player into Flutter `Texture` widgets using the mpv render API. This project provides a unified API that works seamlessly on both **Windows** and **macOS** platforms.

[![Flutter](https://img.shields.io/badge/Flutter-3.35%2B-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS-lightgrey)](#platform-support)
[![libmpv](https://img.shields.io/badge/libmpv-Powered-orange)](https://mpv.io)

## ✨ Features

- 🎬 **Hardware-accelerated video playback** using libmpv
- 🖼️ **Native texture rendering** directly into Flutter widgets
- 🎯 **Unified API** for both Windows and macOS
- 🎮 **Rich playback controls** with overlay UI
- ⚡ **Seek, pause, play** with smooth performance
- 🔊 **Volume control** and mute functionality
- ⏩ **Playback speed** adjustment (0.25x to 2x)
- 🖥️ **Fullscreen mode** support
- 📂 **Local file and URL playback** support
- 🎨 **Beautiful, modern UI** with hover controls

## 🚀 Quick Start

### Prerequisites

Before running this demo, you need:

1. **Flutter SDK** (3.35.0 or later)
2. **Platform-specific libmpv libraries:**
   - **Windows**: `mpv-2.dll`
   - **macOS**: `libmpv.2.dylib`

### 📥 Getting the MPV Libraries

Due to licensing and size constraints, this repository does **not** ship mpv binaries. You must download them separately:

#### Windows
1. Download `mpv-2.dll` from [mpv.io/installation](https://mpv.io/installation/) or [Shinchiro's builds](https://sourceforge.net/projects/mpv-player-windows/files/)
2. Place it in: `packages/mpv_native_texture/windows/third_party/mpv/bin/mpv-2.dll`
3. The plugin's CMake will automatically copy it to your build output folder

#### macOS
1. **Option A: Homebrew (Recommended)**
   ```bash
   brew install mpv
   ```
2. **Option B: Manual Download**
   - Download `libmpv.2.dylib` and **all its dependencies** from a reliable source.
   - Place **all required `.dylib` files** (approximately 70+ files) in: `packages/mpv_native_texture/macos/Libs/`
   - The plugin's `podspec` will automatically include all dylibs in this folder.

### 🔧 Installation

```bash
# Clone the repository
git clone https://github.com/Syak1234/flutter_mpv_win_mac_player_native.git
cd mpv_win_mac_player

# Get dependencies
flutter pub get

# Run on Windows
flutter run -d windows

# Run on macOS
flutter run -d macos
```

### 🎥 Usage

```dart
import 'package:mpv_native_texture/mpv_native_texture.dart';

// Create controller (works on both Windows and macOS)
final controller = await MpvNativeTextureController.create();

// Open and play a video
await controller.open('path/to/video.mp4');
await controller.play();

// Display video in your widget tree
MpvNativeTextureView(controller: controller)
```

## 📚 Detailed Setup Guide

For comprehensive, step-by-step setup instructions with troubleshooting tips, see:

**[📖 SETUP_GUIDE.html](./SETUP_GUIDE.html)** - Download or open this local file in your browser for a beautiful, detailed guide!

## 🖥️ Platform Support

| Platform | Support | Status |
|----------|---------|--------|
| Windows  | ✅ Full | Tested on Windows 10/11 |
| macOS    | ✅ Full | Tested on macOS 12+ |
| Linux    | ❌ Not yet | Planned |
| iOS/Android | ❌ Not yet | Different approach needed |

## 🏗️ Project Structure

```
mpv_win_mac_player/
├── lib/
│   ├── main.dart              # Demo application
├── packages/
│   └── mpv_native_texture/    # Plugin package
│       ├── lib/
│       │   └── mpv_native_texture.dart  # Unified API
│       ├── windows/           # Windows native implementation
│       │   └── third_party/mpv/bin/     # Place mpv-2.dll here
│       └── macos/             # macOS native implementation
│           └── Libs/          # Place libmpv.2.dylib here
├── README.md
└── SETUP_GUIDE.html          # Detailed setup instructions
```

## 🎮 Controls

The demo app includes:

- **Play/Pause**: Click the video or use the control buttons
- **Seek**: Use the timeline slider or ±10s buttons
- **Volume**: Hover over volume icon to adjust
- **Speed**: Click speed icon to change playback rate
- **Fullscreen**: Enter/exit fullscreen mode

## 🐛 Troubleshooting

### Windows Issues

**"Failed to initialize mpv player"**
- Ensure `mpv-2.dll` is in `packages/mpv_native_texture/windows/third_party/mpv/bin/`
- Or place it next to `Runner.exe` in your build output folder
- Verify the DLL is the correct architecture (x64)

**Video not playing**
- Check if the video format is supported by mpv
- Try a different video file
- Check console for error messages

### macOS Issues

**"Library not loaded: libmpv.2.dylib"**
- Install mpv via Homebrew: `brew install mpv`
- Or place `libmpv.2.dylib` and all required dependencies in `packages/mpv_native_texture/macos/Libs/`
- Ensure the plugin's `podspec` can find the libraries.
- Verify library architecture matches your Mac (Intel/Apple Silicon)

## 🔧 Building from Source

```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build for Windows (Debug)
flutter build windows --debug

# Build for macOS (Debug)
flutter build macos --debug

# Build for Windows (Release)
flutter build windows --release

# Build for macOS (Release)
flutter build macos --release
```

## 📝 Requirements

- **Flutter**: 3.35.0 or later
- **Dart SDK**: 3.3.0 or later
- **Windows**: Windows 10 or later (for Windows builds)
- **macOS**: macOS 12 or later (for macOS builds)
- **Visual Studio**: 2019 or later with C++ tools (Windows only)
- **Xcode**: Latest version (macOS only)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is provided as-is for demonstration purposes. Please refer to the [mpv](https://mpv.io) project for libmpv licensing information.

## 🙏 Acknowledgments

- [mpv](https://mpv.io) - The amazing media player
- [Flutter](https://flutter.dev) - Google's UI toolkit
- **Sayak Mishra** - Flutter Developer (Project Creator)
- All contributors to the libmpv project

## 📞 Support

If you encounter issues:
1. Check the [SETUP_GUIDE.html](./SETUP_GUIDE.html) for detailed instructions
2. Review the troubleshooting section above
3. Open an issue on GitHub with:
   - Your platform (Windows/macOS)
   - Flutter version (`flutter --version`)
   - Error messages from console
   - Steps to reproduce

---

**Happy Video Playing! 🎬**
