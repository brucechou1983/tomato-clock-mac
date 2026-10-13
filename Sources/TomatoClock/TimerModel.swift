import AppKit
import Combine
import TomatoCore
import UserNotifications

@MainActor
final class TimerModel: ObservableObject {
    static let shared = TimerModel()

    @Published private(set) var engine: TimerEngine
    @Published var preferences: TimerPreferences
    @Published private(set) var records: [SessionRecord]
    @Published private(set) var now = Date()
    @Published var pendingCompletion: Completion?
    @Published var settingsPresented = false

    let reminders = ReminderService()
    var onCompletion: ((Completion) -> Void)?
    var onDismissReminder: (() -> Void)?
    var onRevealMainWindow: (() -> Void)?
    private var ticker: Timer?
    private var notificationTask: Task<Void, Never>?
    private let defaults: UserDefaults
    private let isPreview: Bool
    private var wakeObserver: NSObjectProtocol?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isPreview = ProcessInfo.processInfo.arguments.contains("--ui-test")
            || Bundle.main.object(forInfoDictionaryKey: "TomatoUITestMode") as? Bool == true
        let decoder = JSONDecoder()
        let savedPreferences = isPreview ? nil : defaults.data(forKey: "preferences")
        let loadedPreferences = savedPreferences.flatMap { try? decoder.decode(TimerPreferences.self, from: $0) } ?? .init()
        preferences = loadedPreferences
        let savedTimer = isPreview ? nil : defaults.data(forKey: "timer")
        engine = savedTimer.flatMap { try? decoder.decode(TimerEngine.self, from: $0) }
            ?? TimerEngine(preferences: loadedPreferences)
        let savedRecords = isPreview ? nil : defaults.data(forKey: "records")
        records = savedRecords.flatMap { try? decoder.decode([SessionRecord].self, from: $0) } ?? []

        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        if let ticker { RunLoop.main.add(ticker, forMode: .common) }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.tick() } }
        Task { await reminders.refreshAuthorization() }
    }

    var summary: DailySummary { DailySummary(records: records, now: now) }
    var isRunning: Bool { engine.phase == .running }
    var isBreak: Bool { engine.kind != .focus }
    var nextBreakMinutes: Int { Int(engine.duration / 60) }

    var actionTitle: String {
        if isRunning { return "暫停一下" }
        if engine.phase == .paused { return "繼續\(engine.kind.title)" }
        return engine.kind == .focus ? "開始專注" : "開始休息"
    }

    var statusTitle: String {
        switch engine.phase {
        case .ready: isBreak ? "讓身體也換一口氣" : "一次，只專心做好一件事"
        case .running: isBreak ? "放下螢幕，留一點時間給自己" : "慢慢來，你正在前進"
        case .paused: "已暫停，準備好了再繼續"
        }
    }

    func toggle() {
        if isRunning {
            let completion = engine.pause(at: Date(), preferences: preferences)
            cancelNotification()
            if let completion { finish(completion) }
        } else {
            dismissReminder()
            engine.start(at: Date())
            scheduleNotification()
        }
        save()
    }

    func select(_ kind: SessionKind) {
        cancelNotification()
        dismissReminder()
        engine.select(kind, preferences: preferences)
        save()
    }

    func reset() {
        cancelNotification()
        dismissReminder()
        engine.reset(preferences: preferences)
        save()
    }

    func applyPreferences(_ value: TimerPreferences) {
        preferences = TimerPreferences(focusMinutes: value.focusMinutes,
                                       shortBreakMinutes: value.shortBreakMinutes,
                                       longBreakMinutes: value.longBreakMinutes,
                                       soundEnabled: value.soundEnabled)
        engine.apply(preferences)
        if isRunning { scheduleNotification() }
        save()
    }

    func tick() {
        now = Date()
        if let completion = engine.tick(at: now, preferences: preferences) {
            finish(completion)
            save()
        }
    }

    func restoreNotifications() {
        tick()
        if isRunning { scheduleNotification() }
    }

    func beginNextSession() {
        dismissReminder()
        if !isRunning { toggle() }
    }

    func dismissReminder() {
        pendingCompletion = nil
        onDismissReminder?()
    }

    func prepareToQuit() {
        if isRunning {
            if let completion = engine.pause(at: Date(), preferences: preferences) {
                records.append(.init(kind: completion.kind, seconds: completion.duration,
                                     endedAt: completion.endedAt))
            }
        }
        cancelNotification()
        save()
    }

    private func finish(_ completion: Completion) {
        records.append(.init(kind: completion.kind, seconds: completion.duration,
                             endedAt: completion.endedAt))
        let cutoff = Date().addingTimeInterval(-90 * 24 * 3600)
        records.removeAll { $0.endedAt < cutoff }
        pendingCompletion = completion
        if preferences.soundEnabled && !reminders.isAuthorized {
            NSSound(named: "Glass")?.play()
        }
        onCompletion?(completion)
    }

    private func scheduleNotification() {
        cancelNotification()
        guard !isPreview else { return }
        notificationTask = Task { [weak self] in
            guard let self else { return }
            await reminders.requestIfNeeded()
            guard !Task.isCancelled, engine.phase == .running,
                  let deadline = engine.deadline else { return }
            let requestID = await reminders.schedule(kind: engine.kind, seconds: deadline.timeIntervalSinceNow,
                                                     sound: preferences.soundEnabled)
            // A pause/reset may occur while Notification Center accepts the request.
            if Task.isCancelled, let requestID { reminders.cancel(identifier: requestID) }
        }
    }

    private func cancelNotification() {
        notificationTask?.cancel()
        notificationTask = nil
        reminders.cancel()
    }

    private func save() {
        guard !isPreview else { return }
        let encoder = JSONEncoder()
        defaults.set(try? encoder.encode(preferences), forKey: "preferences")
        defaults.set(try? encoder.encode(engine), forKey: "timer")
        defaults.set(try? encoder.encode(records), forKey: "records")
    }
}

