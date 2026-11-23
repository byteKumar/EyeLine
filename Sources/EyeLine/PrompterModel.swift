import AppKit
import Combine
import EyeLineCore
import QuartzCore

/// All prompter state. Settings persist in UserDefaults.
@MainActor
final class PrompterModel: ObservableObject {
    static let defaultScript = """
    Welcome to EyeLine. This prompter hangs right under your camera, so when you read these lines your eyes stay on your audience.

    Only you can see it. It stays out of screen shares and recordings.

    Drag the bottom right corner to resize it. Hover for controls, click the text to pause, and scroll on it to rewind.

    See the soft glow below? It listens to your voice. It rises as you speak and fades when you're quiet.

    Open Script & Settings from the menu bar to paste your own script. Break a leg.
    """

    private let defaults = UserDefaults.standard

    @Published var script: String { didSet { defaults.set(script, forKey: "script") } }
    /// Points per second.
    @Published var speed: Double { didSet { defaults.set(speed, forKey: "speed") } }
    @Published var fontSize: Double { didSet { defaults.set(fontSize, forKey: "fontSize") } }
    @Published var size: CGSize {
        didSet {
            defaults.set(size.width, forKey: "width")
            defaults.set(size.height, forKey: "height")
        }
    }
    @Published var glowEnabled: Bool { didSet { defaults.set(glowEnabled, forKey: "glowEnabled") } }
    @Published var voicePaced: Bool { didSet { defaults.set(voicePaced, forKey: "voicePaced") } }
    /// Off by default: the whole point is that the audience never sees the prompter.
    @Published var visibleInCaptures: Bool { didSet { defaults.set(visibleInCaptures, forKey: "visibleInCaptures") } }

    @Published var isPlaying = false
    @Published var isVisible = true
    @Published var offset: CGFloat = 0
    @Published var contentHeight: CGFloat = 0
    /// Height of the notch (or menu bar) the text must start below.
    @Published var topInset: CGFloat = 32
    /// Smoothed microphone level, 0...1.
    @Published private(set) var level: Float = 0
    @Published var micDenied = false

    /// Latest unsmoothed level from the microphone.
    var rawLevel: Float = 0

    private var smoother = LevelSmoother()
    private var timer: Timer?
    private var lastTick = CACurrentMediaTime()

    init() {
        defaults.register(defaults: [
            "script": Self.defaultScript, "speed": 32.0, "fontSize": 17.0,
            "width": 380.0, "height": 150.0,
            "glowEnabled": true, "voicePaced": false, "visibleInCaptures": false,
        ])
        script = defaults.string(forKey: "script") ?? Self.defaultScript
        speed = defaults.double(forKey: "speed")
        fontSize = defaults.double(forKey: "fontSize")
        size = CGSize(width: defaults.double(forKey: "width"), height: defaults.double(forKey: "height"))
        glowEnabled = defaults.bool(forKey: "glowEnabled")
        voicePaced = defaults.bool(forKey: "voicePaced")
        visibleInCaptures = defaults.bool(forKey: "visibleInCaptures")

        let t = Timer(timeInterval: 1.0 / 60.0, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    var lineHeight: CGFloat { fontSize * 1.45 }
    var maxOffset: CGFloat { ScrollMath.maxOffset(contentHeight: contentHeight, lineHeight: lineHeight) }

    /// Sets the glow level directly (snapshots only).
    func setPreviewLevel(_ value: Float) { level = value }

    func togglePlay() {
        if !isPlaying && offset >= maxOffset { offset = 0 }
        isPlaying.toggle()
    }

    func restart() {
        offset = 0
        isPlaying = true
    }

    /// Manual scrubbing from the scroll wheel or trackpad.
    func scrub(by delta: CGFloat) {
        offset = min(maxOffset, max(0, offset + delta))
    }

    @objc private func tick() {
        let now = CACurrentMediaTime()
        let dt = min(0.1, now - lastTick)
        lastTick = now

        let smoothed = smoother.update(rawLevel)
        if abs(smoothed - level) > 0.002 || (smoothed == 0 && level != 0) { level = smoothed }

        guard isPlaying else { return }
        let factor = voicePaced ? ScrollMath.voiceFactor(level: smoothed) : 1
        let next = ScrollMath.advance(offset: offset, speed: speed, dt: dt, factor: factor, maxOffset: maxOffset)
        if next != offset { offset = next }
        if offset >= maxOffset && contentHeight > 0 { isPlaying = false }
    }
}
