import AVFoundation

/// 効果音（端末の中で作る。録音したファイルは持たない）。
/// 昼の畑：土に落ちるポフッ、合体はころんと上がる木琴（段が上がるほど高い）、出荷は木箱のコトン＋小銭、
/// 雨は水のしずく、季節が変わると木琴の 4 音。消音スイッチに従い、ほかのアプリの音と混ぜる（.ambient）
@MainActor
final class SoundBox {
    static let shared = SoundBox()

    enum Cue: Hashable {
        case tap, drop, merge(Int), rain, prize, harvest, warn, miss, over, goal, season
    }

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]
    private var nextPlayer = 0
    private var prepared = false
    private let rate = 44_100.0
    private lazy var format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)

    /// 音量の段階：触る 0.3・落とす 0.4・合体 0.55・出荷 0.7・目標/品評会 0.8・危ない 0.6・終わり 0.7
    private func volume(_ cue: Cue) -> Float {
        switch cue {
        case .tap: 0.3
        case .drop: 0.4
        case .merge: 0.55
        case .rain, .miss: 0.5
        case .warn: 0.6
        case .harvest, .over, .season: 0.7
        case .goal, .prize: 0.8
        }
    }

    private func prepare() -> Bool {
        if prepared { return engine.isRunning || ((try? engine.start()) != nil) }
        guard let format else { return false }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        for _ in 0..<6 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p)
        }
        prepared = true
        return (try? engine.start()) != nil
    }

    func play(_ cue: Cue) {
        guard prepare(), engine.isRunning else { return }
        let buffer: AVAudioPCMBuffer
        if let b = buffers[cue] {
            buffer = b
        } else {
            guard let b = make(cue) else { return }
            buffers[cue] = b
            buffer = b
        }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.stop()
        player.volume = volume(cue)
        player.scheduleBuffer(buffer, at: nil, options: [])
        player.play()
    }

    private struct Tone {
        var freq: Double
        var amp: Double
        var decay: Double
        var delay: Double = 0
        var glide: Double? = nil
    }

    /// 木琴の音階（ド レ ミ ソ ラ ド…）
    private let scale = [523.3, 587.3, 659.3, 784.0, 880.0, 1046.5, 1174.7, 1318.5, 1568.0]

    private func make(_ cue: Cue) -> AVAudioPCMBuffer? {
        switch cue {
        case .tap:
            return render(0.06, noise: 0.1, noiseDecay: 120, tones: [Tone(freq: 900, amp: 0.2, decay: 90)])
        case .drop:
            // 土に落ちる：低いポフッ
            return render(0.18, noise: 0.25, noiseDecay: 40, tones: [Tone(freq: 160, amp: 0.45, decay: 28, glide: 110)])
        case .merge(let tier):
            // 合体：木琴。段が上がるほど高く、2 音で上がる
            let f = scale[min(max(tier, 0), scale.count - 2)]
            let up = scale[min(max(tier, 0) + 1, scale.count - 1)]
            return render(0.45, noise: 0.03, noiseDecay: 80, tones: [
                Tone(freq: f, amp: 0.32, decay: 11), Tone(freq: f * 3.9, amp: 0.05, decay: 30),
                Tone(freq: up, amp: 0.3, decay: 10, delay: 0.06), Tone(freq: up * 3.9, amp: 0.04, decay: 30, delay: 0.06),
            ])
        case .rain:
            // しずく：上へ跳ねる短い音を 3 つ
            return render(0.5, noise: 0, tones: [0.0, 0.11, 0.2].enumerated().map { i, d in
                Tone(freq: 1400 + Double(i) * 260, amp: 0.2, decay: 26, delay: d, glide: 2400 + Double(i) * 300)
            })
        case .prize:
            // 品評会：木琴のファンファーレ
            let notes = [784.0, 1046.5, 1318.5, 1568.0, 2093.0]
            return render(1.4, noise: 0, tones: notes.enumerated().map { i, f in Tone(freq: f, amp: 0.24, decay: 4.5, delay: Double(i) * 0.09) })
        case .harvest:
            // 出荷：木箱のコトン＋小銭のチャリン
            return render(0.55, noise: 0.15, noiseDecay: 60, tones: [
                Tone(freq: 220, amp: 0.4, decay: 30),
                Tone(freq: 2637, amp: 0.14, decay: 9, delay: 0.08), Tone(freq: 3520, amp: 0.1, decay: 10, delay: 0.12),
            ])
        case .warn:
            return render(0.4, noise: 0, tones: [Tone(freq: 440, amp: 0.25, decay: 6), Tone(freq: 415, amp: 0.25, decay: 6, delay: 0.16)])
        case .miss:
            return render(0.22, noise: 0.08, noiseDecay: 40, tones: [Tone(freq: 240, amp: 0.35, decay: 16, glide: 180)])
        case .over:
            let notes = [659.3, 523.3, 440.0, 349.2]
            return render(1.3, noise: 0, tones: notes.enumerated().map { i, f in Tone(freq: f, amp: 0.25, decay: 4, delay: Double(i) * 0.16) })
        case .goal:
            let notes = [523.3, 659.3, 784.0, 1046.5]
            return render(1.1, noise: 0, tones: notes.enumerated().flatMap { i, f in
                [Tone(freq: f, amp: 0.25, decay: 5, delay: Double(i) * 0.08), Tone(freq: f * 3.9, amp: 0.03, decay: 20, delay: Double(i) * 0.08)]
            })
        case .season:
            let notes = [784.0, 659.3, 880.0, 1046.5]
            return render(1.2, noise: 0.02, noiseDecay: 10, tones: notes.enumerated().map { i, f in Tone(freq: f, amp: 0.22, decay: 4, delay: Double(i) * 0.13) })
        }
    }

    private func render(_ seconds: Double, noise: Double, noiseDecay: Double = 60, tones: [Tone]) -> AVAudioPCMBuffer? {
        guard let format else { return nil }
        let frames = AVAudioFrameCount(seconds * rate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames), let data = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frames
        var rng = SeededRNG(seed: 22)
        var phases = Array(repeating: 0.0, count: tones.count)
        for i in 0..<Int(frames) {
            let t = Double(i) / rate
            var v = 0.0
            for (k, p) in tones.enumerated() where t >= p.delay {
                let local = t - p.delay
                var f = p.freq
                if let to = p.glide {
                    let x = min(1, local / max(0.01, seconds - p.delay))
                    f = p.freq + (to - p.freq) * x
                }
                phases[k] += 2 * .pi * f / rate
                let attack = min(1, local / 0.003)
                v += sin(phases[k]) * p.amp * exp(-local * p.decay) * attack
            }
            if noise > 0 {
                let n = rng.unit() * 2 - 1
                v += n * noise * exp(-t * noiseDecay)
            }
            let tail = min(1, (seconds - t) / 0.01)
            data[i] = Float(max(-1, min(1, v * tail)))
        }
        return buffer
    }
}
