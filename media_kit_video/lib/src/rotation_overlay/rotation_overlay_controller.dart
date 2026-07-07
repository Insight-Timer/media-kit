import 'dart:io';

import 'package:media_kit_video/src/rotation_overlay/rotation_overlay_ios.dart';
import 'package:media_kit_video/src/rotation_overlay/rotation_overlay_noop.dart';

/// Native overlay used to hide Flutter `Texture`-widget skew during
/// iOS rotation animations. iOS animates the sibling native view via
/// `transitionCoordinator` while Flutter re-layouts underneath.
///
/// Available on iOS 15+ only; Android and other platforms are no-ops.
abstract class RotationOverlayController {
  factory RotationOverlayController.platform() {
    if (Platform.isIOS) return RotationOverlayIOS();
    return RotationOverlayNoop();
  }

  /// Mounts the overlay UIView above the app's root view and starts
  /// pumping libmpv frames into it. Idempotent: back-to-back `begin`
  /// calls replace the previous overlay.
  ///
  /// [portraitBottomInset]: px inset applied to the video's frame from the
  /// bottom of the container when the container is in portrait. Matches
  /// the Flutter-side inset used to shift inline landscape video up from
  /// centre. Ignored when the container is landscape (fullscreen).
  Future<void> begin({required int handle, double portraitBottomInset = 0});

  /// Removes the overlay and stops the frame pump.
  Future<void> end();
}
