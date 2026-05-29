// MyGymBroActivityAttributes.swift
//
// Shared between the main `Runner` target and the
// `MyGymBroLiveActivity` widget extension. After creating both
// targets in Xcode, add this file to BOTH (File Inspector → Target
// Membership → check both Runner and MyGymBroLiveActivity).
//
// iOS 16.1+ is required for ActivityKit.

import ActivityKit
import Foundation

@available(iOS 16.1, *)
public struct MyGymBroWorkoutAttributes: ActivityAttributes {

    /// Mutable, push-updatable state for the running activity.
    /// Keep this lean — Apple limits the encoded ContentState size.
    public struct ContentState: Codable, Hashable {

        /// Name of the exercise currently being performed.
        public var exerciseName: String

        /// Short progress label, e.g. "Set 2 of 4".
        public var setProgress: String

        /// True while the user is between sets and the rest timer is running.
        public var isResting: Bool

        /// When the rest timer is scheduled to expire. SwiftUI's
        /// `Text(timerInterval:)` reads this for a self-updating
        /// countdown that doesn't require us to push every second.
        /// Nil when `isResting` is false.
        public var restEndsAt: Date?

        public init(
            exerciseName: String,
            setProgress: String,
            isResting: Bool,
            restEndsAt: Date?
        ) {
            self.exerciseName = exerciseName
            self.setProgress = setProgress
            self.isResting = isResting
            self.restEndsAt = restEndsAt
        }
    }

    /// Immutable attributes set once at activity start.
    /// Stored at activity creation; cannot change for the activity's lifetime.
    public var sessionStartedAt: Date

    public init(sessionStartedAt: Date) {
        self.sessionStartedAt = sessionStartedAt
    }
}
