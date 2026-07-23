#if canImport(Flutter)
  import AVFoundation
  import Flutter
  import UIKit

  /// Flutter plugin exposing AirPlay video handoff to Dart through the
  /// `com.alexmercerind/media_kit_video/airplay` method and event channels.
  ///
  /// Instantiated by `MediaKitVideoPlugin.register(with:)`. Unlike the PiP plugin
  /// it needs no `VideoOutputManager` — AVKit streams the media URL to the receiver
  /// directly rather than consuming libmpv frames.
  final class MediaKitAirPlayPlugin: NSObject, FlutterStreamHandler {
    static let METHOD_CHANNEL = "com.alexmercerind/media_kit_video/airplay"
    static let EVENT_CHANNEL = "com.alexmercerind/media_kit_video/airplay/events"

    private var controller: MediaKitAirPlayController?
    private var eventSink: FlutterEventSink?

    init(registrar: FlutterPluginRegistrar) {
      super.init()

      let messenger = registrar.messenger()
      let methodChannel = FlutterMethodChannel(name: Self.METHOD_CHANNEL, binaryMessenger: messenger)
      let eventChannel = FlutterEventChannel(name: Self.EVENT_CHANNEL, binaryMessenger: messenger)
      methodChannel.setMethodCallHandler { [weak self] call, result in
        self?.handle(call, result: result)
      }
      eventChannel.setStreamHandler(self)
    }

    // MARK: - Method channel

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
      switch call.method {
      case "isSupported":
        result(true)
      case "start":
        handleStart(call.arguments, result: result)
      case "play":
        controller?.play()
        result(nil)
      case "pause":
        controller?.pause()
        result(nil)
      case "seek":
        controller?.seek(positionMs: (call.arguments as? [String: Any])?["positionMs"] as? Int ?? 0)
        result(nil)
      case "stop":
        let positionMs = controller?.stop() ?? 0
        controller = nil
        result(positionMs)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    private func handleStart(_ arguments: Any?, result: @escaping FlutterResult) {
      guard let args = arguments as? [String: Any], let url = args["url"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "url required", details: nil))
        return
      }
      // AVPlayer KVO/notifications can fire off the main thread; FlutterEventSink
      // must be invoked on the platform thread.
      let controller = MediaKitAirPlayController { [weak self] event in
        DispatchQueue.main.async { self?.eventSink?(event) }
      }
      self.controller = controller
      controller.start(
        url: url,
        positionMs: args["positionMs"] as? Int ?? 0,
        isLocalFile: args["isLocalFile"] as? Bool ?? false,
        autoPlay: args["autoPlay"] as? Bool ?? true
      )
      result(nil)
    }

    // MARK: - FlutterStreamHandler

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
      eventSink = events
      return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
      eventSink = nil
      return nil
    }
  }
#endif
