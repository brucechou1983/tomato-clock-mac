import AppKit
import SwiftUI
import TomatoCore

struct MenuBarView: View {
    @ObservedObject var model: TimerModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                TomatoMark(size: 22)
                Text("小番茄").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(model.engine.kind.title)
                    .font(.system(size: 11)).foregroundStyle(Theme.accent(for: model.engine.kind))
            }
            Text(model.engine.clockText)
                .font(.system(size: 43, weight: .light, design: .rounded)).monospacedDigit()
                .accessibilityLabel("剩餘 \(model.engine.clockText)")
            Button { model.toggle() } label: {
                Label(model.actionTitle, systemImage: model.isRunning ? "pause.fill" : "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle(color: Theme.button(for: model.engine.kind)))
            Divider()
            HStack {
                Button("打開小番茄") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.plain)
                Spacer()
                Button("結束") { NSApp.terminate(nil) }
                    .buttonStyle(.plain).foregroundStyle(Theme.muted)
            }
            .font(.system(size: 12))
        }
        .foregroundStyle(Theme.text)
        .padding(22)
        .frame(width: 270)
        .background(Theme.background)
    }
}
