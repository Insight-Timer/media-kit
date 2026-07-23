/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

import 'package:media_kit_video/src/airplay/airplay_controller.dart';
import 'package:media_kit_video/src/airplay/airplay_event.dart';

/// iOS implementation of [AirPlayController] backed by a native `AVPlayer`
/// side-car. Owns the libmpv↔AVPlayer handoff: reads the [Player]'s current media
/// + position, pauses/resumes libmpv, and drives the native side-car.
class AirPlayIOS implements AirPlayController {
  AirPlayIOS(this._player);

  final Player _player;

  static const MethodChannel _method =
      MethodChannel('com.alexmercerind/media_kit_video/airplay');
  static const EventChannel _events =
      EventChannel('com.alexmercerind/media_kit_video/airplay/events');

  // Static: each `receiveBroadcastStream` replaces the channel's handler and
  // re-runs the plugin's onListen, severing the prior subscriber. One shared
  // stream, many Dart listeners. (Mirrors PictureInPictureIOS.)
  static Stream<AirPlayEvent>? _eventStream;

  // Play/pause state captured at handoff, restored to libmpv on [stopHandoff].
  bool _wasPlayingBeforeHandoff = false;

  @override
  Future<bool> isSupported() async {
    try {
      final supported = await _method.invokeMethod<bool>('isSupported');
      return supported ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> startHandoff() async {
    final url = _currentMediaUri;
    if (url == null) return;
    final positionMs = _player.state.position.inMilliseconds;
    _wasPlayingBeforeHandoff = _player.state.playing;
    // Pause the on-device decoder so only the AVPlayer feeds the receiver.
    await _player.pause();
    try {
      await _method.invokeMethod<void>('start', <String, dynamic>{
        'url': url,
        'positionMs': positionMs,
        'isLocalFile': _isLocalFile(url),
        'autoPlay': _wasPlayingBeforeHandoff,
      });
    } on MissingPluginException {
      // no-op
    }
  }

  @override
  Future<void> stopHandoff() async {
    int positionMs = 0;
    try {
      positionMs = await _method.invokeMethod<int>('stop') ?? 0;
    } on PlatformException {
      // keep positionMs = 0
    } on MissingPluginException {
      // keep positionMs = 0
    }
    // Resume the on-device decoder exactly where the receiver left off.
    await _player.seek(Duration(milliseconds: positionMs));
    if (_wasPlayingBeforeHandoff) {
      await _player.play();
    }
  }

  @override
  Future<void> play() => _invoke('play');

  @override
  Future<void> pause() => _invoke('pause');

  @override
  Future<void> seek(Duration position) =>
      _invoke('seek', <String, dynamic>{'positionMs': position.inMilliseconds});

  /// The URI of the currently-open media, or null if nothing is loaded.
  String? get _currentMediaUri {
    final playlist = _player.state.playlist;
    if (playlist.medias.isEmpty) return null;
    final index = playlist.index;
    if (index < 0 || index >= playlist.medias.length) return null;
    return playlist.medias[index].uri;
  }

  // IT content is HLS (https) or a downloaded local file; treat anything that
  // isn't an http(s) URL as a local file path for AVPlayer.
  bool _isLocalFile(String uri) =>
      !uri.startsWith('http://') && !uri.startsWith('https://');

  Future<void> _invoke(String method, [Map<String, dynamic>? args]) async {
    try {
      await _method.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // no-op
    }
  }

  @override
  Stream<AirPlayEvent> get events => _eventStream ??=
      _events.receiveBroadcastStream().map(_mapEvent).asBroadcastStream();

  AirPlayEvent _mapEvent(dynamic raw) {
    if (raw is! Map) return const AirPlayFailed('invalid_payload');
    switch (raw['event']) {
      case 'position':
        return AirPlayPositionChanged(
          position:
              Duration(milliseconds: (raw['positionMs'] as num?)?.toInt() ?? 0),
          duration:
              Duration(milliseconds: (raw['durationMs'] as num?)?.toInt() ?? 0),
        );
      case 'playing':
        return AirPlayPlayingChanged(isPlaying: raw['isPlaying'] == true);
      case 'buffering':
        return AirPlayBufferingChanged(isBuffering: raw['isBuffering'] == true);
      case 'completed':
        return const AirPlayCompleted();
      case 'externalActive':
        return AirPlayExternalActiveChanged(isActive: raw['isActive'] == true);
      case 'failed':
        return AirPlayFailed(raw['reason']?.toString() ?? 'unknown');
      default:
        return AirPlayFailed('unknown_event:${raw['event']}');
    }
  }
}
