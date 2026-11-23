import AppKit
import AVFoundation
import SwiftUI

/// `EyeLine --snapshot out.png [level] [offset]` renders the prompter to a PNG and exits.
/// Used for docs and for checking the UI without screen-recording permission.
@MainActor
enum Snapshot {
    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count else { return false }
        let out = URL(fileURLWithPath: args[i + 1])
        let level = args.count > i + 2 ? Float(args[i + 2]) ?? 0.7 : 0.7
        let offset = args.count > i + 3 ? CGFloat(Double(args[i + 3]) ?? 0) : 0

        let model = PrompterModel()
        model.topInset = 32
        model.setPreviewLevel(level)
        model.offset = offset
        let view = PrompterView(model: model, onResizeDrag: {}, alwaysShowControls: true)
            .frame(width: model.size.width, height: model.size.height)
            .padding(30)
            .background(Color(white: 0.55))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write("snapshot failed\n".data(using: .utf8)!)
            exit(1)
        }
        try? png.write(to: out)
        print("wrote \(out.path)")
        return true
    }
}

/// `EyeLine --mic-test` prints microphone levels for five seconds, then exits.
@MainActor
enum MicTest {
    static func runIfRequested() -> Bool {
        guard CommandLine.arguments.contains("--mic-test") else { return false }
        let mic = MicMonitor()
        var peak: Float = 0, samples = 0
        mic.onLevel = { level in peak = max(peak, level); samples += 1 }
        mic.onDenied = { print("mic: access denied"); exit(2) }
        print("mic: authorization status \(AVCaptureDevice.authorizationStatus(for: .audio).rawValue)")
        mic.start()
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated { print("mic: callbacks \(samples), peak level \(String(format: "%.2f", peak))"); peak = 0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) { exit(samples > 0 ? 0 : 3) }
        RunLoop.main.run()
        return true
    }
}
