import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeminiService {
  static const _keyPref = 'gemini_api_key';

  static GenerativeModel? _model;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_keyPref) ?? '';
    if (key.isNotEmpty) _model = _buildModel(key);
  }

  static Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPref, key.trim());
    _model = key.trim().isNotEmpty ? _buildModel(key.trim()) : null;
  }

  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPref);
  }

  static bool get isReady => _model != null;

  static GenerativeModel _buildModel(String apiKey) => GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          maxOutputTokens: 1024,
        ),
        systemInstruction: Content.system(
          'You are a smart text expansion assistant built into a keyboard tool. '
          'When given a short phrase, abbreviation, or rough idea, expand it into '
          'a clear, complete, professional message ready to use. '
          'Return only the expanded text — no explanations, no quotes, no extra formatting.',
        ),
      );

  static Future<String> expand(String shortPhrase) async {
    if (_model == null) throw Exception('API key not configured');
    if (shortPhrase.trim().isEmpty) throw Exception('Input is empty');

    final response = await _model!.generateContent([
      Content.text('Expand this: $shortPhrase'),
    ]);

    final text = response.text;
    if (text == null || text.isEmpty) throw Exception('No response from Gemini');
    return text.trim();
  }
}
