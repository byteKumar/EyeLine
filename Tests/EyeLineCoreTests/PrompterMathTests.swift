import CoreGraphics
import Testing
@testable import EyeLineCore

struct LevelTests {
    @Test func silenceIsZero() {
        #expect(LevelMath.rms([0, 0, 0, 0]) == 0)
        #expect(LevelMath.normalized(rms: 0) == 0)
        #expect(LevelMath.normalized(rms: 0.0001) == 0) // -80 dB, below the floor
    }

    @Test func loudIsOne() {
        #expect(LevelMath.normalized(rms: 0.5) == 1) // about -6 dB
    }

    @Test func speechLandsInTheMiddle() {
        let n = LevelMath.normalized(rms: 0.02) // about -34 dB
        #expect(n > 0.3 && n < 0.6)
    }

    @Test func rmsOfSquareWave() {
        #expect(abs(LevelMath.rms([0.5, -0.5, 0.5, -0.5]) - 0.5) < 0.0001)
    }

    @Test func smootherRisesFastFallsSlow() {
        var s = LevelSmoother()
        let up = s.update(1)
        #expect(up > 0.4)
        let afterOneQuietFrame = s.update(0)
        #expect(afterOneQuietFrame > up * 0.9)
        for _ in 0..<200 { s.update(0) }
        #expect(s.value == 0)
    }
}

struct ScrollTests {
    @Test func advancesBySpeedTimesTime() {
        #expect(ScrollMath.advance(offset: 10, speed: 60, dt: 0.5, maxOffset: 1000) == 40)
    }

    @Test func clampsAtEnd() {
        #expect(ScrollMath.advance(offset: 990, speed: 60, dt: 1, maxOffset: 1000) == 1000)
    }

    @Test func neverNegative() {
        #expect(ScrollMath.advance(offset: 5, speed: -60, dt: 1, maxOffset: 1000) == 0)
        #expect(ScrollMath.maxOffset(contentHeight: 10, lineHeight: 30) == 0)
    }

    @Test func voicePacing() {
        #expect(ScrollMath.voiceFactor(level: 0.05) == 0)
        #expect(ScrollMath.voiceFactor(level: 0.9) == 1)
        let mid = ScrollMath.voiceFactor(level: 0.2)
        #expect(mid > 0 && mid < 1)
    }
}

struct GeometryTests {
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)

    @Test func hangsFromTopCenter() {
        let f = PrompterGeometry.panelFrame(size: CGSize(width: 400, height: 150), screen: screen)
        #expect(f.maxY == screen.maxY)
        #expect(f.midX == screen.midX)
    }

    @Test func resizeStaysCentered() {
        let s = PrompterGeometry.size(forHandleAt: CGPoint(x: screen.midX + 250, y: screen.maxY - 180), screen: screen)
        #expect(s == CGSize(width: 500, height: 180))
    }

    @Test func resizeIsClamped() {
        let tiny = PrompterGeometry.size(forHandleAt: CGPoint(x: screen.midX + 5, y: screen.maxY - 5), screen: screen)
        #expect(tiny == PrompterGeometry.minSize)
        let huge = PrompterGeometry.size(forHandleAt: CGPoint(x: 5000, y: -5000), screen: screen)
        #expect(huge.width <= screen.width * 0.8 && huge.height <= screen.height * 0.6)
    }

    @Test func secondaryScreenOrigin() {
        let ext = CGRect(x: -1920, y: 200, width: 1920, height: 1080)
        let f = PrompterGeometry.panelFrame(size: CGSize(width: 400, height: 150), screen: ext)
        #expect(f.midX == ext.midX && f.maxY == ext.maxY)
    }
}

struct StatsTests {
    @Test func countsWords() {
        #expect(ScriptStats.wordCount("Hello there,\n  camera  friend.") == 4)
        #expect(ScriptStats.wordCount("") == 0)
        #expect(ScriptStats.readMinutes(String(repeating: "word ", count: 300)) == 2)
    }
}
