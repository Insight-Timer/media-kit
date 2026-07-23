/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:async';

import 'package:media_kit_video/src/airplay/airplay_controller.dart';
import 'package:media_kit_video/src/airplay/airplay_event.dart';

/// No-op [AirPlayController] for platforms without AirPlay (everything but iOS).
class AirPlayNoop implements AirPlayController {
  const AirPlayNoop();

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<void> startHandoff() async {}

  @override
  Future<void> stopHandoff() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Stream<AirPlayEvent> get events => const Stream<AirPlayEvent>.empty();
}
