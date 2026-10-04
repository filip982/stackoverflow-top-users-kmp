package dev.filip.sotopusers.data

import kotlin.test.Test
import kotlin.test.assertEquals

class HtmlEntitiesTest {
    @Test fun plainTextIsUnchanged() = assertEquals("Jon Skeet", HtmlEntities.decode("Jon Skeet"))

    @Test fun decodesCommonNamedEntities() =
        assertEquals("<a> & \"b\" 'c' é ü ç ñ ß", HtmlEntities.decode("&lt;a&gt; &amp; &quot;b&quot; &apos;c&apos; &eacute; &uuml; &ccedil; &ntilde; &szlig;"))

    @Test fun decodesDecimalNumericEntities() =
        assertEquals("Günter Zöchbauer", HtmlEntities.decode("G&#252;nter Z&#246;chbauer"))

    @Test fun decodesHexNumericEntities() =
        assertEquals("Stribiżew", HtmlEntities.decode("Stribi&#x17C;ew"))

    @Test fun decodesSupplementaryCodePoints() = assertEquals("hi 😀", HtmlEntities.decode("hi &#128512;"))

    @Test fun decodesDoubleEncodedEntities() =
        assertEquals("René \"Ren\" Gentle", HtmlEntities.decode("Ren&amp;eacute; &amp;quot;Ren&amp;quot; Gentle"))

    @Test fun leavesUnknownAndInvalidReferencesAlone() =
        assertEquals("Tom & Jerry &bogus; &#xZZ; &#; &", HtmlEntities.decode("Tom & Jerry &bogus; &#xZZ; &#; &"))

    @Test fun leavesOutOfRangeCodePointsAlone() = assertEquals("&#99999999;", HtmlEntities.decode("&#99999999;"))
}
