import AVFoundation
import AudioControls
import Foundation

/// A small live synthesizer with an attack/release envelope, pitch glide,
/// vibrato and a nasal harmonic tone. The audio callback reads C atomics so
/// UI changes never lock the realtime audio thread.
final class OtamatoneSynth {
    private let engine = AVAudioEngine()
    private let controls: OpaquePointer
    private let source: AVAudioSourceNode
    private var started = false

    init() {
        guard let controls = AudioControlsCreate() else { fatalError("Audio controls allocation failed") }
        self.controls = controls

        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
        let sampleRate = format.sampleRate
        var phase = 0.0
        var vibratoPhase = 0.0
        var currentFrequency = 220.0
        var envelope = 0.0
        var currentMouth = 0.5

        source = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let targetFrequency = AudioControlsGetFrequency(controls)
            let targetMouth = AudioControlsGetMouth(controls)
            let targetEnvelope = AudioControlsGetGate(controls) != 0 ? 1.0 : 0.0
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            var sumSquares = 0.0

            for frame in 0..<Int(frameCount) {
                // The smoothing also prevents clicks when the lid jumps between
                // readings or the play button is pressed.
                currentFrequency += (targetFrequency - currentFrequency) * 0.0015
                currentMouth += (targetMouth - currentMouth) * 0.001
                let envelopeRate = targetEnvelope > envelope ? 0.004 : 0.0016
                envelope += (targetEnvelope - envelope) * envelopeRate
                vibratoPhase += 2.0 * .pi * 5.2 / sampleRate
                if vibratoPhase >= 2.0 * .pi { vibratoPhase -= 2.0 * .pi }
                let vibrato = 1.0 + 0.003 * sin(vibratoPhase)
                phase += 2.0 * .pi * currentFrequency * vibrato / sampleRate
                if phase >= 2.0 * .pi { phase -= 2.0 * .pi }

                let open = currentMouth
                let fundamental = sin(phase)
                let second = sin(2.0 * phase) * (0.38 + 0.18 * open)
                let third = sin(3.0 * phase) * (0.24 + 0.20 * open)
                let fourth = sin(4.0 * phase) * (0.13 + 0.14 * open)
                let nasal = fundamental + second + third + fourth
                let sample = Float(tanh(nasal * (0.7 + 0.35 * open)) * envelope * 0.22)

                sumSquares += Double(sample) * Double(sample)
                for buffer in buffers {
                    buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = sample
                }
            }
            if frameCount > 0 {
                AudioControlsPublishOutputLevel(controls, sqrt(sumSquares / Double(frameCount)))
            }
            return noErr
        }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
    }

    var outputSample: AudioOutputSample {
        let sequence = AudioControlsGetOutputSequence(controls)
        let rms = started && engine.isRunning ? AudioControlsGetOutputLevel(controls) : 0
        return AudioOutputSample(rms: rms, sequence: sequence)
    }

    func start() throws {
        guard !started else { return }
        try engine.start()
        started = true
    }

    func set(frequency: Double, mouth: Double, playing: Bool) {
        AudioControlsSetFrequency(controls, frequency)
        AudioControlsSetMouth(controls, mouth)
        AudioControlsSetGate(controls, playing ? 1 : 0)
    }

    func stop() {
        AudioControlsSetGate(controls, 0)
        if started { engine.stop() }
        started = false
    }

    #if THEME_CHECKS
    // Exercise the actual render callback without sending sound to a device.
    func startOfflineForChecks() throws {
        try engine.enableManualRenderingMode(.offline, format: source.outputFormat(forBus: 0),
                                             maximumFrameCount: 512)
        try start()
    }

    func renderOfflineForChecks() throws -> [Float] {
        let buffer = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 512)!
        let status = try engine.renderOffline(512, to: buffer)
        precondition(status == .success, "Offline audio render failed")
        return Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength)))
    }
    #endif

    deinit {
        engine.stop()
        AudioControlsDestroy(controls)
    }
}
