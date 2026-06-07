using Kright.Services;
using Xunit;

namespace Kright.Tests;

// Pure-logic tests — no Win32/UIA/keyboard-layout calls needed.

public class LayoutConverterTests
{
    [Theory]
    [InlineData('ש', true)]
    [InlineData('ת', true)]
    [InlineData('א', true)]
    [InlineData('a', false)]
    [InlineData('5', false)]
    public void IsHebrew_DetectsHebrewBlock(char c, bool expected)
        => Assert.Equal(expected, LayoutConverter.IsHebrew(c));

    [Theory]
    [InlineData('a', true)]
    [InlineData('z', true)]
    [InlineData('Z', true)]
    [InlineData('ש', false)]
    [InlineData('5', false)]
    [InlineData(' ', false)]
    public void IsLatin_DetectsAsciiLetters(char c, bool expected)
        => Assert.Equal(expected, LayoutConverter.IsLatin(c));
}

public class LanguageManagerTests
{
    [Theory]
    [InlineData("en", true)]
    [InlineData("EN", true)]
    [InlineData("fr", true)]
    [InlineData("de", true)]
    [InlineData("es", true)]
    [InlineData("", true)]      // unknown → don't disrupt
    public void IsLatinLanguage_LatinScripts(string code, bool expected)
        => Assert.Equal(expected, LanguageManager.IsLatinLanguage(code));

    [Theory]
    [InlineData("he")]
    [InlineData("iw")]
    [InlineData("ar")]
    [InlineData("fa")]
    [InlineData("ru")]
    [InlineData("uk")]
    [InlineData("el")]
    [InlineData("hy")]
    [InlineData("ka")]
    [InlineData("zh")]
    [InlineData("ja")]
    [InlineData("ko")]
    [InlineData("th")]
    [InlineData("hi")]
    public void IsLatinLanguage_NonLatinScripts(string code)
        => Assert.False(LanguageManager.IsLatinLanguage(code));
}
