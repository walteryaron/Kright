import Foundation

/// A character **bigram (Markov) model**: scores how plausible a word's
/// letter-transitions are for a language. Tiny — an n×n log-probability table.
struct BigramModel {
    let index: [Character: Int]
    let boundary: Int
    let n: Int
    let logProb: [Double]          // flat row-major n*n
    let anchorHigh: Double
    let anchorLow: Double
    let threshold: Double

    /// Average transition probability per bigram (0..1). Higher = more word-like.
    func score(_ word: String) -> Double {
        let chars = word.lowercased().filter { index[$0] != nil }
        guard !chars.isEmpty else { return 0 }
        var prev = boundary, logSum = 0.0, count = 0
        for c in chars {
            let cur = index[c]!
            logSum += logProb[prev * n + cur]; count += 1
            prev = cur
        }
        logSum += logProb[prev * n + boundary]; count += 1   // closing boundary
        return exp(logSum / Double(count))
    }

    /// 0..1 confidence that a score reflects a real word of this language.
    func confidence(_ p: Double) -> Double {
        guard anchorHigh > anchorLow else { return 0.5 }
        return min(1, max(0, (p - anchorLow) / (anchorHigh - anchorLow)))
    }

    /// Train an English model at runtime from the system word list.
    static func trainEnglish() -> BigramModel {
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz")
        var idx: [Character: Int] = [:]
        for (i, c) in alphabet.enumerated() { idx[c] = i }
        let boundary = alphabet.count
        let n = alphabet.count + 1

        var counts = Array(repeating: 5.0, count: n * n)
        func add(_ w: String) {
            let chars = w.lowercased().filter { idx[$0] != nil }
            guard !chars.isEmpty else { return }
            var prev = boundary
            for c in chars { let cur = idx[c]!; counts[prev * n + cur] += 1; prev = cur }
            counts[prev * n + boundary] += 1
        }

        let text = (try? String(contentsOfFile: "/usr/share/dict/words", encoding: .utf8)) ?? ""
        let words = text.split(separator: "\n").map(String.init)
        for w in words { add(w) }

        var logProb = Array(repeating: 0.0, count: n * n)
        for i in 0..<n {
            let sum = (0..<n).reduce(0.0) { $0 + counts[i * n + $1] }
            for j in 0..<n { logProb[i * n + j] = Foundation.log(counts[i * n + j] / sum) }
        }

        var model = BigramModel(index: idx, boundary: boundary, n: n, logProb: logProb,
                                anchorHigh: 0, anchorLow: 0, threshold: 0)
        // Calibrate against real words vs random key-mashing.
        let good = words.shuffled().prefix(8000).map { model.score($0) }.sorted()
        let bad = (0..<3000).map { _ -> Double in
            let len = Int.random(in: 3...8)
            return model.score(String((0..<len).map { _ in alphabet.randomElement()! }))
        }.sorted()
        func pct(_ a: [Double], _ q: Double) -> Double {
            a.isEmpty ? 0 : a[min(a.count - 1, max(0, Int(Double(a.count - 1) * q)))]
        }
        let high = pct(good, 0.10), low = pct(bad, 0.90)
        model = BigramModel(index: idx, boundary: boundary, n: n, logProb: logProb,
                            anchorHigh: high, anchorLow: low, threshold: (high + low) / 2)
        return model
    }
}

extension BigramModel {
    /// Build a baked model from generated data (see tools/gen_models.swift).
    init(entry: LanguageModelData.Entry) {
        var idx: [Character: Int] = [:]
        for (i, c) in Array(entry.alphabet).enumerated() { idx[c] = i }
        self.init(index: idx, boundary: entry.alphabet.count, n: entry.alphabet.count + 1,
                  logProb: entry.logProb, anchorHigh: entry.anchorHigh,
                  anchorLow: entry.anchorLow, threshold: entry.threshold)
    }
}

/// Detects wrong-layout / gibberish locally with per-language bigram models.
/// No network, no neural net. Symmetric: it confirms both that the typed word is
/// *not* a real word in its source language and that the converted form *is* a
/// real word in the target language. Non-Latin languages are bundled (Hebrew,
/// Russian, Greek, …); English is trained at runtime from the system word list.
final class GibberishDetector {
    static let shared = GibberishDetector()

    private var models: [String: BigramModel] = [:]   // baked, keyed by 2-letter code
    private var english: BigramModel?                 // trained at runtime
    private(set) var ready = false

    private init() {
        for (code, entry) in LanguageModelData.byLang { models[code] = BigramModel(entry: entry) }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let en = BigramModel.trainEnglish()
            DispatchQueue.main.async { self?.english = en; self?.ready = true }
        }
    }

    /// The model for a BCP-47 language code (English is the runtime-trained one).
    private func model(for lang: String) -> BigramModel? {
        let code = String(lang.lowercased().prefix(2))
        return code == "en" ? english : models[code]
    }

    /// Whether `typed` (produced in `fromLang`) looks like wrong-layout gibberish
    /// whose conversion is a real `toLang` word. Returns (false, 0) when either
    /// language has no model yet (e.g. English still training, or an unsupported
    /// language).
    func looksWrongLayout(typed: String, converted: String,
                          fromLang: String, toLang: String) -> (wrong: Bool, confidence: Double) {
        guard let src = model(for: fromLang), let dst = model(for: toLang) else { return (false, 0) }
        let typedScore = src.score(typed)        // is `typed` a real word in its language?
        let convScore = dst.score(converted)     // is the conversion a real word in the other?
        let wrong = convScore > dst.threshold && typedScore < src.threshold
        let conf = (dst.confidence(convScore) + (1 - src.confidence(typedScore))) / 2
        return (wrong, conf)
    }
}
