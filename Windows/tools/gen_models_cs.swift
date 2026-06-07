import Foundation

struct Model {
    let alphabet: [Character]
    let n: Int
    let logProb: [Double]
    let anchorHigh: Double
    let anchorLow: Double
    let threshold: Double
}

func train(words: [String], alphabet: [Character]) -> Model {
    var index: [Character: Int] = [:]
    for (i, c) in alphabet.enumerated() { index[c] = i }
    let boundary = alphabet.count
    let n = alphabet.count + 1
    var counts = Array(repeating: 5.0, count: n * n)

    func add(_ w: String) {
        let chars = w.lowercased().filter { index[$0] != nil }
        guard !chars.isEmpty else { return }
        var prev = boundary
        for c in chars { let cur = index[c]!; counts[prev * n + cur] += 1; prev = cur }
        counts[prev * n + boundary] += 1
    }
    for w in words { add(w) }

    var logProb = Array(repeating: 0.0, count: n * n)
    for i in 0..<n {
        let sum = (0..<n).reduce(0.0) { $0 + counts[i * n + $1] }
        for j in 0..<n { logProb[i * n + j] = log(counts[i * n + j] / sum) }
    }
    func score(_ w: String) -> Double {
        let chars = w.lowercased().filter { index[$0] != nil }
        guard !chars.isEmpty else { return 0 }
        var prev = boundary, s = 0.0, c = 0
        for ch in chars { let cur = index[ch]!; s += logProb[prev * n + cur]; c += 1; prev = cur }
        s += logProb[prev * n + boundary]; c += 1
        return exp(s / Double(c))
    }
    let good = words.shuffled().prefix(8000).map { score($0) }.sorted()
    let bad = (0..<3000).map { _ -> Double in
        let len = Int.random(in: 3...8)
        return score(String((0..<len).map { _ in alphabet.randomElement()! }))
    }.sorted()
    func pct(_ a: [Double], _ q: Double) -> Double { a[min(a.count-1, max(0, Int(Double(a.count-1)*q)))] }
    let high = pct(good, 0.10), low = pct(bad, 0.90)
    return Model(alphabet: alphabet, n: n, logProb: logProb, anchorHigh: high, anchorLow: low, threshold: (high + low) / 2)
}

// English
let enText = (try? String(contentsOfFile: "/usr/share/dict/words", encoding: .utf8)) ?? ""
let enWords = enText.split(separator: "\n").map(String.init)
let en = train(words: enWords, alphabet: Array("abcdefghijklmnopqrstuvwxyz"))

// Hebrew
let heAlphabet: [Character] = (0x05D0...0x05EA).compactMap { UnicodeScalar($0).map(Character.init) }
var heIdx: [Character: Int] = [:]; for (i,c) in heAlphabet.enumerated() { heIdx[c] = i }
let heText = (try? String(contentsOfFile: "/tmp/he.dic", encoding: .utf8)) ?? ""
let heWords = heText.split(separator: "\n").map { line -> String in
    let w = line.split(separator: "/").first.map(String.init) ?? String(line)
    return String(w.filter { heIdx[$0] != nil })
}.filter { $0.count >= 2 }
let he = train(words: heWords, alphabet: heAlphabet)

func arr(_ a: [Double]) -> String { a.map { String(format: "%.4f", $0) }.joined(separator: ", ") }

var out = "// Auto-generated bigram models (English: /usr/share/dict/words, Hebrew: LibreOffice he_IL).\n"
out += "// Regenerate with tools/gen_models_cs.swift. Do not edit by hand.\n"
out += "namespace Kright.Services;\n\n"
out += "public static class ModelData\n{\n"
out += "    public const string EnglishAlphabet = \"abcdefghijklmnopqrstuvwxyz\";\n"
out += "    public const int EnglishN = \(en.n);\n"
out += "    public const double EnglishAnchorHigh = \(en.anchorHigh);\n"
out += "    public const double EnglishAnchorLow = \(en.anchorLow);\n"
out += "    public const double EnglishThreshold = \(en.threshold);\n"
out += "    public static readonly double[] EnglishLogProb = { \(arr(en.logProb)) };\n\n"
out += "    public const string HebrewAlphabet = \"\(String(heAlphabet))\";\n"
out += "    public const int HebrewN = \(he.n);\n"
out += "    public const double HebrewAnchorHigh = \(he.anchorHigh);\n"
out += "    public const double HebrewAnchorLow = \(he.anchorLow);\n"
out += "    public const double HebrewThreshold = \(he.threshold);\n"
out += "    public static readonly double[] HebrewLogProb = { \(arr(he.logProb)) };\n"
out += "}\n"
try! out.write(toFile: "/Users/walter_yaron/Documents/kright/Windows/Services/ModelData.cs", atomically: true, encoding: .utf8)
FileHandle.standardError.write("en n=\(en.n) thr=\(en.threshold)  he n=\(he.n) thr=\(he.threshold)\n".data(using: .utf8)!)
