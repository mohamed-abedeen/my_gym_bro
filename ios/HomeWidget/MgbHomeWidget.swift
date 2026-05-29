// MgbHomeWidget.swift
//
// Always-on home-screen / lock-screen widget for MyGymBro.
//
// Lives in a separate `MgbHomeWidget` widget extension target (NOT the
// MyGymBroLiveActivity target — they coexist but are different extensions).
// Reads from the App Group `group.com.mygymbro.widgets` shared
// UserDefaults, populated by `WidgetSyncService` on the Dart side. Same
// key contract as the Android AppWidgetProvider so a single Dart
// service feeds both platforms.
//
// iOS 16+ deployment target so we can ship the small + medium widgets to
// the standby / lock-screen widget gallery added in iOS 16.

import SwiftUI
import WidgetKit

// ─────────────────────────────────────────────────────────────────────────
// Shared App Group key — MUST match the value in WidgetSyncService.
// ─────────────────────────────────────────────────────────────────────────
private let kAppGroupId = "group.com.mygymbro.widgets"

// Brand accent. Matches AppColors.accent (#D2FF00) so the widget feels
// native to the app, not a generic OS chrome.
private let kAccent = Color(red: 0.82, green: 1.0, blue: 0.0)

// ─────────────────────────────────────────────────────────────────────────
// Timeline entry — one snapshot of the values WidgetSyncService wrote.
// ─────────────────────────────────────────────────────────────────────────
struct MgbWidgetEntry: TimelineEntry {
    let date: Date
    let streakDays: Int
    let streakLabel: String
    let nextFocus: String      // muscle group, possibly empty
    let nextCta: String        // tone-aware short CTA
}

// ─────────────────────────────────────────────────────────────────────────
// Provider — pulls latest values from shared UserDefaults.
// We use `atEnd` reload policy: the widget refreshes on its own at a
// modest pace, and `WidgetCenter.shared.reloadTimelines` (called from
// the home_widget plugin on Dart-side writes) handles real-time updates.
// ─────────────────────────────────────────────────────────────────────────
struct MgbWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> MgbWidgetEntry {
        MgbWidgetEntry(
            date: Date(),
            streakDays: 0,
            streakLabel: "Start a streak",
            nextFocus: "",
            nextCta: "Open MyGymBro"
        )
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (MgbWidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<MgbWidgetEntry>) -> Void) {
        let entry = loadEntry()
        // Refresh every 2 hours as a safety net. The primary refresh
        // signal is the Dart-side reloadTimelines call.
        let next = Calendar.current.date(byAdding: .hour, value: 2, to: entry.date)
            ?? entry.date.addingTimeInterval(7200)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadEntry() -> MgbWidgetEntry {
        let defaults = UserDefaults(suiteName: kAppGroupId)
        let days = defaults?.integer(forKey: "streak_days") ?? 0
        let label = defaults?.string(forKey: "streak_label")
            ?? defaultStreakLabel(days: days)
        let focus = defaults?.string(forKey: "next_focus") ?? ""
        let cta = defaults?.string(forKey: "next_cta")
            ?? "Tap to open MyGymBro"
        return MgbWidgetEntry(
            date: Date(),
            streakDays: days,
            streakLabel: label,
            nextFocus: focus,
            nextCta: cta
        )
    }

    private func defaultStreakLabel(days: Int) -> String {
        if days <= 0 { return "Start a streak" }
        if days == 1 { return "1-day streak" }
        return "\(days)-day streak"
    }
}

// ─────────────────────────────────────────────────────────────────────────
// Widget views — small + medium + lock-screen accessory variants.
// ─────────────────────────────────────────────────────────────────────────

struct MgbWidgetEntryView: View {
    let entry: MgbWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallBody
        case .systemMedium:
            mediumBody
        case .accessoryRectangular:
            accessoryRectangular
        case .accessoryInline:
            accessoryInline
        default:
            mediumBody
        }
    }

    // ── Small (2x2): streak only, large flame and number ─────────────
    private var smallBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.streakDays > 0 ? "🔥" : "💤")
                .font(.system(size: 28))
            Text(entry.streakLabel)
                .font(.headline.bold())
                .foregroundStyle(kAccent)
                .lineLimit(1)
            Spacer()
            Text("MyGymBro")
                .font(.system(size: 9, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(Color.black, for: .widget)
    }

    // ── Medium (4x2): streak block + next-focus block ────────────────
    private var mediumBody: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.streakDays > 0 ? "🔥" : "💤")
                    .font(.system(size: 22))
                Text(entry.streakLabel)
                    .font(.title3.bold())
                    .foregroundStyle(kAccent)
                    .lineLimit(1)
                Text("MyGymBro")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .overlay(Color.white.opacity(0.2))

            VStack(alignment: .leading, spacing: 4) {
                Text("NEXT")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                Text(entry.nextFocus.isEmpty ? "Ready when you are" : "Train \(entry.nextFocus)")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(entry.nextCta)
                    .font(.caption)
                    .foregroundStyle(kAccent)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .containerBackground(Color.black, for: .widget)
    }

    // ── Lock-screen accessoryRectangular (iOS 16+) ───────────────────
    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.streakLabel)
                .font(.headline)
            if !entry.nextFocus.isEmpty {
                Text("Train \(entry.nextFocus)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // ── Lock-screen inline ───────────────────────────────────────────
    private var accessoryInline: some View {
        Text("🔥 \(entry.streakLabel)")
    }
}

// ─────────────────────────────────────────────────────────────────────────
// Widget entry point — must be marked @main in the widget bundle.
// The bundle wrapper at the bottom registers this with WidgetKit.
// ─────────────────────────────────────────────────────────────────────────

struct MgbHomeWidget: Widget {
    let kind: String = "MgbHomeWidget"  // MUST match WidgetSyncService.iOSName

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MgbWidgetProvider()) { entry in
            MgbWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("MyGymBro")
        .description("Your streak and what to train next.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

// ─────────────────────────────────────────────────────────────────────────
// Widget bundle entry point. Add additional widgets (Live Activity is in
// a DIFFERENT extension target so it's not bundled here) to this list as
// they ship.
// ─────────────────────────────────────────────────────────────────────────

@main
struct MgbHomeWidgetBundle: WidgetBundle {
    var body: some Widget {
        MgbHomeWidget()
    }
}
