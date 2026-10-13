import SwiftUI
import TomatoCore

struct MainView: View {
    @ObservedObject var model: TimerModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openWindow) private var openWindow
    @State private var kindToConfirm: SessionKind?
    @State private var confirmReset = false

    private var accent: Color { Theme.accent(for: model.engine.kind) }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.bottom, 24)
            modes
                .padding(.bottom, 20)
            clock
            Text(model.statusTitle)
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .padding(.top, 18)
                .padding(.bottom, 25)
            controls
                .padding(.bottom, 21)
            cycle
                .padding(.bottom, 22)
            movementNote
                .padding(.bottom, 20)
            dailyStats
        }
        .padding(.horizontal, 32)
        .padding(.top, 36)
        .padding(.bottom, 24)
        .frame(width: 440, height: 740)
        .background(Theme.background)
        .tint(accent)
        .onAppear {
            model.onRevealMainWindow = { openWindow(id: "main") }
        }
        .sheet(isPresented: $model.settingsPresented) {
            SettingsView(model: model, reminders: model.reminders)
        }
        .alert("結束這一段計時？", isPresented: Binding(
            get: { kindToConfirm != nil },
            set: { if !$0 { kindToConfirm = nil } }
        )) {
            Button("切換模式", role: .destructive) {
                if let kind = kindToConfirm { model.select(kind) }
                kindToConfirm = nil
            }
            Button("繼續計時", role: .cancel) { kindToConfirm = nil }
        } message: {
            Text("目前的進度會重設，這一段不會列入今日紀錄。")
        }
        .alert("重新開始這一段？", isPresented: $confirmReset) {
            Button("重新開始", role: .destructive) { model.reset() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("目前的進度會重設。")
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            TomatoMark()
            VStack(alignment: .leading, spacing: 2) {
                Text("小番茄")
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.text)
                Text("專注一會，休息一下")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Button { model.settingsPresented = true } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(QuietIconButtonStyle())
            .help("時間與提醒設定 ⌘,")
            .accessibilityLabel("時間與提醒設定")
        }
    }

    private var modes: some View {
        HStack(spacing: 4) {
            ForEach(SessionKind.allCases, id: \.self) { kind in
                Button {
                    guard kind != model.engine.kind else { return }
                    if model.engine.phase != .ready { kindToConfirm = kind }
                    else { model.select(kind) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: kind.symbol).accessibilityHidden(true)
                        Text(kind.title)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .foregroundStyle(model.engine.kind == kind ? Theme.accent(for: kind) : Theme.muted)
                    .background {
                        if model.engine.kind == kind {
                            Capsule().fill(Theme.surface)
                                .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(model.engine.kind == kind ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Theme.tintSurface, in: Capsule())
    }

    private var clock: some View {
        ZStack {
            Circle().stroke(Theme.track, lineWidth: 7)
            Circle()
                .trim(from: 0, to: model.engine.phase == .ready ? 1 : max(0.001, 1 - model.engine.progress))
                .stroke(accent, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 1), value: model.engine.progress)
            ForEach(0..<60) { tick in
                Capsule()
                    .fill(Theme.line)
                    .frame(width: tick.isMultiple(of: 5) ? 2 : 1,
                           height: tick.isMultiple(of: 5) ? 7 : 3)
                    .offset(y: -104)
                    .rotationEffect(.degrees(Double(tick) * 6))
            }
            VStack(spacing: 9) {
                HStack(spacing: 5) {
                    Circle().fill(accent).frame(width: 5, height: 5)
                    Text(model.engine.phase == .paused ? "暫停中" : model.engine.kind.title + "時間")
                        .font(.system(size: 12, weight: .medium))
                        .tracking(2)
                }
                .foregroundStyle(accent)
                Text(model.engine.clockText)
                    .font(.system(size: 63, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .tracking(-2)
                    .foregroundStyle(Theme.text)
                Text(model.isRunning ? "預計 \(endTime) 結束" : "留一點空白，給更好的自己")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
            }
        }
        .frame(width: 248, height: 248)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(model.engine.kind.title)，\(model.engine.phase == .paused ? "已暫停，" : "")剩餘 \(model.engine.clockText)")
    }

    private var endTime: String {
        (model.engine.deadline ?? model.now).formatted(date: .omitted, time: .shortened)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button { model.toggle() } label: {
                Label(model.actionTitle, systemImage: model.isRunning ? "pause.fill" : "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle(color: Theme.button(for: model.engine.kind)))
            .keyboardShortcut(.space, modifiers: [])
            .help("空白鍵開始或暫停")
            Button {
                if model.engine.phase == .ready { model.reset() }
                else { confirmReset = true }
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(QuietIconButtonStyle())
            .accessibilityLabel("重設計時")
            .help("重設這一段計時")
        }
        .frame(width: 282)
    }

    private var cycle: some View {
        HStack(spacing: 8) {
            ForEach(0..<4) { index in
                Circle()
                    .fill(index < model.engine.completedFocusCount % 4 ? Theme.tomato : Theme.track)
                    .frame(width: 7, height: 7)
            }
            Text("每 4 段專注，享受一次長休息")
                .font(.system(size: 10))
                .foregroundStyle(Theme.muted)
                .padding(.leading, 3)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("目前完成本輪 \(model.engine.completedFocusCount % 4) 段專注，每 4 段有一次長休息")
    }

    private var movementNote: some View {
        HStack(spacing: 13) {
            Image(systemName: "figure.walk")
                .font(.system(size: 23, weight: .regular))
                .foregroundStyle(Theme.green)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(model.isBreak ? "現在，是身體的時間" : "專注結束，提醒你動一動")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.text)
                Text("走幾步、喝口水，讓肩膀放鬆。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 15)
        .background(Theme.tintSurface.opacity(0.75), in: RoundedRectangle(cornerRadius: 15))
    }

    private var dailyStats: some View {
        HStack(spacing: 0) {
            stat(value: "\(model.summary.focusCount)", label: "今日專注", suffix: "段")
            Rectangle().fill(Theme.line).frame(width: 1, height: 29)
            stat(value: "\(model.summary.focusMinutes)", label: "累積專注", suffix: "分鐘")
            Rectangle().fill(Theme.line).frame(width: 1, height: 29)
            stat(value: "\(model.summary.breakCount)", label: "完成休息", suffix: "次")
        }
    }

    private func stat(value: String, label: String, suffix: String) -> some View {
        VStack(spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.system(size: 20, weight: .medium, design: .rounded)).monospacedDigit()
                    .foregroundStyle(Theme.text)
                Text(suffix).font(.system(size: 10)).foregroundStyle(Theme.muted)
            }
            Text(label).font(.system(size: 10)).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
