namespace Kysy.Services;

/// <summary>Detects wrong-layout / gibberish locally using two bigram models
/// (English + Hebrew), both embedded. No network, no neural net. Symmetric: it
/// confirms both that the typed word is not a real word in its own script and
/// that the converted form is a real word in the other.</summary>
public static class GibberishDetector
{
    private static readonly BigramModel En = BigramModel.English();
    private static readonly BigramModel He = BigramModel.Hebrew();

    public static (bool Wrong, double Confidence) LooksWrongLayout(string typed, string converted)
    {
        bool typedIsHebrew = typed.Any(LayoutConverter.IsHebrew);

        if (typedIsHebrew)
        {
            double he = He.Score(typed);          // is typed real Hebrew?
            double ascii = En.Score(converted);   // is the conversion real English?
            bool wrong = ascii > En.Threshold && he < He.Threshold;
            double conf = (En.Confidence(ascii) + (1 - He.Confidence(he))) / 2;
            return (wrong, conf);
        }
        else
        {
            double ascii = En.Score(typed);        // is typed real English?
            double he = He.Score(converted);       // is the conversion real Hebrew?
            bool wrong = he > He.Threshold && ascii < En.Threshold;
            double conf = (He.Confidence(he) + (1 - En.Confidence(ascii))) / 2;
            return (wrong, conf);
        }
    }
}
