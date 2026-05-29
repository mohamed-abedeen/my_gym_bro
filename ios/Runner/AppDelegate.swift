import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    let registry = engineBridge.pluginRegistry
    GeneratedPluginRegistrant.register(with: registry)

    // ── Live Activities (iOS 16.1+) ──────────────────────────────────────
    // ActivityKit is gated on iOS 16.1. The bridge itself is @available
    // 16.1+ so we only instantiate + register it on supported OS versions;
    // older iOS just silently no-ops which matches the Dart side's
    // best-effort contract.
    if #available(iOS 16.1, *) {
      let bridge = LiveActivityBridge()
      // The widget extension lives in its own target — the registrar we
      // want is for the main Runner so MethodChannel messages from
      // `lib/core/services/live_activity_service.dart` resolve here.
      if let registrar = registry.registrar(forPlugin: "LiveActivityBridge") {
        bridge.register(with: registrar)
        // Retain the bridge for the lifetime of the engine so the
        // MethodCallHandler stays alive across calls.
        LiveActivityBridgeHolder.shared.bridge = bridge
      }
    }
  }
}

/// Strong reference holder so the bridge isn't dealloc'd after registration.
@available(iOS 16.1, *)
private final class LiveActivityBridgeHolder {
  static let shared = LiveActivityBridgeHolder()
  var bridge: LiveActivityBridge?
}
