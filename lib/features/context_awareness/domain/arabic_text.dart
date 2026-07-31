/// Arabic normalisation and token matching shared by the context classifiers.
///
/// Substring matching on Arabic is a trap the codebase has already been bitten
/// by: `'هم'` matches inside `اللهم`, `'دين'` inside `الدين`. Everything here
/// matches on token boundaries instead.
library;

/// Diacritics (harakat), tatweel, and the Quranic annotation range.
final RegExp _diacritics = RegExp(
  r'[ؐ-ًؚ-ٰٟۖ-ۭـ]',
);

final RegExp _nonWord = RegExp(r'[^؀-ۿݐ-ݿa-zA-Z0-9]+');

/// Folds the orthographic variation that makes naive matching fail:
/// alef forms, ta marbuta, alef maqsura, and Persian/Urdu yeh and kaf.
String normalizeArabic(String input) {
  var s = input.replaceAll(_diacritics, '');
  s = s
      .replaceAll('آ', 'ا') // آ -> ا
      .replaceAll('أ', 'ا') // أ -> ا
      .replaceAll('إ', 'ا') // إ -> ا
      .replaceAll('ٱ', 'ا') // ٱ -> ا
      .replaceAll('ة', 'ه') // ة -> ه
      .replaceAll('ى', 'ي') // ى -> ي
      .replaceAll('ی', 'ي') // ی -> ي
      .replaceAll('ک', 'ك'); // ک -> ك
  return s.toLowerCase();
}

/// Splits into normalised tokens, dropping punctuation and empties.
List<String> tokenize(String input) => normalizeArabic(input)
    .split(_nonWord)
    .where((t) => t.isNotEmpty)
    .toList(growable: false);

/// Common Arabic proclitics, stripped so `الزلزال` also matches `زلزال`.
const List<String> _prefixes = ['وال', 'بال', 'كال', 'فال', 'ال', 'و', 'ف', 'ب', 'ل', 'ك'];

/// The token itself plus its prefix-stripped forms.
Set<String> tokenVariants(String token) {
  final out = <String>{token};
  for (final p in _prefixes) {
    if (token.length > p.length + 2 && token.startsWith(p)) {
      out.add(token.substring(p.length));
    }
  }
  return out;
}

/// True when [keyword] matches [tokens] on a token boundary.
///
/// A multi-word keyword falls back to a phrase check against the normalised
/// text. A single-word keyword must equal a token (or one of its
/// prefix-stripped variants); keywords of four characters or more may also
/// match as a prefix, which covers Arabic suffixed forms without admitting
/// the short-stem false positives that plain `contains` produced.
bool keywordMatches(String keyword, String normalizedText, List<String> tokens) {
  final kw = normalizeArabic(keyword);
  if (kw.isEmpty) return false;
  if (kw.contains(' ')) return normalizedText.contains(kw);
  for (final t in tokens) {
    for (final v in tokenVariants(t)) {
      if (v == kw) return true;
      if (kw.length >= 4 && v.startsWith(kw)) return true;
    }
  }
  return false;
}
