import Foundation
import Testing
@testable import TomatoCore

private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

@Test func defaultsAreReady() {
    let engine = TimerEngine()
    #expect(engine.phase == .ready)
    #expect(engine.kind == .focus)
    #expect(engine.clockText == "25:00")
    #expect(engine.deadline == nil)
}

@Test func delayedTicksUseTheDeadline() {
    let preferences = TimerPreferences()
    var engine = TimerEngine()
    engine.start(at: epoch)
    #expect(engine.tick(at: epoch.addingTimeInterval(73.4), preferences: preferences) == nil)
    #expect(abs(engine.remaining - 1426.6) < 0.001)
    #expect(engine.clockText == "23:47")
}

@Test func pauseAndResumePreserveRemainingTime() {
    let preferences = TimerPreferences()
    var engine = TimerEngine()
    engine.start(at: epoch)
    #expect(engine.pause(at: epoch.addingTimeInterval(60), preferences: preferences) == nil)
    #expect(engine.phase == .paused)
    #expect(engine.remaining == 1440)
    #expect(engine.deadline == nil)
    #expect(engine.tick(at: epoch.addingTimeInterval(500), preferences: preferences) == nil)
    engine.start(at: epoch.addingTimeInterval(600))
    #expect(engine.deadline == epoch.addingTimeInterval(2040))
    #expect(engine.tick(at: epoch.addingTimeInterval(660), preferences: preferences) == nil)
    #expect(engine.remaining == 1380)
}

@Test func wakeAfterDeadlineCompletesExactlyOneSession() {
    let preferences = TimerPreferences()
    var engine = TimerEngine()
    engine.start(at: epoch)
    let completion = engine.tick(at: epoch.addingTimeInterval(10_000), preferences: preferences)
    #expect(completion?.kind == .focus)
    #expect(completion?.endedAt == epoch.addingTimeInterval(1500))
    #expect(engine.completedFocusCount == 1)
    #expect(engine.kind == .shortBreak)
    #expect(engine.phase == .ready)
    #expect(engine.clockText == "05:00")
    #expect(engine.tick(at: epoch.addingTimeInterval(20_000), preferences: preferences) == nil)
    #expect(engine.completedFocusCount == 1)
}

@Test func fourthFocusSelectsLongBreak() {
    let preferences = TimerPreferences()
    var engine = TimerEngine()
    for count in 1...4 {
        engine.select(.focus, preferences: preferences)
        engine.start(at: epoch)
        let completion = engine.tick(at: epoch.addingTimeInterval(1500), preferences: preferences)
        #expect(completion?.nextKind == (count == 4 ? .longBreak : .shortBreak))
    }
    #expect(engine.kind == .longBreak)
    #expect(engine.clockText == "15:00")
}

@Test func completedBreakReturnsToFocusWithoutAutoStarting() {
    let preferences = TimerPreferences()
    var engine = TimerEngine()
    engine.select(.shortBreak, preferences: preferences)
    engine.start(at: epoch)
    let completion = engine.tick(at: epoch.addingTimeInterval(300), preferences: preferences)
    #expect(completion?.kind == .shortBreak)
    #expect(engine.kind == .focus)
    #expect(engine.phase == .ready)
    #expect(engine.completedFocusCount == 0)
}

@Test func resetAndSwitchDoNotCountIncompleteSessions() {
    let preferences = TimerPreferences()
    var engine = TimerEngine()
    engine.start(at: epoch)
    _ = engine.tick(at: epoch.addingTimeInterval(100), preferences: preferences)
    engine.reset(preferences: preferences)
    #expect(engine.clockText == "25:00")
    #expect(engine.phase == .ready)
    #expect(engine.completedFocusCount == 0)
    engine.select(.longBreak, preferences: preferences)
    #expect(engine.clockText == "15:00")
    #expect(engine.deadline == nil)
}

@Test func settingsDoNotRewriteAnActiveSession() {
    var engine = TimerEngine()
    engine.start(at: epoch)
    let preferences = TimerPreferences(focusMinutes: 40, shortBreakMinutes: 8)
    engine.apply(preferences)
    #expect(engine.duration == 1500)
    #expect(engine.deadline == epoch.addingTimeInterval(1500))
    _ = engine.pause(at: epoch.addingTimeInterval(100), preferences: preferences)
    engine.apply(preferences)
    #expect(engine.duration == 1500)
    #expect(engine.remaining == 1400)
    engine.reset(preferences: preferences)
    #expect(engine.duration == 2400)
}

@Test func pauseAtDeadlinePreservesTheCompletion() {
    let preferences = TimerPreferences()
    var engine = TimerEngine()
    engine.start(at: epoch)
    let completion = engine.pause(at: epoch.addingTimeInterval(1500), preferences: preferences)
    #expect(completion?.kind == .focus)
    #expect(engine.kind == .shortBreak)
    #expect(engine.phase == .ready)
}

@Test func persistedRunningSessionKeepsItsDeadline() throws {
    var engine = TimerEngine()
    engine.start(at: epoch)
    let data = try JSONEncoder().encode(engine)
    var restored = try JSONDecoder().decode(TimerEngine.self, from: data)
    #expect(restored == engine)
    _ = restored.tick(at: epoch.addingTimeInterval(600), preferences: .init())
    #expect(restored.clockText == "15:00")
}

@Test func dailySummaryUsesLocalCalendarAndCompletedSessions() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
    let midnight = calendar.startOfDay(for: epoch)
    let records = [
        SessionRecord(kind: .focus, seconds: 1500, endedAt: midnight.addingTimeInterval(-1)),
        SessionRecord(kind: .focus, seconds: 1500, endedAt: midnight.addingTimeInterval(1)),
        SessionRecord(kind: .focus, seconds: 600, endedAt: midnight.addingTimeInterval(3600)),
        SessionRecord(kind: .shortBreak, seconds: 300, endedAt: midnight.addingTimeInterval(1800))
    ]
    let summary = DailySummary(records: records, now: midnight.addingTimeInterval(7200), calendar: calendar)
    #expect(summary.focusCount == 2)
    #expect(summary.focusMinutes == 35)
    #expect(summary.breakCount == 1)
}

@Test func durationLimitsAndRoundingAreSafe() {
    let preferences = TimerPreferences(focusMinutes: 0, shortBreakMinutes: -1, longBreakMinutes: 999)
    #expect(preferences.focusMinutes == 1)
    #expect(preferences.shortBreakMinutes == 1)
    #expect(preferences.longBreakMinutes == 60)
    var engine = TimerEngine(preferences: preferences)
    engine.start(at: epoch)
    _ = engine.tick(at: epoch.addingTimeInterval(59.1), preferences: preferences)
    #expect(engine.clockText == "00:01")
    #expect(engine.progress >= 0 && engine.progress <= 1)
}
