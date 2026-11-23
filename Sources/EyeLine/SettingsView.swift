import EyeLineCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: PrompterModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Script").font(.headline)
                Spacer()
                Text(stats).font(.caption).foregroundStyle(.secondary)
            }

            TextEditor(text: $model.script)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
                .frame(minHeight: 200)

            HStack {
                Button(model.isPlaying ? "Pause" : "Play") { model.togglePlay() }
                Button("Restart") { model.restart() }
                Button(model.isVisible ? "Hide Prompter" : "Show Prompter") { model.isVisible.toggle() }
                Spacer()
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Scroll speed")
                    Slider(value: $model.speed, in: 8...160)
                    Text("\(Int(model.speed)) pt/s").monospacedDigit().foregroundStyle(.secondary).frame(width: 60, alignment: .trailing)
                }
                GridRow {
                    Text("Text size")
                    Slider(value: $model.fontSize, in: 12...40)
                    Text("\(Int(model.fontSize)) pt").monospacedDigit().foregroundStyle(.secondary).frame(width: 60, alignment: .trailing)
                }
            }

            Toggle("Voice glow", isOn: $model.glowEnabled)
            Toggle("Scroll only while I'm speaking", isOn: $model.voicePaced)
            Toggle("Show the prompter in screen shares and recordings", isOn: $model.visibleInCaptures)

            if model.micDenied && (model.glowEnabled || model.voicePaced) {
                Text("Microphone access is off. Turn it on in System Settings > Privacy & Security > Microphone.")
                    .font(.caption).foregroundStyle(.orange)
            }

            Text("Hover the prompter for controls. Click the text to pause, scroll on it to rewind, drag its corner to resize. The microphone is only used for loudness; nothing is recorded.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(minWidth: 460, idealWidth: 500, minHeight: 520)
    }

    private var stats: String {
        let words = ScriptStats.wordCount(model.script)
        let minutes = ScriptStats.readMinutes(model.script)
        let time = minutes < 1 ? "\(Int((minutes * 60).rounded())) sec" : String(format: "%.1f min", minutes)
        return "\(words) words · about \(time) spoken"
    }
}
