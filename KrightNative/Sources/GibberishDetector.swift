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

    static func hebrew() -> BigramModel {
        let alphabet = Array(HebrewModelData.alphabet)
        var idx: [Character: Int] = [:]
        for (i, c) in alphabet.enumerated() { idx[c] = i }
        return BigramModel(index: idx, boundary: alphabet.count, n: HebrewModelData.n,
                           logProb: HebrewModelData.logProb,
                           anchorHigh: HebrewModelData.anchorHigh,
                           anchorLow: HebrewModelData.anchorLow,
                           threshold: HebrewModelData.threshold)
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

/// Detects wrong-layout / gibberish locally using two bigram models (English +
/// Hebrew). No network, no neural net. Symmetric: it confirms both that the
/// typed word is *not* a real word in its own script and that the converted form
/// *is* a real word in the other.
final class GibberishDetector {
    static let shared = GibberishDetector()

    private let hebrew = BigramModel.hebrew()
    private var english: BigramModel?
    private(set) var ready = false

    private init() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let en = BigramModel.trainEnglish()
            DispatchQueue.main.async { self?.english = en; self?.ready = true }
        }
    }

    func looksWrongLayout(typed: String, converted: String) -> (wrong: Bool, confidence: Double) {
        guard ready, let en = english else { return (false, 0) }
        let typedIsHebrew = typed.contains { LayoutConverter.isHebrew($0) }

        if typedIsHebrew {
            let he = hebrew.score(typed)        // is typed real Hebrew?
            let ascii = en.score(converted)     // is the conversion real English?
            let wrong = ascii > en.threshold && he < hebrew.threshold
            let conf = (en.confidence(ascii) + (1 - hebrew.confidence(he))) / 2
            return (wrong, conf)
        } else {
            let ascii = en.score(typed)         // is typed real English?
            let he = hebrew.score(converted)    // is the conversion real Hebrew?
            let wrong = he > hebrew.threshold && ascii < en.threshold
            let conf = (hebrew.confidence(he) + (1 - en.confidence(ascii))) / 2
            return (wrong, conf)
        }
    }
}
