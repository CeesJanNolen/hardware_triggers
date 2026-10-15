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
/// A held button makes iOS step the volume repeatedly. The first step is
/// reported as key-down; key-up follows once no step has arrived for
/// `holdGap`. A quick press is therefore a down/up pair `holdGap` apart, and
/// a hold a longer one, so the Dart recogniser needs no iOS special case.
///
/// UNVERIFIED on a device. Compiles in CI; behaviour awaits the Mac mini.
public class HardwareTriggersPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private struct Rule {
    let code: Int
    let consume: Bool
    let externalOnly: Bool
  }

  private static let volumeUpCode = 24
  private static let volumeDownCode = 25
  private static let baselineRange: ClosedRange<Float> = 0.1...0.9
  private static let holdGap: TimeInterval = 0.3

  private var sink: FlutterEventSink?
  private var rules: [Rule] = []
  private var observation: NSKeyValueObservation?
  private var volumeView: MPVolumeView?
  private var baseline: Float = 0.5
  private var holdTimers: [Int: Timer] = [:]

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
      try session.setCategory(.ambient, options: [.mixWithOthers])
      try session.setActive(true)
    } catch {
      sink?(FlutterError(code: "audio_session", message: error.localizedDescription, details: nil))
      return
    }

    if volumeView == nil {
      let view = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
      view.alpha = 0.01
      keyWindow()?.addSubview(view)
      volumeView = view
    }

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
    for timer in holdTimers.values {
      timer.invalidate()
    }
    holdTimers.removeAll()
  }

  /// Runs on the main queue.
  private func onVolumeChanged(old: Float?, new: Float?) {
    guard let old = old, let new = new, old != new else { return }
    // Our own restore to the baseline is not a press.
    if abs(new - baseline) < 0.001 { return }

    let code = new > old ? Self.volumeUpCode : Self.volumeDownCode
    guard let rule = rules.first(where: { $0.code == code }) else { return }
    // Device identity is unknown on iOS, so an external-only rule matches nothing.
    if rule.externalOnly { return }

    if let timer = holdTimers[code] {
      timer.invalidate()
    } else {
      emit(code: code, phase: "down", timestamp: Self.nowMillis())
    }
    holdTimers[code] = Timer.scheduledTimer(withTimeInterval: Self.holdGap, repeats: false) { [weak self] _ in
      guard let self = self else { return }
      self.holdTimers[code] = nil
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
