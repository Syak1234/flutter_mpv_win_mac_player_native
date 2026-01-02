import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A unified mpv instance rendered into a Flutter external texture.
/// Automatically selects the correct implementation based on the platform.
class MpvNativeTextureController {
  static const MethodChannel _channel = MethodChannel('mpv_native_texture');

  final int textureId;
  final bool _isWindows;

  MpvNativeTextureController._(this.textureId, this._isWindows);

  /// Creates an mpv controller for the current platform.
  ///
  /// [width] and [height] specify the initial video dimensions.
  /// On Windows, requires mpv-2.dll to be present next to Runner.exe or in PATH.
  /// On macOS, requires libmpv.2.dylib to be available in the application bundle.
  static Future<MpvNativeTextureController> create({
    int width = 1280,
    int height = 720,
  }) async {
    final isWindows = Platform.isWindows;
    final int id = await _channel.invokeMethod('create', <String, dynamic>{
      'width': width,
      'height': height,
    });
    return MpvNativeTextureController._(id, isWindows);
  }

  /// Releases resources used by this controller.
  Future<void> dispose() async {
    await _channel
        .invokeMethod('dispose', <String, dynamic>{'textureId': textureId});
  }

  /// Opens a video file or URL.
  ///
  /// [pathOrUrl] can be a local file path or a remote URL.
  Future<void> open(String pathOrUrl) async {
    await _channel.invokeMethod('open', <String, dynamic>{
      'textureId': textureId,
      'path': pathOrUrl,
    });
  }

  /// Starts or resumes playback.
  Future<void> play() =>
      _channel.invokeMethod('play', <String, dynamic>{'textureId': textureId});

  /// Pauses playback.
  Future<void> pause() =>
      _channel.invokeMethod('pause', <String, dynamic>{'textureId': textureId});

  /// Seeks relative to the current position.
  ///
  /// [seconds] can be positive (forward) or negative (backward).
  Future<void> seekRelative(num seconds) =>
      _channel.invokeMethod('seekRelative', <String, dynamic>{
        'textureId': textureId,
        'seconds': seconds,
      });

  /// Seeks to an absolute position.
  ///
  /// [seconds] is the position in seconds from the start.
  Future<void> seekAbsolute(num seconds) =>
      _channel.invokeMethod('seekAbsolute', <String, dynamic>{
        'textureId': textureId,
        'seconds': seconds,
      });

  /// Sets the playback volume.
  ///
  /// [volume01] should be between 0.0 (mute) and 1.0 (max).
  Future<void> setVolume(num volume01) =>
      _channel.invokeMethod('setVolume', <String, dynamic>{
        'textureId': textureId,
        'volume': volume01,
      });

  /// Toggles mute on/off.
  Future<void> toggleMute() => _channel
      .invokeMethod('toggleMute', <String, dynamic>{'textureId': textureId});

  /// Gets the current playback position in seconds.
  Future<double> getPosition() async {
    final result = await _channel
        .invokeMethod('getPosition', <String, dynamic>{'textureId': textureId});
    return (result as num).toDouble();
  }

  /// Gets the total duration in seconds.
  Future<double> getDuration() async {
    final result = await _channel
        .invokeMethod('getDuration', <String, dynamic>{'textureId': textureId});
    return (result as num).toDouble();
  }

  /// Sets the playback speed.
  ///
  /// [speed] should be between 0.25 and 10.0 (1.0 is normal speed).
  Future<void> setSpeed(num speed) =>
      _channel.invokeMethod('setSpeed', <String, dynamic>{
        'textureId': textureId,
        'speed': speed,
      });
}

/// A widget that displays the video texture from [MpvNativeTextureController].
class MpvNativeTextureView extends StatelessWidget {
  final MpvNativeTextureController controller;

  const MpvNativeTextureView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Texture(textureId: controller.textureId);
  }
}
