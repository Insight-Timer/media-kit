import 'package:media_kit_video/src/rotation_overlay/rotation_overlay_controller.dart';

class RotationOverlayNoop implements RotationOverlayController {
  @override
  Future<void> begin({required int handle, double portraitBottomInset = 0}) async {}

  @override
  Future<void> end() async {}
}
