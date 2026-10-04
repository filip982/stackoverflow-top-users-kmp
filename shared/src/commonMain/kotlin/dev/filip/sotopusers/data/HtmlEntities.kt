package dev.filip.sotopusers.data

/**
 * Decodes HTML character references as found in StackExchange text fields
 * (numeric decimal/hex plus the named entities that realistically occur in names/locations).
 *
 * The API sometimes double-encodes (`&amp;eacute;`), so decoding repeats until the text is stable
 * (bounded to [MAX_PASSES]). Unknown or invalid references are left untouched.
 */
internal object HtmlEntities {
    private const val MAX_PASSES = 3
    private val reference = Regex("&(#[0-9]{1,8}|#[xX][0-9a-fA-F]{1,6}|[A-Za-z][A-Za-z0-9]{1,7});")

    private val latin1Names = (
        "nbsp iexcl cent pound curren yen brvbar sect uml copy ordf laquo not shy reg macr deg plusmn sup2 sup3 " +
            "acute micro para middot cedil sup1 ordm raquo frac14 frac12 frac34 iquest Agrave Aacute Acirc Atilde " +
            "Auml Aring AElig Ccedil Egrave Eacute Ecirc Euml Igrave Iacute Icirc Iuml ETH Ntilde Ograve Oacute " +
            "Ocirc Otilde Ouml times Oslash Ugrave Uacute Ucirc Uuml Yacute THORN szlig agrave aacute acirc atilde " +
            "auml aring aelig ccedil egrave eacute ecirc euml igrave iacute icirc iuml eth ntilde ograve oacute " +
            "ocirc otilde ouml divide oslash ugrave uacute ucirc uuml yacute thorn yuml"
        ).split(' ')

    private val named: Map<String, Int> = buildMap {
        latin1Names.forEachIndexed { i, name -> put(name, 160 + i) }
        put("amp", '&'.code); put("lt", '<'.code); put("gt", '>'.code)
        put("quot", '"'.code); put("apos", '\''.code)
        put("OElig", 338); put("oelig", 339); put("Scaron", 352); put("scaron", 353); put("Yuml", 376)
        put("ndash", 8211); put("mdash", 8212); put("lsquo", 8216); put("rsquo", 8217)
        put("ldquo", 8220); put("rdquo", 8221); put("bull", 8226); put("hellip", 8230)
        put("euro", 8364); put("trade", 8482)
    }

    fun decode(input: String): String {
        var current = input
        repeat(MAX_PASSES) {
            if ('&' !in current) return current
            val next = decodeOnce(current)
            if (next == current) return current
            current = next
        }
        return current
    }

    private fun decodeOnce(text: String): String = reference.replace(text) { match ->
        val body = match.groupValues[1]
        val codePoint = when {
            body.startsWith("#x") || body.startsWith("#X") -> body.drop(2).toIntOrNull(16)
            body.startsWith("#") -> body.drop(1).toIntOrNull()
            else -> named[body]
        }
        codePoint?.let(::codePointToString) ?: match.value
    }

    private fun codePointToString(cp: Int): String? = when {
        cp <= 0 || cp > 0x10FFFF || cp in 0xD800..0xDFFF -> null
        cp < 0x10000 -> cp.toChar().toString()
        else -> {
            val v = cp - 0x10000
            charArrayOf((0xD800 + (v shr 10)).toChar(), (0xDC00 + (v and 0x3FF)).toChar()).concatToString()
        }
    }
}
