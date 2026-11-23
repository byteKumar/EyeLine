import AVFoundation
import EyeLineCore

/// Reads the microphone's loudness. Nothing is recorded or stored; only a 0...1 level leaves this class.
final class MicMonitor {
    private let engine = AVAudioEngine()
    private(set) var isRunning = false

    /// Called on the main queue with a normalized level.
    var onLevel: ((Float) -> Void)?
    /// Called on the main queue when the user has denied microphone access.
    var onDenied: (() -> Void)?

    func start() {
        guard !isRunning else { return }
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            begin()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    if granted { self.begin() } else { self.onDenied?() }
                }
            }
        default:
            onDenied?()
        }
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }

    private func begin() {
        guard !isRunning else { return }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { return }

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let channel = buffer.floatChannelData?[0] else { return }
            let rms = LevelMath.rms(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
            let level = LevelMath.normalized(rms: rms)
            DispatchQueue.main.async { self?.onLevel?(level) }
        }
        do {
            try engine.start()
            isRunning = true
        } catch {
            input.removeTap(onBus: 0)
            NSLog("EyeLine: microphone failed to start: \(error.localizedDescription)")
        }
    }
}
