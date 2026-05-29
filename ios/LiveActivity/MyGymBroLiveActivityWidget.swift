// MyGymBroLiveActivityWidget.swift
//
// Widget Extension target ONLY. Provides:
//   • Lock-screen / Notification-center layout
//   • Dynamic Island compact / minimal / expanded layouts
//
// Lives in the `MyGymBroLiveActivity` target. The attributes file
// `MyGymBroActivityAttributes.swift` must also be in this target.

import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.1, *)
public struct MyGymBroLiveActivityWidgetBundle: WidgetBundle {
    public init() {}
    public var body: some Widget {
        MyGymBroLiveActivityWidget()
    }
}

@available(iOS 16.1, *)
public struct MyGymBroLiveActivityWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: MyGymBroWorkoutAttributes.self) { context in
            // ── Lock-screen / Notification-center view ───────────────
            LockScreenView(context: context)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // ── Expanded (long-press) ────────────────────────────
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.exerciseName)
                            .font(.headline)
                            .lineLimit(1)
                        Text(context.state.setProgress)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TimerLabel(context: context)
                        .font(.title3.monospacedDigit())
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    StatusLine(context: context)
                        .font(.subheadline)
                }
            } compactLeading: {
                Image(systemName: context.state.isResting
                      ? "timer"
                      : "figure.strengthtraining.traditional")
                    .foregroundStyle(brandTint)
            } compactTrailing: {
                TimerLabel(context: context)
                    .monospacedDigit()
                    .font(.caption2.weight(.semibold))
            } minimal: {
                Image(systemName: context.state.isResting
                      ? "timer"
                      : "dumbbell.fill")
                    .foregroundStyle(brandTint)
            }
            .keylineTint(brandTint)
        }
    }

    /// The MyGymBro accent — keep in sync with `AppColors.accent` so the
    /// Live Activity feels native to the app.
    private var brandTint: Color {
        Color(red: 0.82, green: 1.0, blue: 0.0) // ~ #D2FF00
    }
}

// ─────────────────────────────────────────────────────────────────────────
// Lock-screen view
// ─────────────────────────────────────────────────────────────────────────

@available(iOS 16.1, *)
private struct LockScreenView: View {
    let context: ActivityViewContext<MyGymBroWorkoutAttributes>

    var body: some View {
        HStack(spacing: 14) {
            // Status icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 44, height: 44)
                Image(systemName: context.state.isResting
                      ? "timer"
                      : "figure.strengthtraining.traditional")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(brandTint)
            }

            // Exercise + progress
            VStack(alignment: .leading, spacing: 2) {
                Text(context.state.exerciseName)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(context.state.setProgress)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }

            Spacer()

            // Timer (rest countdown or session elapsed)
            VStack(alignment: .trailing, spacing: 2) {
                Text(context.state.isResting ? "REST" : "ELAPSED")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.5))
                TimerLabel(context: context)
                    .font(.title2.monospacedDigit().weight(.bold))
                    .foregroundStyle(.white)
            }
        }
    }

    private var brandTint: Color {
        Color(red: 0.82, green: 1.0, blue: 0.0)
    }
}

// ─────────────────────────────────────────────────────────────────────────
// Reusable timer label — picks countdown vs elapsed based on state.
// SwiftUI's Text(timerInterval:) ticks on-device so we don't push every sec.
// ─────────────────────────────────────────────────────────────────────────

@available(iOS 16.1, *)
private struct TimerLabel: View {
    let context: ActivityViewContext<MyGymBroWorkoutAttributes>

    var body: some View {
        if context.state.isResting, let endsAt = context.state.restEndsAt {
            // Countdown — show the time remaining until restEndsAt.
            Text(timerInterval: Date()...endsAt, countsDown: true)
        } else {
            // Elapsed — show how long the session has been running.
            Text(timerInterval: context.attributes.sessionStartedAt...Date.distantFuture,
                 countsDown: false)
        }
    }
}

@available(iOS 16.1, *)
private struct StatusLine: View {
    let context: ActivityViewContext<MyGymBroWorkoutAttributes>

    var body: some View {
        Text(context.state.isResting
             ? "Resting — next set up soon"
             : "Crushing it. Lock it in.")
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}
