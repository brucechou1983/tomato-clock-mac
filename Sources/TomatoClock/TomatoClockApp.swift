import AppKit
import SwiftUI
import TomatoCore

@main
struct TomatoClockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = TimerModel.shared

    var body: some Scene {
        Window("小番茄", id: "main") {
            MainView(model: model)
                .onAppear { configureMainWindow() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("設定⋯") {
                    revealMainWindow()
                    model.settingsPresented = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandMenu("計時") {
                Button(model.actionTitle) { model.toggle() }
                    .keyboardShortcut("p", modifiers: .command)
                Button("顯示小番茄") { revealMainWindow() }
                    .keyboardShortcut("1", modifiers: .command)
            }
        }

        MenuBarExtra {
            MenuBarView(model: model)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: model.isBreak ? "leaf" : "timer")
                if model.engine.phase != .ready {
                    Text(model.engine.clockText).monospacedDigit()
                    if model.engine.phase == .paused { Image(systemName: "pause.fill") }
                }
            }
            .accessibilityLabel("小番茄，\(model.engine.kind.title)，\(model.engine.clockText)")
        }
        .menuBarExtraStyle(.window)
    }

    private func configureMainWindow() {
        DispatchQueue.main.async {
            guard let window = NSApp.windows.first(where: { $0.title == "小番茄" }) else { return }
            window.identifier = NSUserInterfaceItemIdentifier("tomato-main")
            window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor(Theme.background)
            window.standardWindowButton(.zoomButton)?.isEnabled = false
        }
    }
}

@MainActor
func revealMainWindow() {
    TimerModel.shared.onRevealMainWindow?()
    if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "tomato-main" }) {
        window.makeKeyAndOrderFront(nil)
    }
    NSApp.activate(ignoringOtherApps: true)
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var reminderWindow: NSPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = TimerModel.shared
        model.onCompletion = { [weak self] completion in self?.showReminder(completion) }
        model.onDismissReminder = { [weak self] in self?.reminderWindow?.orderOut(nil) }
        model.reminders.onNotificationAction = { [weak self] action in
            model.tick()
            if action == "start-break", model.pendingCompletion?.kind == .focus {
                model.beginNextSession()
                revealMainWindow()
            } else if let completion = model.pendingCompletion {
                self?.showReminder(completion)
            } else {
                revealMainWindow()
            }
        }
        model.restoreNotifications()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        revealMainWindow()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        TimerModel.shared.prepareToQuit()
    }

    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) == reminderWindow {
            TimerModel.shared.pendingCompletion = nil
        }
    }

    private func showReminder(_ completion: Completion) {
        let model = TimerModel.shared
        let panel = reminderWindow ?? NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 410, height: 430),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false)
        panel.title = completion.kind == .focus ? "起身動一動" : "休息完成"
        panel.identifier = NSUserInterfaceItemIdentifier("tomato-reminder")
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.backgroundColor = NSColor(Theme.background)
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.delegate = self
        let hosting = NSHostingView(rootView: ReminderView(model: model, completion: completion))
        panel.contentView = hosting
        panel.setContentSize(hosting.fittingSize)
        panel.center()
        reminderWindow = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }
}
