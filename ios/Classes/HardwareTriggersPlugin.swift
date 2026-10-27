import AVFoundation
import Flutter
import MediaPlayer
import UIKit

/// iOS never delivers volume key presses to apps, so this implementation
/// watches the audio session's output volume instead. A rise is reported as
/// Volume Up (Android code 24), a drop as Volume Down (25). Under a consume
/// rule the level is set back to a baseline through a hidden MPVolumeView,
/// which also keeps the system volume popup away.
///
/// Each press is one volume step. A held button makes iOS repeat the step,
/// about 330 ms after the press and then every 42 ms (measured with an AB
/// Shutter3). A step soon after the previous one is that repeat, a later one
/// a new press, so quick presses about 180 ms apart stay separate. Key-up
/// follows once no repeat arrives: `repeatDelay` after a press, `releaseGap`
/// after a repeat. A quick press is therefore a down/up pair shorter than the
/// long press threshold, and a hold a longer one, so the Dart recogniser needs
/// no iOS special case.
///
/// Volume changes carry no device, so an external-only rule matches nothing.
/// Verified on an iPhone (iOS 27) with an AB Shutter3, whose presses are
/// volume steps like the phone's own rocker's.
public class HardwareTriggersPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private struct Rule {
    let code: Int
    let consume: Bool
    let externalOnly: Bool
  }

  private static let volumeUpCode = 24
  private static let volumeDownCode = 25
  private static let baselineRange: ClosedRange<Float> = 0.1...0.9
  private static let repeatGap: TimeInterval = 0.1
  private static let repeatDelay: TimeInterval = 0.4
  private static let releaseGap: TimeInterval = 0.15
  /// How long volume changes after the app set the volume are its own.
  private static let ownChangeGap: TimeInterval = 0.5

  private var sink: FlutterEventSink?
  private var rules: [Rule] = []
  private var observation: NSKeyValueObservation?
  private var volumeView: MPVolumeView?
  private var baseline: Float = 0.5
  private var upTimers: [Int: Timer] = [:]
  private var lastStep: [Int: Date] = [:]
  private var ownChangeUntil = Date.distantPast

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = HardwareTriggersPlugin()
    let methods = FlutterMethodChannel(name: "hardware_triggers", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methods)
    let events = FlutterEventChannel(name: "hardware_triggers/events", binaryMessenger: registrar.messenger())
    events.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startIntercepting":
      let args = call.arguments as? [String: Any]
      let raw = args?["rules"] as? [[String: Any]] ?? []
      rules = raw.map {
        Rule(
          code: $0["code"] as? Int ?? -1,
          consume: ($0["policy"] as? String) != "observe",
          externalOnly: $0["externalOnly"] as? Bool ?? false)
      }
      startObserving()
      result(nil)
    case "stopIntercepting":
      rules = []
      stopObserving()
      result(nil)
    case "isInterceptSupported":
      result(true)
    case "systemVolume":
      result(Double(AVAudioSession.sharedInstance().outputVolume))
    case "setSystemVolume":
      let value = Float((call.arguments as? [String: Any])?["value"] as? Double ?? 0.5)
      changeSystemVolume(to: value)
      result(nil)
    case "connectedDevices":
      // iOS does not expose which HID device sent a key.
      result([])
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: FlutterStreamHandler

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  // MARK: Volume observation

  private func startObserving() {
    guard observation == nil else { return }
    let session = AVAudioSession.sharedInstance()
    do {
      // Without an active playback session the buttons step the ringer,
      // which outputVolume does not follow. .playback is also not silenced
      // by the mute switch, unlike .ambient. A category the app chose that
      // plays is kept.
      if session.category != .playback && session.category != .playAndRecord {
        try session.setCategory(.playback, options: [.mixWithOthers])
      }
      try session.setActive(true)
    } catch {
      sink?(FlutterError(code: "audio_session", message: error.localizedDescription, details: nil))
      return
    }

    attachVolumeView()

    baseline = Self.clampToBaseline(session.outputVolume)
    if rules.contains(where: { $0.consume }) {
      setSystemVolume(baseline)
    }

    observation = session.observe(\.outputVolume, options: [.old, .new]) { [weak self] _, change in
      let old = change.oldValue
      let new = change.newValue
      DispatchQueue.main.async {
        self?.onVolumeChanged(old: old, new: new)
      }
    }
  }

  private func stopObserving() {
    observation?.invalidate()
    observation = nil
    volumeView?.removeFromSuperview()
    volumeView = nil
    for timer in upTimers.values {
      timer.invalidate()
    }
    upTimers.removeAll()
    lastStep.removeAll()
  }

  /// Runs on the main queue.
  private func onVolumeChanged(old: Float?, new: Float?) {
    guard let old = old, let new = new, old != new else { return }
    // Our own restore to the baseline is not a press, and neither is a level
    // the app set: a dragged slider sets several in a row, and a late one no
    // longer matches the baseline.
    if abs(new - baseline) < 0.001 || Date() < ownChangeUntil { return }

    let code = new > old ? Self.volumeUpCode : Self.volumeDownCode
    guard let rule = rules.first(where: { $0.code == code }) else {
      // The user set this level on purpose; a consumed press returns to it.
      baseline = Self.clampToBaseline(new)
      return
    }
    // Device identity is unknown on iOS, so an external-only rule matches nothing.
    if rule.externalOnly { return }

    let now = Date()
    let isRepeat = lastStep[code].map { now.timeIntervalSince($0) < Self.repeatGap } ?? false
    lastStep[code] = now
    let pendingUp = upTimers[code]
    pendingUp?.invalidate()
    if !isRepeat {
      // The previous press was released before this one.
      if pendingUp != nil {
        emit(code: code, phase: "up", timestamp: Self.nowMillis())
      }
      emit(code: code, phase: "down", timestamp: Self.nowMillis())
    }
    let wait = isRepeat ? Self.releaseGap : Self.repeatDelay
    upTimers[code] = Timer.scheduledTimer(withTimeInterval: wait, repeats: false) { [weak self] _ in
      guard let self = self else { return }
      self.upTimers[code] = nil
      self.emit(code: code, phase: "up", timestamp: Self.nowMillis())
    }

    if rule.consume {
      setSystemVolume(baseline)
    } else {
      baseline = Self.clampToBaseline(new)
    }
  }

  private func emit(code: Int, phase: String, timestamp: Int) {
    sink?([
      "code": code,
      "phase": phase,
      "timestamp": timestamp,
      "deviceId": NSNull(),
      "deviceName": NSNull(),
      "isExternal": NSNull(),
    ])
  }

  private static func nowMillis() -> Int {
    Int(Date().timeIntervalSince1970 * 1000)
  }

  /// Sets the system volume on the app's behalf. While observing, the level
  /// becomes the baseline, so it is not mistaken for a press, and is kept
  /// inside the range a press can still move.
  private func changeSystemVolume(to value: Float) {
    if observation != nil {
      ownChangeUntil = Date().addingTimeInterval(Self.ownChangeGap)
      baseline = Self.clampToBaseline(value)
      setSystemVolume(baseline)
    } else {
      attachVolumeView()
      setSystemVolume(min(max(value, 0), 1))
      // An attached MPVolumeView hides the system volume popup; only keep it
      // while observing.
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        guard let self = self, self.observation == nil else { return }
        self.volumeView?.removeFromSuperview()
        self.volumeView = nil
      }
    }
  }

  private func attachVolumeView() {
    guard volumeView == nil else { return }
    let view = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
    view.alpha = 0.01
    keyWindow()?.addSubview(view)
    volumeView = view
  }

  private func setSystemVolume(_ value: Float) {
    guard let slider = volumeView?.subviews.compactMap({ $0 as? UISlider }).first else { return }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
      slider.setValue(value, animated: false)
      slider.sendActions(for: .touchUpInside)
    }
  }

  private static func clampToBaseline(_ value: Float) -> Float {
    min(max(value, baselineRange.lowerBound), baselineRange.upperBound)
  }

  private func keyWindow() -> UIWindow? {
    if #available(iOS 13.0, *) {
      return UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }
    }
    return UIApplication.shared.keyWindow
  }
}
