import Foundation

// Hebrew alphabet: U+05D0...U+05EA (22 letters + 5 final forms = 27), in code order.
let alphabet: [Character] = (0x05D0...0x05EA).compactMap { UnicodeScalar($0).map(Character.init) }
let n = alphabet.count + 1          // + boundary
let boundary = n - 1
var index: [Character: Int] = [:]
for (i, c) in alphabet.enumerated() { index[c] = i }

func cleaned(_ line: Substring) -> String {
    let word = line.split(separator: "/").first.map(String.init) ?? String(line)
    return String(word.filter { index[$0] != nil })
}

let text = (try? String(contentsOfFile: "/tmp/he.dic", encoding: .utf8)) ?? ""
let words = text.split(separator: "\n").map { cleaned($0) }.filter { $0.count >= 2 }
FileHandle.standardError.write("words: \(words.count)\n".data(using: .utf8)!)

var counts = Array(repeating: Array(repeating: 5.0, count: n), count: n)
func countWord(_ w: String) {
    let chars = Array(" " + w + " ")
    for i in 0..<(chars.count - 1) {
        let a = chars[i] == " " ? boundary : index[chars[i]]!
        let b = chars[i+1] == " " ? boundary : index[chars[i+1]]!
        counts[a][b] += 1
    }
}
for w in words { countWord(w) }

var logProb = Array(repeating: Array(repeating: 0.0, count: n), count: n)
for i in 0..<n {
    let sum = counts[i].reduce(0, +)
    for j in 0..<n { logProb[i][j] = log(counts[i][j] / sum) }
}

func score(_ w: String) -> Double {
    let chars = Array(" " + w + " ")
    var s = 0.0, c = 0
    for i in 0..<(chars.count - 1) {
        let a = chars[i] == " " ? boundary : (index[chars[i]] ?? boundary)
        let b = chars[i+1] == " " ? boundary : (index[chars[i+1]] ?? boundary)
        s += logProb[a][b]; c += 1
    }
    return c > 0 ? exp(s / Double(c)) : 0
}

// Calibrate: real words vs random Hebrew key-mashing.
let good = words.shuffled().prefix(8000).map { score($0) }.sorted()
let bad = (0..<3000).map { _ -> Double in
    let len = Int.random(in: 3...8)
    return score(String((0..<len).map { _ in alphabet.randomElement()! }))
}.sorted()
func pct(_ a: [Double], _ q: Double) -> Double { a[min(a.count-1, max(0, Int(Double(a.count-1)*q)))] }
let anchorHigh = pct(good, 0.10)
let anchorLow = pct(bad, 0.90)
let threshold = (anchorHigh + anchorLow) / 2

// Emit a Swift source file.
var out = "// Auto-generated Hebrew bigram model (from LibreOffice he_IL dictionary).\n"
out += "// Do not edit by hand — regenerate with tools/gen_hebrew.swift.\n"
out += "enum HebrewModelData {\n"
out += "    static let alphabet = \"\(String(alphabet))\"\n"
out += "    static let n = \(n)\n"
out += "    static let anchorHigh = \(anchorHigh)\n"
out += "    static let anchorLow = \(anchorLow)\n"
out += "    static let threshold = \(threshold)\n"
out += "    static let logProb: [Double] = [\n"
for i in 0..<n {
    let row = logProb[i].map { String(format: "%.4f", $0) }.joined(separator: ", ")
    out += "        \(row),\n"
}
out += "    ]\n}\n"
try! out.write(toFile: "/Users/walter_yaron/Documents/kright/KrightNative/Sources/HebrewModelData.swift", atomically: true, encoding: .utf8)

// Sanity print
FileHandle.standardError.write("threshold=\(threshold) high=\(anchorHigh) low=\(anchorLow)\n".data(using: .utf8)!)
for w in ["שלום", "ספר", "מחשב", "קסןא", " wכ", "abcd"] {
    FileHandle.standardError.write("score(\(w))=\(String(format: "%.4f", score(w)))\n".data(using: .utf8)!)
}
