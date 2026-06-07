namespace Kright.Services;

/// <summary>A character bigram (Markov) model: scores how plausible a word's
/// letter-transitions are for a language. Tiny — an n×n log-probability table.
/// Mirrors the macOS implementation.</summary>
public sealed class BigramModel
{
    private readonly Dictionary<char, int> _index = new();
    private readonly int _boundary;
    private readonly int _n;
    private readonly double[] _logProb;

    public double AnchorHigh { get; }
    public double AnchorLow { get; }
    public double Threshold { get; }

    public BigramModel(string alphabet, int n, double[] logProb,
                       double anchorHigh, double anchorLow, double threshold)
    {
        for (int i = 0; i < alphabet.Length; i++) _index[alphabet[i]] = i;
        _boundary = alphabet.Length;
        _n = n;
        _logProb = logProb;
        AnchorHigh = anchorHigh;
        AnchorLow = anchorLow;
        Threshold = threshold;
    }

    /// <summary>Average transition probability per bigram (0..1). Higher = more word-like.</summary>
    public double Score(string word)
    {
        var chars = word.ToLowerInvariant().Where(c => _index.ContainsKey(c)).ToList();
        if (chars.Count == 0) return 0;
        int prev = _boundary;
        double logSum = 0;
        int count = 0;
        foreach (var c in chars)
        {
            int cur = _index[c];
            logSum += _logProb[prev * _n + cur];
            count++;
            prev = cur;
        }
        logSum += _logProb[prev * _n + _boundary]; // closing boundary
        count++;
        return Math.Exp(logSum / count);
    }

    /// <summary>0..1 confidence that a score reflects a real word of this language.</summary>
    public double Confidence(double p)
    {
        if (AnchorHigh <= AnchorLow) return 0.5;
        return Math.Clamp((p - AnchorLow) / (AnchorHigh - AnchorLow), 0, 1);
    }

    public static BigramModel English() => new(
        ModelData.EnglishAlphabet, ModelData.EnglishN, ModelData.EnglishLogProb,
        ModelData.EnglishAnchorHigh, ModelData.EnglishAnchorLow, ModelData.EnglishThreshold);

    public static BigramModel Hebrew() => new(
        ModelData.HebrewAlphabet, ModelData.HebrewN, ModelData.HebrewLogProb,
        ModelData.HebrewAnchorHigh, ModelData.HebrewAnchorLow, ModelData.HebrewThreshold);
}
