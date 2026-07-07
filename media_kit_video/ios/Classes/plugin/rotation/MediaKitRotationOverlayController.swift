#if canImport(Flutter)
  import AVFoundation
  import CoreMedia
  import Flutter
  import UIKit

  /// Container that holds an `AVSampleBufferDisplayLayer` sublayer. iOS
  /// calls `layoutSubviews` inside its rotation animation block, so the
  /// display layer's frame change participates in the
  /// `transitionCoordinator` animation naturally.
  @available(iOS 15.0, *)
  final class RotationSnapshotContainer: UIView {
    let displayLayer: AVSampleBufferDisplayLayer
    var portraitBottomInset: CGFloat = 0
    /// Orientation the display layer is currently posed for (portrait /
    /// landscape / unknown at mount). Prevents deriving inset from
    /// intermediate bounds during rotation animation, which would
    /// flip-flop as bounds cross the square-ish midpoint.
    private var currentPose: Pose = .unknown
    private enum Pose { case unknown, portrait, landscape }

    override init(frame: CGRect) {
      self.displayLayer = AVSampleBufferDisplayLayer()
      super.init(frame: frame)
      backgroundColor = .black
      clipsToBounds = true
      displayLayer.videoGravity = .resizeAspect
      layer.addSublayer(displayLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
      super.layoutSubviews()
      // iOS wraps this in its rotation CATransaction — set the target frame
      // once per pose change so iOS interpolates across the whole animation.
      // Per-tick recompute would flip the inset mid-animation.
      let newPose: Pose = bounds.height > bounds.width ? .portrait : .landscape
      if newPose != currentPose {
        currentPose = newPose
        let inset = (newPose == .portrait) ? portraitBottomInset : 0
        displayLayer.frame = CGRect(
          x: 0, y: 0, width: bounds.width, height: max(0, bounds.height - inset)
        )
      }
    }
  }

  @available(iOS 15.0, *)
  final class MediaKitRotationOverlayController: NSObject {
    private let outputManager: VideoOutputManager
    private let hostView: UIView
    private let container: RotationSnapshotContainer
    private let handle: Int64
    private let enqueueQueue = DispatchQueue(
      label: "com.alexmercerind.media_kit_video.rotation_overlay.enqueue",
      qos: .userInteractive
    )

    init(
      handle: Int64,
      outputManager: VideoOutputManager,
      hostView: UIView,
      portraitBottomInset: CGFloat
    ) {
      self.handle = handle
      self.outputManager = outputManager
      self.hostView = hostView
      self.container = RotationSnapshotContainer(frame: .zero)
      self.container.portraitBottomInset = portraitBottomInset
      super.init()

      container.translatesAutoresizingMaskIntoConstraints = false
      hostView.addSubview(container)
      NSLayoutConstraint.activate([
        container.leadingAnchor.constraint(equalTo: hostView.leadingAnchor),
        container.trailingAnchor.constraint(equalTo: hostView.trailingAnchor),
        container.topAnchor.constraint(equalTo: hostView.topAnchor),
        container.bottomAnchor.constraint(equalTo: hostView.bottomAnchor),
      ])
      hostView.setNeedsLayout()
      hostView.layoutIfNeeded()

      // Seed with the frame Flutter is currently showing — the display
      // layer is otherwise empty until mpv's next render tick, which iOS
      // captures as a black flash in its rotation snapshot.
      if let seed = outputManager.copyCurrentPixelBuffer(handle: handle) {
        enqueue(pixelBuffer: seed)
      }

      outputManager.setOnFrameRendered(handle: handle) { [weak self] pixelBuffer in
        self?.enqueue(pixelBuffer: pixelBuffer)
      }
    }

    func teardown() {
      outputManager.setOnFrameRendered(handle: handle, nil)
      container.displayLayer.flushAndRemoveImage()
      container.removeFromSuperview()
    }

    private func enqueue(pixelBuffer: CVPixelBuffer) {
      let retained = pixelBuffer
      enqueueQueue.async { [weak self] in
        guard let self = self else { return }
        let layer = self.container.displayLayer
        if layer.status == .failed { layer.flush() }
        guard layer.isReadyForMoreMediaData else { return }
        guard let sample = self.makeSampleBuffer(from: retained) else { return }
        layer.enqueue(sample)
      }
    }

    private func makeSampleBuffer(from pixelBuffer: CVPixelBuffer) -> CMSampleBuffer? {
      var formatDescription: CMVideoFormatDescription?
      let fdStatus = CMVideoFormatDescriptionCreateForImageBuffer(
        allocator: kCFAllocatorDefault,
        imageBuffer: pixelBuffer,
        formatDescriptionOut: &formatDescription
      )
      guard fdStatus == noErr, let description = formatDescription else { return nil }

      let presentationTime = CMClockGetTime(CMClockGetHostTimeClock())
      var timingInfo = CMSampleTimingInfo(
        duration: .invalid,
        presentationTimeStamp: presentationTime,
        decodeTimeStamp: .invalid
      )

      var sampleBuffer: CMSampleBuffer?
      let status = CMSampleBufferCreateReadyWithImageBuffer(
        allocator: kCFAllocatorDefault,
        imageBuffer: pixelBuffer,
        formatDescription: description,
        sampleTiming: &timingInfo,
        sampleBufferOut: &sampleBuffer
      )
      guard status == noErr, let buffer = sampleBuffer else { return nil }

      if let attachments = CMSampleBufferGetSampleAttachmentsArray(
        buffer,
        createIfNecessary: true
      ) as? [NSMutableDictionary],
        let first = attachments.first
      {
        first[kCMSampleAttachmentKey_DisplayImmediately as NSString] = kCFBooleanTrue
      }
      return buffer
    }
  }
#endif
