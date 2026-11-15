import AudioToolbox
import CoreLocation
import CoreMotion
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, CLLocationManagerDelegate {
  private let motionManager = CMMotionManager()
  private var tiltChannel: FlutterMethodChannel?
  private var locationChannel: FlutterMethodChannel?
  private var locationManager: CLLocationManager?
  private var pendingLocationResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FypNativeBridge") else {
      return
    }

    let tilt = FlutterMethodChannel(name: "fyp/tilt", binaryMessenger: registrar.messenger())
    tiltChannel = tilt
    tilt.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "start":
        result(self.startMotion())
      case "stop":
        self.stopMotion()
        result(true)
      case "playAlert":
        let args = call.arguments as? [String: Any]
        let danger = args?["danger"] as? Bool ?? false
        AudioServicesPlaySystemSound(danger ? 1005 : 1057)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let loc = FlutterMethodChannel(name: "fyp/location", binaryMessenger: registrar.messenger())
    locationChannel = loc
    loc.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      if call.method == "getCurrentLocation" {
        self.fetchLocation(result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func startMotion() -> [String: Any] {
    guard motionManager.isDeviceMotionAvailable else {
      return ["supported": false, "sensor": "", "type": "none"]
    }
    motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
    motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
      guard let self = self, let m = motion else { return }
      // CoreMotion gravity points DOWN (-worldUp); negate to get world-up in device axes.
      let ux = -m.gravity.x
      let uy = -m.gravity.y
      let uz = -m.gravity.z
      let norm = sqrt(ux * ux + uy * uy + uz * uz)
      guard norm.isFinite && norm >= 0.9 else { return }

      let rx = m.rotationRate.x
      let ry = m.rotationRate.y
      let rz = m.rotationRate.z
      let gyroDeg = sqrt(rx * rx + ry * ry + rz * rz) * 180.0 / Double.pi

      let ax = m.userAcceleration.x
      let ay = m.userAcceleration.y
      let az = m.userAcceleration.z
      let impactG = sqrt(ax * ax + ay * ay + az * az)

      let rot = self.currentScreenRotation()
      let ms = Int(ProcessInfo.processInfo.systemUptime * 1000.0)

      self.tiltChannel?.invokeMethod("sample", arguments: [
        "x": ux / norm,
        "y": uy / norm,
        "z": uz / norm,
        "rotation": rot,
        "accuracy": 3,
        "elapsedMs": ms,
        "gyroDegPerSec": gyroDeg,
        "impactG": impactG,
      ])
    }
    UIApplication.shared.isIdleTimerDisabled = true
    return ["supported": true, "sensor": "CoreMotion DeviceMotion", "type": "game"]
  }

  private func stopMotion() {
    if motionManager.isDeviceMotionActive {
      motionManager.stopDeviceMotionUpdates()
    }
    UIApplication.shared.isIdleTimerDisabled = false
  }

  private func currentScreenRotation() -> Int {
    let orientation = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first?.interfaceOrientation ?? .portrait
    switch orientation {
    case .landscapeLeft:
      return 3
    case .landscapeRight:
      return 1
    case .portraitUpsideDown:
      return 2
    default:
      return 0
    }
  }

  private func fetchLocation(result: @escaping FlutterResult) {
    if locationManager == nil {
      let lm = CLLocationManager()
      lm.delegate = self
      lm.desiredAccuracy = kCLLocationAccuracyHundredMeters
      locationManager = lm
    }
    guard let lm = locationManager else {
      result(["ok": false, "error": "無法初始化定位服務"])
      return
    }
    if let cached = lm.location, abs(cached.timestamp.timeIntervalSinceNow) < 300 {
      result([
        "ok": true,
        "lat": cached.coordinate.latitude,
        "lon": cached.coordinate.longitude,
        "accuracyM": cached.horizontalAccuracy,
      ])
      return
    }
    pendingLocationResult = result
    lm.requestWhenInUseAuthorization()
    lm.requestLocation()
    DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) { [weak self] in
      guard let self = self, let pending = self.pendingLocationResult else { return }
      self.pendingLocationResult = nil
      if let fallback = lm.location {
        pending([
          "ok": true,
          "lat": fallback.coordinate.latitude,
          "lon": fallback.coordinate.longitude,
          "accuracyM": fallback.horizontalAccuracy,
        ])
      } else {
        pending(["ok": false, "error": "定位逾時，請確認已允許定位權限"])
      }
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let pending = pendingLocationResult, let loc = locations.last else { return }
    pendingLocationResult = nil
    pending([
      "ok": true,
      "lat": loc.coordinate.latitude,
      "lon": loc.coordinate.longitude,
      "accuracyM": loc.horizontalAccuracy,
    ])
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    guard let pending = pendingLocationResult else { return }
    pendingLocationResult = nil
    pending(["ok": false, "error": "定位失敗：\(error.localizedDescription)"])
  }
}
