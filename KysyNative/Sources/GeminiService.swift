import Foundation

/// Calls the Gemini REST API directly (no SDK). The API key is stored in
/// UserDefaults.
enum GeminiService {
    private static let keyDefaults = "gemini_api_key"
    private static let model = "gemini-2.0-flash"

    static var apiKey: String {
        get { UserDefaults.standard.string(forKey: keyDefaults) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: keyDefaults) }
    }

    static var isReady: Bool { !apiKey.isEmpty }

    struct GeminiError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Expands a short phrase into a full message.
    static func expand(_ phrase: String) async throws -> String {
        guard isReady else { throw GeminiError(message: "API key not configured") }
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GeminiError(message: "Input is empty") }

        let urlStr = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlStr) else { throw GeminiError(message: "Bad URL") }

        let body: [String: Any] = [
            "system_instruction": [
                "parts": [["text":
                    "You are a smart text expansion assistant built into a keyboard tool. " +
                    "When given a short phrase, abbreviation, or rough idea, expand it into a clear, " +
                    "complete, professional message ready to use. Return only the expanded text — " +
                    "no explanations, no quotes, no extra formatting."]]
            ],
            "contents": [["parts": [["text": "Expand this: \(trimmed)"]]]],
            "generationConfig": ["temperature": 0.7, "maxOutputTokens": 1024],
        ]

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw GeminiError(message: "Gemini error \(http.statusCode): \(msg)")
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let first = candidates.first,
            let content = first["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let text = parts.first?["text"] as? String
        else {
            throw GeminiError(message: "No response from Gemini")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
