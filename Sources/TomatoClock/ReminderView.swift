import SwiftUI
import TomatoCore

struct ReminderView: View {
    @ObservedObject var model: TimerModel
    let completion: Completion

    private var movement: Bool { completion.kind == .focus }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(Theme.green.opacity(0.10)).frame(width: 110, height: 110)
                Image(systemName: movement ? "figure.walk" : "sun.max")
                    .font(.system(size: 49, weight: .light))
                    .foregroundStyle(Theme.green)
            }
            .accessibilityHidden(true)
            .padding(.bottom, 24)
            Text(movement ? "該起來動一動了" : "休息好了，重新出發")
                .font(.system(size: 25, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.text)
                .padding(.bottom, 12)
            Text(movement ? "這一段，你已經做得很好。\n離開螢幕，走幾步、喝口水，伸展肩頸。"
                          : "把注意力帶回眼前。\n準備好了，再開始下一段專注。")
                .font(.system(size: 13))
                .lineSpacing(6)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.muted)
                .padding(.bottom, 26)
            Button { model.beginNextSession() } label: {
                Label(movement ? "開始 \(model.nextBreakMinutes) 分鐘休息" : "開始下一段專注",
                      systemImage: movement ? "leaf" : "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle(color: movement ? Theme.buttonGreen : Theme.buttonTomato))
            .keyboardShortcut(.defaultAction)
            .padding(.bottom, 12)
            Button(movement ? "稍後再休息" : "再等一下") { model.dismissReminder() }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
                .padding(8)
                .keyboardShortcut(.cancelAction)
        }
        .padding(34)
        .frame(width: 410)
        .background(Theme.background)
    }
}
