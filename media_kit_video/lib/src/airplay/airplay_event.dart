/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.

/// Base class for events emitted by [AirPlayController.events].
///
/// While an AirPlay session is active, playback runs on a native `AVPlayer`
/// side-car (libmpv can't route video to an AirPlay receiver), so these events
/// report that player's position/state back to Dart.
abstract class AirPlayEvent {
  const AirPlayEvent();
}

/// Periodic playback position/duration from the side-car.
class AirPlayPositionChanged extends AirPlayEvent {
  const AirPlayPositionChanged(
      {required this.position, required this.duration});

  final Duration position;
  final Duration duration;
}

/// Emitted when the side-car's playing state changes.
class AirPlayPlayingChanged extends AirPlayEvent {
  const AirPlayPlayingChanged({required this.isPlaying});

  final bool isPlaying;
}

/// Emitted when the side-car's buffering state changes.
class AirPlayBufferingChanged extends AirPlayEvent {
  const AirPlayBufferingChanged({required this.isBuffering});

  final bool isBuffering;
}

/// Emitted when the side-car reaches the end of the media.
class AirPlayCompleted extends AirPlayEvent {
  const AirPlayCompleted();
}

/// Emitted when the side-car fails to load or play.
class AirPlayFailed extends AirPlayEvent {
  const AirPlayFailed(this.reason);

  final String reason;
}

/// Emitted when the `AVPlayer`'s `isExternalPlaybackActive` changes — the
/// authoritative "is casting to an external screen" signal. Unlike the audio
/// session route, it stays true for the whole cast and flips false only when
/// the receiver is actually deselected.
class AirPlayExternalActiveChanged extends AirPlayEvent {
  const AirPlayExternalActiveChanged({required this.isActive});

  final bool isActive;
}
