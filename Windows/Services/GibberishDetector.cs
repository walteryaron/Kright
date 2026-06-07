namespace Kright.Services;

/// <summary>Detects wrong-layout / gibberish locally with per-language bigram
/// models (English + Hebrew, Russian, Greek, …), all embedded. No network, no
/// neural net. Symmetric: it confirms both that the typed word is not a real word
/// in its source language and that the converted form is a real word in the
/// target language.</summary>
public static class GibberishDetector
{
    private static readonly Dictionary<string, BigramModel> Models =
        LanguageModelData.ByLang.ToDictionary(kv => kv.Key, kv => BigramModel.FromEntry(kv.Value));

    private static BigramModel? Model(string lang)
    {
        var code = (lang ?? "").ToLowerInvariant();
        if (code.Length > 2) code = code.Substring(0, 2);
        return Models.TryGetValue(code, out var m) ? m : null;
    }

    /// <summary>Whether <paramref name="typed"/> (produced in <paramref name="fromLang"/>)
    /// looks like wrong-layout gibberish whose conversion is a real
    /// <paramref name="toLang"/> word. Returns (false, 0) for unsupported languages.</summary>
    public static (bool Wrong, double Confidence) LooksWrongLayout(
        string typed, string converted, string fromLang, string toLang)
    {
        var src = Model(fromLang);
        var dst = Model(toLang);
        if (src is null || dst is null) return (false, 0);
        double typedScore = src.Score(typed);
        double convScore = dst.Score(converted);
        bool wrong = convScore > dst.Threshold && typedScore < src.Threshold;
        double conf = (dst.Confidence(convScore) + (1 - src.Confidence(typedScore))) / 2;
        return (wrong, conf);
    }
}
