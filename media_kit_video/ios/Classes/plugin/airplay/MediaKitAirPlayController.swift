#if canImport(Flutter)
  import AVFoundation

  /// AVPlayer side-car for AirPlay video output.
  ///
  /// libmpv renders into a Flutter texture and can't reach an AirPlay screen;
  /// external playback (`AVPlayer.allowsExternalPlayback`) is the only iOS API that
  /// streams video to a receiver. This owns one `AVPlayer` fed by the media URL,
  /// forwards transport commands, and streams position/state/lifecycle back through
  /// [eventCallback]. Created and owned by `MediaKitAirPlayPlugin`.
  final class MediaKitAirPlayController {
    private let eventCallback: ([String: Any]) -> Void

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var itemStatusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var externalActiveObservation: NSKeyValueObservation?

    init(eventCallback: @escaping ([String: Any]) -> Void) {
      self.eventCallback = eventCallback
    }

    // MARK: - Transport

    func start(url: String, positionMs: Int, isLocalFile: Bool, autoPlay: Bool) {
      teardown()

      // libmpv runs with the app owning the audio session (iosManageAudioSession: false),
      // so make sure a playback session is active before AVPlayer takes over routing.
      let session = AVAudioSession.sharedInstance()
      try? session.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay, .allowBluetoothA2DP])
      try? session.setActive(true)

      let mediaURL: URL
      if isLocalFile {
        mediaURL = url.hasPrefix("file://") ? (URL(string: url) ?? URL(fileURLWithPath: url)) : URL(fileURLWithPath: url)
      } else {
        mediaURL = URL(string: url) ?? URL(fileURLWithPath: url)
      }
      let item = AVPlayerItem(url: mediaURL)
      let player = AVPlayer(playerItem: item)
      player.allowsExternalPlayback = true
      player.usesExternalPlaybackWhileExternalScreenIsActive = true
      self.player = player

      observeItemStatus(item)
      observeTimeControlStatus(player)
      observeExternalPlaybackActive(player)
      addPeriodicTimeObserver(to: player)
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(didPlayToEnd),
        name: .AVPlayerItemDidPlayToEndTime,
        object: item
      )

      if positionMs > 0 {
        let target = CMTime(value: CMTimeValue(positionMs), timescale: 1000)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak player] _ in
          if autoPlay { player?.play() }
        }
      } else if autoPlay {
        player.play()
      }
    }

    func play() { player?.play() }

    func pause() { player?.pause() }

    func seek(positionMs: Int) {
      guard let player = player else { return }
      let target = CMTime(value: CMTimeValue(max(0, positionMs)), timescale: 1000)
      player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    /// Tears the side-car down and returns the last known position (ms).
    func stop() -> Int {
      let positionMs = player.map { Int((CMTimeGetSeconds($0.currentTime()) * 1000).rounded()) } ?? 0
      teardown()
      return max(0, positionMs)
    }

    // MARK: - Observers

    private func addPeriodicTimeObserver(to player: AVPlayer) {
      let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
      timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
        guard let self = self, let item = self.player?.currentItem else { return }
        let durationSeconds = CMTimeGetSeconds(item.duration)
        self.eventCallback([
          "event": "position",
          "positionMs": Int((CMTimeGetSeconds(time) * 1000).rounded()),
          "durationMs": durationSeconds.isFinite ? Int((durationSeconds * 1000).rounded()) : 0,
        ])
      }
    }

    private func observeItemStatus(_ item: AVPlayerItem) {
      itemStatusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
        guard let self = self, item.status == .failed else { return }
        self.eventCallback(["event": "failed", "reason": item.error?.localizedDescription ?? "AVPlayerItem failed"])
      }
    }

    private func observeTimeControlStatus(_ player: AVPlayer) {
      timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
        guard let self = self else { return }
        switch player.timeControlStatus {
        case .playing:
          self.eventCallback(["event": "buffering", "isBuffering": false])
          self.eventCallback(["event": "playing", "isPlaying": true])
        case .paused:
          self.eventCallback(["event": "buffering", "isBuffering": false])
          self.eventCallback(["event": "playing", "isPlaying": false])
        case .waitingToPlayAtSpecifiedRate:
          self.eventCallback(["event": "buffering", "isBuffering": true])
        @unknown default:
          break
        }
      }
    }

    /// Emits `isExternalPlaybackActive` changes so Dart can detect a real
    /// receiver disconnect (see `AirPlayExternalActiveChanged`).
    private func observeExternalPlaybackActive(_ player: AVPlayer) {
      externalActiveObservation = player.observe(\.isExternalPlaybackActive, options: [.new]) { [weak self] player, _ in
        self?.eventCallback(["event": "externalActive", "isActive": player.isExternalPlaybackActive])
      }
    }

    @objc private func didPlayToEnd() {
      eventCallback(["event": "completed"])
    }

    private func teardown() {
      if let timeObserver = timeObserver {
        player?.removeTimeObserver(timeObserver)
        self.timeObserver = nil
      }
      itemStatusObservation = nil
      timeControlObservation = nil
      externalActiveObservation = nil
      NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
      player?.pause()
      player = nil
    }

    deinit {
      teardown()
    }
  }
#endif
