import Combine
import Foundation
import QuartzCore
import SwiftUI

struct AudioOutputSample {
    let rms: Double
    let sequence: UInt64
    static let silent = Self(rms: 0, sequence: 0)
}

/// Fade a fixed-strength glow in and out, expiring stalled audio callbacks.
struct AudioLevelEnvelope {
    private(set) var level = 0.0
    private var sequence: UInt64 = 0
    private var lastRenderTime: TimeInterval?
    private var lastUpdateTime: TimeInterval?

    mutating func update(_ sample: AudioOutputSample, at time: TimeInterval) -> Double {
        if sample.sequence != sequence {
            sequence = sample.sequence
            lastRenderTime = time
        }
        let fresh = lastRenderTime.map { time - $0 <= 0.20 } ?? false
        let target = fresh && sample.rms.isFinite && sample.rms > 0.0001 ? 1.0 : 0.0
        let elapsed = lastUpdateTime.map { min(max(time - $0, 0), 0.25) } ?? 1.0 / 30
        lastUpdateTime = time
        let duration = target > level ? 0.09 : 0.16
        level += (target - level) * (1 - exp(-elapsed / duration))
        if target == 0 && level < 0.005 { level = 0 }
        return level
    }
}

/// Only the glow layers observe this publisher; metering doesn't redraw controls.
final class AudioActivity: ObservableObject {
    @Published private(set) var level = 0.0
    private var envelope = AudioLevelEnvelope()
    private var subscription: AnyCancellable?

    func start(sampling: @escaping () -> AudioOutputSample) {
        guard subscription == nil else { return }
        subscription = Timer.publish(every: 1.0 / 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.accept(sampling(), at: CACurrentMediaTime()) }
    }

    func accept(_ sample: AudioOutputSample, at time: TimeInterval) {
        let next = envelope.update(sample, at: time)
        if abs(next - level) > 0.0005 || (next == 0 && level != 0) { level = next }
    }

    func stop() {
        subscription?.cancel()
        subscription = nil
        envelope = AudioLevelEnvelope()
        level = 0
    }
}

struct AudioReactiveGlow: View {
    let theme: InstrumentTheme
    @ObservedObject var activity: AudioActivity
    var diameter: CGFloat = 302
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30,
                                paused: activity.level == 0 || reduceMotion)) { context in
            let phase = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 2) * .pi
            AudioGlowFrame(theme: theme, level: activity.level, breath: sin(phase), diameter: diameter)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

/// A separate frame also permits deterministic visual checks of the motion.
struct AudioGlowFrame: View {
    let theme: InstrumentTheme
    let level: Double
    let breath: Double
    var diameter: CGFloat = 302

    var body: some View {
        Circle()
            .fill(RadialGradient(stops: [
                .init(color: theme.accent.opacity(0.18), location: 0),
                .init(color: theme.accent.opacity(0.65), location: 0.48),
                .init(color: theme.accent.opacity(0.22), location: 0.76),
                .init(color: .clear, location: 1)
            ], center: .center, startRadius: 0, endRadius: diameter / 2))
            .frame(width: diameter, height: diameter)
            .scaleEffect(1 + breath * 0.12)
            .opacity(level)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}
