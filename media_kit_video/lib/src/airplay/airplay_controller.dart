/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:async';
import 'dart:io';

import 'package:media_kit/media_kit.dart';

import 'package:media_kit_video/src/airplay/airplay_event.dart';
import 'package:media_kit_video/src/airplay/airplay_ios.dart';
import 'package:media_kit_video/src/airplay/airplay_noop.dart';

/// Platform-agnostic AirPlay video controller exposed on [VideoController.airPlay].
///
/// media_kit renders video into a Flutter texture via libmpv, which can't route
/// video to an AirPlay receiver. This plays the current stream on a native
/// `AVPlayer` (the only iOS API that streams video to a receiver) while a route is
/// active. iOS-only; a no-op elsewhere.
abstract class AirPlayController {
  /// Creates a platform-specific instance driving [player]. On unsupported
  /// platforms this returns a no-op whose [isSupported] resolves to `false`.
  factory AirPlayController.platform(Player player) {
    if (Platform.isIOS) return AirPlayIOS(player);
    return const AirPlayNoop();
  }

  /// Whether AirPlay video handoff is supported on the current platform.
  Future<bool> isSupported();

  /// Hands the current playback off to the AVPlayer side-car: reads the current
  /// media URL + position from the [Player], pauses libmpv, and starts external
  /// playback (preserving the paused/playing state). No-op if nothing is loaded.
  Future<void> startHandoff();

  /// Ends the handoff: tears down the side-car, seeks libmpv back to the position
  /// the receiver reached, and restores its prior play/pause state.
  Future<void> stopHandoff();

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  /// Broadcast stream of side-car position/state/lifecycle events.
  Stream<AirPlayEvent> get events;
}
