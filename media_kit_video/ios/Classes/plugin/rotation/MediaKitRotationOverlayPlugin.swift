#if canImport(Flutter)
  import Flutter
  import UIKit

  /// Flutter plugin exposing `begin`/`end` methods for a native SBDL overlay
  /// used to cover Flutter's `Texture`-widget skew during iOS rotation
  /// animations. See `MediaKitRotationOverlayController` for the SBDL host.
  final class MediaKitRotationOverlayPlugin: NSObject {
    static let METHOD_CHANNEL = "com.alexmercerind/media_kit_video/rotation_overlay"

    private let outputManager: VideoOutputManager
    private var controller: AnyObject?

    init(registrar: FlutterPluginRegistrar, outputManager: VideoOutputManager) {
      self.outputManager = outputManager
      super.init()

      let channel = FlutterMethodChannel(
        name: Self.METHOD_CHANNEL,
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { [weak self] call, result in
        self?.handle(call, result: result)
      }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
      switch call.method {
      case "begin":
        handleBegin(call.arguments, result: result)
      case "end":
        if #available(iOS 15.0, *) {
          (controller as? MediaKitRotationOverlayController)?.teardown()
        }
        controller = nil
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    private func handleBegin(_ arguments: Any?, result: @escaping FlutterResult) {
      guard #available(iOS 15.0, *) else {
        result(FlutterError(code: "UNSUPPORTED", message: "iOS 15+", details: nil))
        return
      }
      guard let args = arguments as? [String: Any] else {
        result(FlutterError(code: "INVALID_ARGS", message: "arguments required", details: nil))
        return
      }
      guard let handle = readHandle(args["handle"]) else {
        result(FlutterError(code: "INVALID_ARGS", message: "handle required", details: nil))
        return
      }
      guard let hostView = resolveHostView() else {
        result(FlutterError(code: "NO_WINDOW", message: "No host window available", details: nil))
        return
      }
      let portraitBottomInset = (args["portraitBottomInset"] as? NSNumber)?.doubleValue ?? 0

      // Replace any in-flight overlay before mounting a new one — orientation
      // transitions can overlap under rapid rotation.
      (controller as? MediaKitRotationOverlayController)?.teardown()
      controller = MediaKitRotationOverlayController(
        handle: handle,
        outputManager: outputManager,
        hostView: hostView,
        portraitBottomInset: CGFloat(portraitBottomInset)
      )
      // Defer result to the next main-queue tick so UIKit commits the
      // addSubview + layout to the render tree before Dart proceeds to
      // SystemChrome.setPreferredOrientations. Without this, iOS can take
      // its pre-rotation snapshot before our overlay is committed → the
      // rotation animates without the overlay participating.
      DispatchQueue.main.async {
        result(nil)
      }
    }

    private func readHandle(_ raw: Any?) -> Int64? {
      if let number = raw as? NSNumber { return number.int64Value }
      if let string = raw as? String { return Int64(string) }
      return nil
    }

    private func resolveHostView() -> UIView? {
      for scene in UIApplication.shared.connectedScenes {
        guard let windowScene = scene as? UIWindowScene,
          scene.activationState == .foregroundActive
            || scene.activationState == .foregroundInactive
        else { continue }
        let keyed =
          windowScene.windows.first(where: { $0.isKeyWindow })
          ?? windowScene.windows.first
        if let window = keyed {
          return window.rootViewController?.view ?? window
        }
      }
      return nil
    }
  }
#endif