@MainActor
final class ReminderService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published private(set) var authorization: UNAuthorizationStatus = .notDetermined
    @Published private(set) var errorMessage: String?
    var onNotificationAction: ((String) -> Void)?
    private let center = UNUserNotificationCenter.current()

    var isAuthorized: Bool { authorization == .authorized || authorization == .provisional }
    var statusText: String {
        switch authorization {
        case .authorized, .provisional, .ephemeral: "已開啟"
        case .denied: "未允許"
        case .notDetermined: "尚未開啟"
        @unknown default: "尚未開啟"
        }
    }

    override init() {
        super.init()
        center.delegate = self
        let start = UNNotificationAction(identifier: "start-break", title: "開始休息", options: [.foreground])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: "movement", actions: [start], intentIdentifiers: [])
        ])
    }

    func refreshAuthorization() async {
        authorization = await center.notificationSettings().authorizationStatus
    }

    func requestIfNeeded() async {
        await refreshAuthorization()
        guard authorization == .notDetermined else { return }
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
            await refreshAuthorization()
        } catch {
            errorMessage = "系統通知暫時無法開啟；起身提醒視窗仍會出現。"
        }
    }

    func schedule(kind: SessionKind, seconds: TimeInterval, sound: Bool) async -> String? {
        guard isAuthorized, seconds > 0 else { return nil }
        let content = UNMutableNotificationContent()
        content.title = kind == .focus ? "該起來動一動了" : "休息結束，重新出發"
        content.body = kind == .focus
            ? "離開螢幕，走幾步、喝口水，伸展一下肩頸。"
            : "準備好了，就開始下一段專注吧。"
        if kind == .focus { content.categoryIdentifier = "movement" }
        if sound { content.sound = .default }
        let identifier = "tomato-session-end-" + UUID().uuidString
        let request = UNNotificationRequest(identifier: identifier, content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false))
        do {
            try await center.add(request)
            errorMessage = nil
            return identifier
        } catch {
            errorMessage = "系統通知排程失敗；起身提醒視窗仍會出現。"
            return nil
        }
    }

    func cancel() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    func cancel(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse) async {
        let action = response.actionIdentifier
        await MainActor.run { self.onNotificationAction?(action) }
    }
}
