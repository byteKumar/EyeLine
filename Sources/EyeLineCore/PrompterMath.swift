import CoreGraphics
import Foundation

/// Turns raw microphone samples into a 0...1 loudness value.
public enum LevelMath {
    public static func rms(_ samples: UnsafeBufferPointer<Float>) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sum: Float = 0
        for s in samples { sum += s * s }
        return (sum / Float(samples.count)).squareRoot()
    }

    public static func rms(_ samples: [Float]) -> Float {
        samples.withUnsafeBufferPointer { rms($0) }
    }

    /// Maps RMS onto 0...1 through a decibel window, so quiet rooms read as 0
    /// and normal speech lands around 0.5-0.9.
    public static func normalized(rms: Float, floorDB: Float = -50, ceilingDB: Float = -12) -> Float {
        guard rms > 0 else { return 0 }
        let db = 20 * log10(rms)
        return min(1, max(0, (db - floorDB) / (ceilingDB - floorDB)))
    }
}

/// Fast attack, slow release, so the glow jumps up with a word and fades between sentences.
public struct LevelSmoother {
    public var value: Float = 0
    public var attack: Float
    public var release: Float

    public init(attack: Float = 0.45, release: Float = 0.06) {
        self.attack = attack
        self.release = release
    }

    @discardableResult
    public mutating func update(_ target: Float) -> Float {
        let k = target > value ? attack : release
        value += (target - value) * k
        if value < 0.001 { value = 0 }
        return value
    }
}

public enum ScrollMath {
    /// Next scroll offset in points, clamped to 0...maxOffset.
    public static func advance(offset: Double, speed: Double, dt: Double, factor: Double = 1, maxOffset: Double) -> Double {
        min(max(0, maxOffset), max(0, offset + speed * dt * factor))
    }

    /// How fast to scroll in voice-paced mode: 0 when silent, ramping to 1 while speaking.
    public static func voiceFactor(level: Float, threshold: Float = 0.12) -> Double {
        guard level > threshold else { return 0 }
        return min(1, Double((level - threshold) / 0.25))
    }

    /// Scroll stops once the last line sits at the top of the viewport.
    public static func maxOffset(contentHeight: Double, lineHeight: Double) -> Double {
        max(0, contentHeight - lineHeight)
    }
}

public enum PrompterGeometry {
    public static let minSize = CGSize(width: 260, height: 100)

    public static func maxSize(for screen: CGRect) -> CGSize {
        CGSize(width: screen.width * 0.8, height: screen.height * 0.6)
    }

    public static func clamp(_ size: CGSize, screen: CGRect) -> CGSize {
        let maxS = maxSize(for: screen)
        return CGSize(width: min(maxS.width, max(minSize.width, size.width)),
                      height: min(maxS.height, max(minSize.height, size.height)))
    }

    /// The panel hangs from the top edge of the screen, centered under the camera.
    public static func panelFrame(size: CGSize, screen: CGRect) -> CGRect {
        let s = clamp(size, screen: screen)
        return CGRect(x: (screen.midX - s.width / 2).rounded(),
                      y: screen.maxY - s.height,
                      width: s.width, height: s.height)
    }

    /// Size for a resize handle dragged to `point` (screen coordinates).
    /// Width grows symmetrically so the panel stays centered on the camera.
    public static func size(forHandleAt point: CGPoint, screen: CGRect) -> CGSize {
        clamp(CGSize(width: abs(point.x - screen.midX) * 2, height: screen.maxY - point.y), screen: screen)
    }
}

public enum ScriptStats {
    public static func wordCount(_ text: String) -> Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    /// Read time at a typical speaking pace of 150 words per minute.
    public static func readMinutes(_ text: String, wpm: Double = 150) -> Double {
        Double(wordCount(text)) / wpm
    }
}
