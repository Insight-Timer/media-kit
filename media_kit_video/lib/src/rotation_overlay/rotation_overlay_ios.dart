import 'package:flutter/services.dart';

import 'package:media_kit_video/src/rotation_overlay/rotation_overlay_controller.dart';

class RotationOverlayIOS implements RotationOverlayController {
  static const MethodChannel _method =
      MethodChannel('com.alexmercerind/media_kit_video/rotation_overlay');

  @override
  Future<void> begin({required int handle, double portraitBottomInset = 0}) async {
    try {
      await _method.invokeMethod<void>('begin', <String, dynamic>{
        'handle': handle,
        'portraitBottomInset': portraitBottomInset,
      });
    } on MissingPluginException {
      // no-op on unsupported plugin builds
    }
  }

  @override
  Future<void> end() async {
    try {
      await _method.invokeMethod<void>('end');
    } on MissingPluginException {
      // no-op
    }
  }
}
