import AppKit
import SwiftUI
import TomatoCore

struct SettingsView: View {
    @ObservedObject var model: TimerModel
    @ObservedObject var reminders: ReminderService
    @Environment(\.dismiss) private var dismiss
    @State private var draft = TimerPreferences()

    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("找到你的節奏")
                        .font(.system(size: 23, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text("簡單設定，讓專注和休息剛剛好。")
                        .font(.system(size: 12)).foregroundStyle(Theme.muted)
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .buttonStyle(QuietIconButtonStyle())
                    .accessibilityLabel("關閉設定")
                    .keyboardShortcut(.cancelAction)
            }

            VStack(spacing: 17) {
                durationRow("專注", symbol: "circle.dotted", value: $draft.focusMinutes, range: 1...90)
                Divider()
                durationRow("短休息", symbol: "leaf", value: $draft.shortBreakMinutes, range: 1...30)
                Divider()
                durationRow("長休息", symbol: "sun.max", value: $draft.longBreakMinutes, range: 1...60)
            }
            .padding(20)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 17))

            VStack(alignment: .leading, spacing: 15) {
                Toggle("提醒音效", isOn: $draft.soundEnabled)
                    .toggleStyle(.switch)
                HStack {
                    Text("系統通知")
                    Spacer()
                    Text(reminders.statusText).foregroundStyle(Theme.muted)
                    if reminders.authorization == .notDetermined {
                        Button("開啟") { Task { await reminders.requestIfNeeded() } }
                    } else if reminders.authorization == .denied {
                        Button("系統設定") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
                Text("專注結束會顯示起身提醒視窗。允許系統通知後，也會收到通知；勿擾模式可能會隱藏橫幅。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if let error = reminders.errorMessage {
                    Text(error).font(.system(size: 11)).foregroundStyle(Theme.tomato)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(Theme.text)

            Text("每 4 段專注安排一次長休息。新的時間設定會套用到下一段，進行中的計時不受影響。")
                .font(.system(size: 11)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                model.applyPreferences(draft)
                dismiss()
            } label: { Text("儲存設定") }
                .buttonStyle(PrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
        }
        .padding(28)
        .frame(width: 420)
        .background(Theme.background)
        .tint(Theme.tomato)
        .onAppear {
            draft = model.preferences
            Task { await reminders.refreshAuthorization() }
        }
    }

    private func durationRow(_ title: String, symbol: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: 11) {
            Image(systemName: symbol).foregroundStyle(Theme.muted).frame(width: 20)
                .accessibilityHidden(true)
            Text(title).font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.text)
            Spacer()
            Text("\(value.wrappedValue)")
                .font(.system(size: 19, weight: .medium, design: .rounded))
                .monospacedDigit().foregroundStyle(Theme.text)
                .frame(width: 30, alignment: .trailing)
            Text("分鐘").font(.system(size: 11)).foregroundStyle(Theme.muted)
            Stepper(title, value: value, in: range).labelsHidden()
                .accessibilityLabel("\(title)分鐘")
                .accessibilityValue("\(value.wrappedValue) 分鐘")
        }
    }
}
