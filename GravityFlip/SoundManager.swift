import AVFoundation

// Generates all SFX programmatically — no audio files needed.
final class SoundManager {
    static let shared = SoundManager()

    private let engine = AVAudioEngine()
    private var isReady = false

    private init() {
        configureSession()
        startEngine()
        observeInterruptions()
    }

    private func configureSession() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default,
                                                         options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func startEngine() {
        guard !engine.isRunning else { isReady = true; return }
        // Accessing mainMixerNode forces AVAudioEngine to create its output node
        // chain. Without this, start() throws "inputNode/outputNode != nullptr"
        // when called before any nodes have been attached (e.g. at first init).
        _ = engine.mainMixerNode
        do {
            try engine.start()
            isReady = true
        } catch {
            isReady = false
        }
    }

    // Restart the engine after an audio interruption (phone call, Siri, etc.).
    private func observeInterruptions() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let self,
                  let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  type == AVAudioSession.InterruptionType.ended.rawValue else { return }
            self.configureSession()
            self.startEngine()
        }
    }

    func playFlip()  { guard SettingsManager.shared.soundEnabled else { return }; play(startHz: 460, endHz: 680, dur: 0.09, amp: 0.12) }
    func playLand()  { guard SettingsManager.shared.soundEnabled else { return }; play(startHz: 300, endHz: 230, dur: 0.07, amp: 0.09) }
    func playCoin()  { guard SettingsManager.shared.soundEnabled else { return }; play(startHz: 900, endHz: 1160, dur: 0.07, amp: 0.10) }
    func playDeath() { guard SettingsManager.shared.soundEnabled else { return }; play(startHz: 260, endHz: 75,  dur: 0.30, amp: 0.18) }

    private func play(startHz: Double, endHz: Double, dur: Double, amp: Float) {
        guard isReady else { return }

        let sr: Double = 44100
        let frameCount = AVAudioFrameCount(sr * dur)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channelData = buffer.floatChannelData
        else { return }
        buffer.frameLength = frameCount

        let data = channelData[0]
        var phase = 0.0
        for i in 0..<Int(frameCount) {
            let progress = Double(i) / (sr * dur)
            let hz = startHz + (endHz - startHz) * progress
            let envelope = Float(sin(.pi * progress))   // fade in + out
            phase += 2.0 * .pi * hz / sr
            data[i] = amp * envelope * Float(sin(phase))
        }

        let node = AVAudioPlayerNode()
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        node.scheduleBuffer(buffer, completionHandler: nil)
        node.play()

        DispatchQueue.main.asyncAfter(deadline: .now() + dur + 0.12) { [weak self] in
            node.stop()
            self?.engine.detach(node)
        }
    }
}
