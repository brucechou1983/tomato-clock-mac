import Foundation

public enum SessionKind: String, Codable, CaseIterable, Sendable {
    case focus, shortBreak, longBreak

    public var title: String {
        switch self {
        case .focus: "專注"
        case .shortBreak: "短休息"
        case .longBreak: "長休息"
        }
    }

    public var symbol: String {
        switch self {
        case .focus: "circle.dotted"
        case .shortBreak: "leaf"
        case .longBreak: "sun.max"
        }
    }
}

public struct TimerPreferences: Codable, Equatable, Sendable {
    public var focusMinutes: Int
    public var shortBreakMinutes: Int
    public var longBreakMinutes: Int
    public var soundEnabled: Bool

    public init(focusMinutes: Int = 25, shortBreakMinutes: Int = 5,
                longBreakMinutes: Int = 15, soundEnabled: Bool = true) {
        self.focusMinutes = min(90, max(1, focusMinutes))
        self.shortBreakMinutes = min(30, max(1, shortBreakMinutes))
        self.longBreakMinutes = min(60, max(1, longBreakMinutes))
        self.soundEnabled = soundEnabled
    }

    public func seconds(for kind: SessionKind) -> TimeInterval {
        let minutes = switch kind {
        case .focus: min(90, max(1, focusMinutes))
        case .shortBreak: min(30, max(1, shortBreakMinutes))
        case .longBreak: min(60, max(1, longBreakMinutes))
        }
        return TimeInterval(60 * minutes)
    }
}

public enum TimerPhase: String, Codable, Sendable {
    case ready, running, paused
}

public struct Completion: Equatable, Sendable {
    public let kind: SessionKind
    public let duration: TimeInterval
    public let endedAt: Date
    public let nextKind: SessionKind
}

/// The deadline is the source of truth, so delayed ticks and sleep cannot drift.
public struct TimerEngine: Codable, Equatable, Sendable {
    public private(set) var kind: SessionKind = .focus
    public private(set) var phase: TimerPhase = .ready
    public private(set) var duration: TimeInterval = 25 * 60
    public private(set) var remaining: TimeInterval = 25 * 60
    public private(set) var deadline: Date?
    public private(set) var completedFocusCount: Int = 0

    public init(preferences: TimerPreferences = .init()) {
        duration = preferences.seconds(for: .focus)
        remaining = duration
    }

    public var progress: Double {
        max(0, min(1, 1 - remaining / max(1, duration)))
    }

    public var clockText: String {
        let seconds = max(0, Int(ceil(remaining)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    public mutating func start(at now: Date) {
        guard phase != .running else { return }
        deadline = now.addingTimeInterval(remaining)
        phase = .running
    }

    /// Returns a completion if pausing races with the session deadline.
    public mutating func pause(at now: Date, preferences: TimerPreferences) -> Completion? {
        guard phase == .running else { return nil }
        if let completion = tick(at: now, preferences: preferences) { return completion }
        deadline = nil
        phase = .paused
        return nil
    }

    public mutating func select(_ kind: SessionKind, preferences: TimerPreferences) {
        self.kind = kind
        duration = preferences.seconds(for: kind)
        remaining = duration
        deadline = nil
        phase = .ready
    }

    public mutating func reset(preferences: TimerPreferences) {
        select(kind, preferences: preferences)
    }

    public mutating func apply(_ preferences: TimerPreferences) {
        // A settings edit only changes the next session, never an active one.
        guard phase == .ready else { return }
        select(kind, preferences: preferences)
    }

    public mutating func tick(at now: Date, preferences: TimerPreferences) -> Completion? {
        guard phase == .running, let deadline else { return nil }
        remaining = max(0, deadline.timeIntervalSince(now))
        guard remaining == 0 else { return nil }

        let finishedKind = kind
        let finishedDuration = duration
        if kind == .focus { completedFocusCount += 1 }
        let nextKind: SessionKind = kind == .focus
            ? (completedFocusCount.isMultiple(of: 4) ? .longBreak : .shortBreak)
            : .focus
        select(nextKind, preferences: preferences)
        return Completion(kind: finishedKind, duration: finishedDuration,
                          endedAt: deadline, nextKind: nextKind)
    }
}

public struct SessionRecord: Codable, Equatable, Sendable {
    public let kind: SessionKind
    public let seconds: TimeInterval
    public let endedAt: Date

    public init(kind: SessionKind, seconds: TimeInterval, endedAt: Date) {
        self.kind = kind
        self.seconds = seconds
        self.endedAt = endedAt
    }
}

public struct DailySummary: Equatable, Sendable {
    public let focusCount: Int
    public let focusMinutes: Int
    public let breakCount: Int

    public init(records: [SessionRecord], now: Date, calendar: Calendar = .current) {
        let today = records.filter { calendar.isDate($0.endedAt, inSameDayAs: now) }
        let focus = today.filter { $0.kind == .focus }
        focusCount = focus.count
        focusMinutes = Int(focus.reduce(0) { $0 + $1.seconds } / 60)
        breakCount = today.filter { $0.kind != .focus }.count
    }
}
