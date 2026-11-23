import EyeLineCore
import SwiftUI

private struct HeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Black panel shaped like an extension of the notch: square top, rounded bottom.
private let panelShape = UnevenRoundedRectangle(
    topLeadingRadius: 0, bottomLeadingRadius: 22, bottomTrailingRadius: 22, topTrailingRadius: 0, style: .continuous)

struct PrompterView: View {
    @ObservedObject var model: PrompterModel
    /// Called while the resize handle is dragged; the controller reads the mouse position itself.
    var onResizeDrag: () -> Void
    /// Keeps the hover controls visible (used for snapshots).
    var alwaysShowControls = false

    @State private var hovering = false

    var body: some View {
        ZStack {
            panelShape.fill(Color.black)

            if model.glowEnabled { VoiceGlow(level: model.level) }

            script
                .padding(.top, model.topInset + 4)
                .padding(.horizontal, 26)
                .padding(.bottom, 12)

            controls
        }
        .clipShape(panelShape)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.2), value: hovering)
    }

    private var script: some View {
        GeometryReader { geo in
            Text(model.script)
                .font(.system(size: model.fontSize, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(model.fontSize * 0.25)
                .frame(width: geo.size.width)
                .fixedSize(horizontal: false, vertical: true)
                .background(GeometryReader { g in Color.clear.preference(key: HeightKey.self, value: g.size.height) })
                .offset(y: -model.offset)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .clipped()
        .mask(
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.1),
                .init(color: .black, location: 0.82),
                .init(color: .clear, location: 1),
            ], startPoint: .top, endPoint: .bottom)
        )
        .contentShape(Rectangle())
        .onTapGesture { model.togglePlay() }
        .onPreferenceChange(HeightKey.self) { model.contentHeight = $0 }
    }

    private var controls: some View {
        VStack {
            HStack {
                ControlButton(symbol: "xmark", help: "Hide prompter") { model.isVisible = false }
                Spacer()
                ControlButton(symbol: model.isPlaying ? "pause.fill" : "play.fill", help: "Play or pause") { model.togglePlay() }
            }
            .padding(.top, max(6, model.topInset * 0.25))
            Spacer()
            HStack {
                ControlButton(symbol: "arrow.counterclockwise", help: "Restart from the top") { model.restart() }
                Spacer()
                ResizeGrip(onDrag: onResizeDrag)
            }
            .padding(.bottom, 6)
        }
        .padding(.horizontal, 8)
        .opacity(hovering || alwaysShowControls ? 1 : 0)
    }
}

private struct ControlButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.white.opacity(0.14)))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private struct ResizeGrip: View {
    let onDrag: () -> Void

    var body: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white.opacity(0.7))
            .frame(width: 20, height: 20)
            .background(Circle().fill(Color.white.opacity(0.14)))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global).onChanged { _ in onDrag() })
            .help("Drag to resize")
    }
}

/// Warm light at the bottom edge that rises with your voice and fades in silence.
private struct VoiceGlow: View {
    let level: Float

    var body: some View {
        let l = CGFloat(level)
        GeometryReader { geo in
            Ellipse()
                .fill(RadialGradient(
                    colors: [Color(red: 1, green: 0.86, blue: 0.5).opacity(0.95),
                             Color(red: 1, green: 0.7, blue: 0.3).opacity(0.45),
                             .clear],
                    center: .center, startRadius: 0, endRadius: geo.size.width * 0.32))
                .frame(width: geo.size.width * 0.85, height: 36 + geo.size.height * 0.55 * l)
                .blur(radius: 18)
                .opacity(Double(0.08 + 0.85 * l))
                .position(x: geo.size.width / 2, y: geo.size.height + 8 - geo.size.height * 0.22 * l)
        }
        .allowsHitTesting(false)
        .blendMode(.plusLighter)
    }
}
