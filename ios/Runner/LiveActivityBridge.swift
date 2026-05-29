// LiveActivityBridge.swift
//
// Connects Flutter's `live_activity` MethodChannel to ActivityKit.
// Lives in the main `Runner` target. Must also reference
// `MyGymBroActivityAttributes.swift` (add that file to BOTH targets).
//
// All entry points fail gracefully on < iOS 16.1 — the Dart side already
// treats the bridge as best-effort, so a missing entitlement or unsupported
// OS version becomes a silent no-op rather than a crash.

import ActivityKit
import Flutter
import Foundation

@available(iOS 16.1, *)
final class LiveActivityBridge: NSObject {

    static let channelName = "com.mygymbro/live_activity"

    /// Currently-running workout activity, if any. ActivityKit returns the
    /// authoritative handle from `Activity.request(...)`; we cache it so
    /// `update` and `end` can route to the same activity without scanning.
    private var current: Activity<MyGymBroWorkoutAttributes>?

    // ── MethodChannel setup ───────────────────────────────────────────

    func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: LiveActivityBridge.channelName,
            binaryMessenger: registrar.messenger()
        )
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call: call, result: result)
        }
    }

    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isSupported":
            result(ActivityAuthorizationInfo().areActivitiesEnabled)

        case "start":
            guard let args = call.arguments as? [String: Any] else {
                return result(FlutterError(code: "BAD_ARGS",
                                           message: "expected map",
                                           details: nil))
            }
            start(args: args, result: result)

        case "updateRest":
            guard let args = call.arguments as? [String: Any] else {
                return result(FlutterError(code: "BAD_ARGS",
                                           message: "expected map",
                                           details: nil))
            }
            updateRest(args: args, result: result)

        case "updateActive":
            guard let args = call.arguments as? [String: Any] else {
                return result(FlutterError(code: "BAD_ARGS",
                                           message: "expected map",
                                           details: nil))
            }
            updateActive(args: args, result: result)

        case "end":
            end(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // ── ActivityKit operations ────────────────────────────────────────

    private func start(args: [String: Any], result: @escaping FlutterResult) {
        // If a previous activity is already running (e.g. app was killed and
        // relaunched without ending it cleanly), end it first so we don't
        // accumulate stale activities on the lock screen.
        if current != nil {
            endInternal()
        }

        let exerciseName = args["exerciseName"] as? String ?? "Workout"
        let setProgress = args["setProgress"] as? String ?? ""
        let startedAtMillis = args["sessionStartedAtMillis"] as? Int
            ?? Int(Date().timeIntervalSince1970 * 1000)

        let attributes = MyGymBroWorkoutAttributes(
            sessionStartedAt: Date(
                timeIntervalSince1970: TimeInterval(startedAtMillis) / 1000.0
            )
        )
        let state = MyGymBroWorkoutAttributes.ContentState(
            exerciseName: exerciseName,
            setProgress: setProgress,
            isResting: false,
            restEndsAt: nil
        )

        do {
            let activity: Activity<MyGymBroWorkoutAttributes>
            if #available(iOS 16.2, *) {
                activity = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: state, staleDate: nil),
                    pushType: nil
                )
            } else {
                activity = try Activity.request(
                    attributes: attributes,
                    contentState: state,
                    pushType: nil
                )
            }
            current = activity
            result(activity.id)
        } catch {
            // Most common cause: Live Activities disabled in Settings.
            // Don't surface as a Flutter error — it would noisy-up Crashlytics
            // for a user-controlled config. Return null so Dart no-ops.
            NSLog("[LiveActivity] start failed: \(error)")
            result(nil)
        }
    }

    private func updateRest(args: [String: Any], result: @escaping FlutterResult) {
        guard let activity = current else { return result(false) }

        let exerciseName = args["exerciseName"] as? String
            ?? activity.contentState.exerciseName
        let setProgress = args["setProgress"] as? String
            ?? activity.contentState.setProgress
        let restEndsAtMillis = args["restEndsAtMillis"] as? Int

        let restEndsAt = restEndsAtMillis.map {
            Date(timeIntervalSince1970: TimeInterval($0) / 1000.0)
        }

        let newState = MyGymBroWorkoutAttributes.ContentState(
            exerciseName: exerciseName,
            setProgress: setProgress,
            isResting: true,
            restEndsAt: restEndsAt
        )

        Task {
            if #available(iOS 16.2, *) {
                await activity.update(
                    ActivityContent(state: newState, staleDate: nil)
                )
            } else {
                await activity.update(using: newState)
            }
            result(true)
        }
    }

    private func updateActive(args: [String: Any], result: @escaping FlutterResult) {
        guard let activity = current else { return result(false) }

        let exerciseName = args["exerciseName"] as? String
            ?? activity.contentState.exerciseName
        let setProgress = args["setProgress"] as? String
            ?? activity.contentState.setProgress

        let newState = MyGymBroWorkoutAttributes.ContentState(
            exerciseName: exerciseName,
            setProgress: setProgress,
            isResting: false,
            restEndsAt: nil
        )

        Task {
            if #available(iOS 16.2, *) {
                await activity.update(
                    ActivityContent(state: newState, staleDate: nil)
                )
            } else {
                await activity.update(using: newState)
            }
            result(true)
        }
    }

    private func end(result: @escaping FlutterResult) {
        endInternal()
        result(true)
    }

    private func endInternal() {
        guard let activity = current else { return }
        current = nil
        Task {
            if #available(iOS 16.2, *) {
                await activity.end(nil, dismissalPolicy: .immediate)
            } else {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }
}
