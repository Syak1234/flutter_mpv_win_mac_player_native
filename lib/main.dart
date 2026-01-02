import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mpv_native_texture/mpv_native_texture.dart';
import 'dart:io';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const App());
}

// Update the podspec to use libmpv.2.dylib
// Remove the system fallback from MpvApi.mm
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'mpv_native_texture demo',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const PlayerPage(),
    );
  }
}

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  MpvNativeTextureController? _controller;
  final _urlCtrl = TextEditingController(
    text:
        'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
  );

  @override
  void dispose() {
    _controller?.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureController() async {
    if (_controller != null) return;
    print(
        '[Dart] _ensureController: Starting controller creation for ${Platform.operatingSystem}...');
    try {
      final width = 1280;
      final height = 720;
      print(
          '[Dart] _ensureController: Calling MpvNativeTextureController.create() with $width x $height...');
      final c = await MpvNativeTextureController.create(
        width: width,
        height: height,
      );
      print(
          '[Dart] _ensureController: Controller created successfully, textureId=${c.textureId}');
      setState(() => _controller = c);
      print('[Dart] _ensureController: Controller set to state');
    } catch (e, stackTrace) {
      print('[Dart] _ensureController: CAUGHT ERROR: $e');
      print('[Dart] _ensureController: Stack trace: $stackTrace');
      // Show error dialog when controller creation fails (e.g., missing mpv-2.dll)
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Initialization Failed'),
            content: Text(
              'Failed to initialize mpv player.\n\n'
              'Error: $e\n\n'
              '${Platform.isWindows ? 'Make sure mpv-2.dll is present next to Runner.exe or in your system PATH.' : Platform.isMacOS ? 'Make sure libmpv.2.dylib is available in the application bundle or system.' : 'Make sure the mpv library is properly installed.'}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _openFile() async {
    await _ensureController();
    if (_controller == null) return;
    final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['mp4', 'mkv', 'mov', 'webm', 'avi']);
    if (res == null || res.files.single.path == null) return;
    await _controller!.open(res.files.single.path!);
    await _controller!.play();
  }

  Future<void> _openUrl() async {
    try {
      await _ensureController();
      if (_controller == null) return;
      final url = _urlCtrl.text.trim();
      if (url.isEmpty) return;
      await _controller!.open(url);
      await _controller!.play();
    } catch (e) {
      print("Error opening URL: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'mpv_native_texture demo (${Platform.isWindows ? 'Windows' : Platform.isMacOS ? 'macOS' : 'Unknown'})'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: c == null
                        ? Center(
                            child: Text(
                              'Click Open File or Open URL\n(${Platform.isWindows ? 'Requires mpv-2.dll present at runtime' : Platform.isMacOS ? 'Requires libmpv.2.dylib available' : 'Requires mpv library'})',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          )
                        : _VideoPlayerWithControls(controller: c),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'URL',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _openUrl,
                  child: const Text('Open URL'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _openFile,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Open File'),
                ),
                OutlinedButton(
                  onPressed: c == null ? null : () => c.play(),
                  child: const Text('Play'),
                ),
                OutlinedButton(
                  onPressed: c == null ? null : () => c.pause(),
                  child: const Text('Pause'),
                ),
                OutlinedButton(
                  onPressed: c == null ? null : () => c.seekRelative(-10),
                  child: const Text('-10s'),
                ),
                OutlinedButton(
                  onPressed: c == null ? null : () => c.seekRelative(10),
                  child: const Text('+10s'),
                ),
                OutlinedButton(
                  onPressed: c == null ? null : () => c.toggleMute(),
                  child: const Text('Mute'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Video player widget with overlay controls (appears on hover)
class _VideoPlayerWithControls extends StatefulWidget {
  final MpvNativeTextureController controller;

  const _VideoPlayerWithControls({required this.controller});

  @override
  State<_VideoPlayerWithControls> createState() =>
      _VideoPlayerWithControlsState();
}

class _VideoPlayerWithControlsState extends State<_VideoPlayerWithControls> {
  bool _showControls = false;
  bool _isPlaying = true;
  bool _isMuted = false;
  bool _showVolumeSlider = false;
  bool _isFullScreen = false;
  double _currentPosition = 0.0;
  double _duration = 100.0;
  double _volume = 100.0;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    // Start a timer to update position periodically from MPV
    _startPositionTimer();
  }

  void _startPositionTimer() {
    Future.delayed(const Duration(milliseconds: 1000), () async {
      if (mounted) {
        try {
          // Get real position and duration from MPV
          final pos = await widget.controller.getPosition();
          final dur = await widget.controller.getDuration();

          setState(() {
            _currentPosition = pos;
            // Only update duration if we got a valid value
            if (dur > 0) {
              _duration = dur;
            }
          });
        } catch (e) {
          // Ignore errors during polling (e.g., if no video is loaded)
        }
        _startPositionTimer();
      }
    });
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _toggleFullScreen() {
    if (_isFullScreen) {
      // Exit fullscreen - Navigator will pop automatically
      setState(() => _isFullScreen = false);
    } else {
      // Enter fullscreen
      setState(() => _isFullScreen = true);
      Navigator.of(context)
          .push(
        MaterialPageRoute(
          builder: (context) => _FullScreenPlayer(
            controller: widget.controller,
            onExit: () {
              setState(() => _isFullScreen = false);
            },
          ),
        ),
      )
          .then((_) {
        // Update state when user exits fullscreen
        if (mounted) {
          setState(() => _isFullScreen = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _showControls = true),
      onExit: (_) => setState(() {
        _showControls = false;
        _showVolumeSlider = false;
      }),
      child: GestureDetector(
        onTap: () {
          // Toggle play/pause on tap
          if (_isPlaying) {
            widget.controller.pause();
          } else {
            widget.controller.play();
          }
          setState(() => _isPlaying = !_isPlaying);
        },
        child: Stack(
          children: [
            // Video
            Positioned.fill(
              child: MpvNativeTextureView(controller: widget.controller),
            ),
            // Controls overlay
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.5),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                    ],
                    stops: const [0.0, 0.2, 0.7, 1.0],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top bar with title
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Text(
                            'Video Player',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          // Playback speed button
                          PopupMenuButton<double>(
                            icon: const Icon(Icons.speed, color: Colors.white),
                            tooltip: 'Playback Speed',
                            onSelected: (speed) {
                              setState(() => _playbackSpeed = speed);
                              widget.controller.setSpeed(speed);
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                  value: 0.25, child: Text('0.25x')),
                              const PopupMenuItem(
                                  value: 0.5, child: Text('0.5x')),
                              const PopupMenuItem(
                                  value: 0.75, child: Text('0.75x')),
                              const PopupMenuItem(
                                  value: 1.0, child: Text('1.0x (Normal)')),
                              const PopupMenuItem(
                                  value: 1.25, child: Text('1.25x')),
                              const PopupMenuItem(
                                  value: 1.5, child: Text('1.5x')),
                              const PopupMenuItem(
                                  value: 2.0, child: Text('2.0x')),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Bottom control bar
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Progress slider
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Text(
                                _formatDuration(_currentPosition),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderThemeData(
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 6,
                                    ),
                                    overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 12,
                                    ),
                                    trackHeight: 3,
                                  ),
                                  child: Slider(
                                    value:
                                        _currentPosition.clamp(0.0, _duration),
                                    min: 0,
                                    max: _duration,
                                    activeColor: Colors.red,
                                    inactiveColor: Colors.white24,
                                    onChanged: (value) {
                                      setState(() => _currentPosition = value);
                                    },
                                    onChangeEnd: (value) {
                                      widget.controller.seekAbsolute(value);
                                    },
                                  ),
                                ),
                              ),
                              Text(
                                _formatDuration(_duration),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Control buttons
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          child: Row(
                            children: [
                              // Play/Pause button
                              IconButton(
                                icon: Icon(
                                  _isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                onPressed: () {
                                  if (_isPlaying) {
                                    widget.controller.pause();
                                  } else {
                                    widget.controller.play();
                                  }
                                  setState(() => _isPlaying = !_isPlaying);
                                },
                              ),
                              // Seek backward
                              IconButton(
                                icon: const Icon(Icons.replay_10,
                                    color: Colors.white, size: 28),
                                onPressed: () {
                                  widget.controller.seekRelative(-10);
                                  setState(() {
                                    _currentPosition = (_currentPosition - 10)
                                        .clamp(0, _duration);
                                  });
                                },
                              ),
                              // Seek forward
                              IconButton(
                                icon: const Icon(Icons.forward_10,
                                    color: Colors.white, size: 28),
                                onPressed: () {
                                  widget.controller.seekRelative(10);
                                  setState(() {
                                    _currentPosition = (_currentPosition + 10)
                                        .clamp(0, _duration);
                                  });
                                },
                              ),
                              const Spacer(),
                              // Volume controls
                              MouseRegion(
                                onEnter: (_) =>
                                    setState(() => _showVolumeSlider = true),
                                onExit: (_) =>
                                    setState(() => _showVolumeSlider = false),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Volume slider
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      width: _showVolumeSlider ? 100 : 0,
                                      child: _showVolumeSlider
                                          ? SliderTheme(
                                              data: SliderThemeData(
                                                thumbShape:
                                                    const RoundSliderThumbShape(
                                                  enabledThumbRadius: 5,
                                                ),
                                                overlayShape:
                                                    const RoundSliderOverlayShape(
                                                  overlayRadius: 10,
                                                ),
                                                trackHeight: 2,
                                              ),
                                              child: Slider(
                                                value: _volume,
                                                min: 0,
                                                max: 100,
                                                activeColor: Colors.white,
                                                inactiveColor: Colors.white24,
                                                onChanged: (value) {
                                                  setState(() {
                                                    _volume = value;
                                                    _isMuted = value == 0;
                                                  });
                                                  // In real implementation: widget.controller.setVolume(value);
                                                },
                                              ),
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                    // Volume/Mute button
                                    IconButton(
                                      icon: Icon(
                                        _isMuted || _volume == 0
                                            ? Icons.volume_off
                                            : _volume < 50
                                                ? Icons.volume_down
                                                : Icons.volume_up,
                                        color: Colors.white,
                                      ),
                                      onPressed: () {
                                        widget.controller.toggleMute();
                                        setState(() => _isMuted = !_isMuted);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              // Fullscreen button
                              IconButton(
                                icon: Icon(
                                  _isFullScreen
                                      ? Icons.fullscreen_exit
                                      : Icons.fullscreen,
                                  color: Colors.white,
                                ),
                                onPressed: _toggleFullScreen,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Center play button when paused
            if (!_isPlaying)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 72,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Fullscreen video player overlay
class _FullScreenPlayer extends StatefulWidget {
  final MpvNativeTextureController controller;
  final VoidCallback onExit;

  const _FullScreenPlayer({
    required this.controller,
    required this.onExit,
  });

  @override
  State<_FullScreenPlayer> createState() => _FullScreenPlayerState();
}

class _FullScreenPlayerState extends State<_FullScreenPlayer> {
  bool _showControls = false;
  bool _isPlaying = true;
  bool _isMuted = false;
  bool _showVolumeSlider = false;
  double _currentPosition = 0.0;
  double _duration = 100.0;
  double _volume = 100.0;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _startPositionTimer();
  }

  void _startPositionTimer() {
    Future.delayed(const Duration(milliseconds: 1000), () async {
      if (mounted) {
        try {
          final pos = await widget.controller.getPosition();
          final dur = await widget.controller.getDuration();

          setState(() {
            _currentPosition = pos;
            if (dur > 0) {
              _duration = dur;
            }
          });
        } catch (e) {
          // Ignore errors during polling
        }
        _startPositionTimer();
      }
    });
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.toInt());
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: MouseRegion(
        onEnter: (_) => setState(() => _showControls = true),
        onExit: (_) => setState(() {
          _showControls = false;
          _showVolumeSlider = false;
        }),
        child: GestureDetector(
          onTap: () {
            if (_isPlaying) {
              widget.controller.pause();
            } else {
              widget.controller.play();
            }
            setState(() => _isPlaying = !_isPlaying);
          },
          child: Stack(
            children: [
              // Video - fill the screen
              Positioned.fill(
                child: MpvNativeTextureView(controller: widget.controller),
              ),
              // Controls overlay
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                      ],
                      stops: const [0.0, 0.2, 0.7, 1.0],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top bar
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Text(
                              'Video Player - Fullscreen',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            // Playback speed button
                            PopupMenuButton<double>(
                              icon:
                                  const Icon(Icons.speed, color: Colors.white),
                              tooltip: 'Playback Speed',
                              onSelected: (speed) {
                                setState(() => _playbackSpeed = speed);
                                widget.controller.setSpeed(speed);
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                    value: 0.25, child: Text('0.25x')),
                                const PopupMenuItem(
                                    value: 0.5, child: Text('0.5x')),
                                const PopupMenuItem(
                                    value: 0.75, child: Text('0.75x')),
                                const PopupMenuItem(
                                    value: 1.0, child: Text('1.0x (Normal)')),
                                const PopupMenuItem(
                                    value: 1.25, child: Text('1.25x')),
                                const PopupMenuItem(
                                    value: 1.5, child: Text('1.5x')),
                                const PopupMenuItem(
                                    value: 2.0, child: Text('2.0x')),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Bottom control bar
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Progress slider
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Text(
                                  _formatDuration(_currentPosition),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderThemeData(
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 6,
                                      ),
                                      overlayShape:
                                          const RoundSliderOverlayShape(
                                        overlayRadius: 12,
                                      ),
                                      trackHeight: 3,
                                    ),
                                    child: Slider(
                                      value: _currentPosition.clamp(
                                          0.0, _duration),
                                      min: 0,
                                      max: _duration,
                                      activeColor: Colors.red,
                                      inactiveColor: Colors.white24,
                                      onChanged: (value) {
                                        setState(
                                            () => _currentPosition = value);
                                      },
                                      onChangeEnd: (value) {
                                        widget.controller.seekAbsolute(value);
                                      },
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatDuration(_duration),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Control buttons
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            child: Row(
                              children: [
                                // Play/Pause button
                                IconButton(
                                  icon: Icon(
                                    _isPlaying ? Icons.pause : Icons.play_arrow,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  onPressed: () {
                                    if (_isPlaying) {
                                      widget.controller.pause();
                                    } else {
                                      widget.controller.play();
                                    }
                                    setState(() => _isPlaying = !_isPlaying);
                                  },
                                ),
                                // Seek backward
                                IconButton(
                                  icon: const Icon(Icons.replay_10,
                                      color: Colors.white, size: 28),
                                  onPressed: () {
                                    widget.controller.seekRelative(-10);
                                    setState(() {
                                      _currentPosition = (_currentPosition - 10)
                                          .clamp(0, _duration);
                                    });
                                  },
                                ),
                                // Seek forward
                                IconButton(
                                  icon: const Icon(Icons.forward_10,
                                      color: Colors.white, size: 28),
                                  onPressed: () {
                                    widget.controller.seekRelative(10);
                                    setState(() {
                                      _currentPosition = (_currentPosition + 10)
                                          .clamp(0, _duration);
                                    });
                                  },
                                ),
                                const Spacer(),
                                // Volume controls
                                MouseRegion(
                                  onEnter: (_) =>
                                      setState(() => _showVolumeSlider = true),
                                  onExit: (_) =>
                                      setState(() => _showVolumeSlider = false),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        width: _showVolumeSlider ? 100 : 0,
                                        child: _showVolumeSlider
                                            ? SliderTheme(
                                                data: SliderThemeData(
                                                  thumbShape:
                                                      const RoundSliderThumbShape(
                                                    enabledThumbRadius: 5,
                                                  ),
                                                  overlayShape:
                                                      const RoundSliderOverlayShape(
                                                    overlayRadius: 10,
                                                  ),
                                                  trackHeight: 2,
                                                ),
                                                child: Slider(
                                                  value: _volume,
                                                  min: 0,
                                                  max: 100,
                                                  activeColor: Colors.white,
                                                  inactiveColor: Colors.white24,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      _volume = value;
                                                      _isMuted = value == 0;
                                                    });
                                                  },
                                                ),
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          _isMuted || _volume == 0
                                              ? Icons.volume_off
                                              : _volume < 50
                                                  ? Icons.volume_down
                                                  : Icons.volume_up,
                                          color: Colors.white,
                                        ),
                                        onPressed: () {
                                          widget.controller.toggleMute();
                                          setState(() => _isMuted = !_isMuted);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                // Exit fullscreen button
                                IconButton(
                                  icon: const Icon(
                                    Icons.fullscreen_exit,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    widget.onExit();
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Center play button when paused
              if (!_isPlaying)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 72,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
