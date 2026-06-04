// Converts ASCII emoticons to emoji characters.
// Matches only at word/token boundaries (preceded by start-of-string or
// whitespace, followed by whitespace or end-of-string) so URLs like
// "example.com:8080" are left untouched.

const _map = <String, String>{
  // Longest patterns first so e.g. ">:-(" beats ">:(" and ":-(" beats ":("
  r'>:-(': '😠',
  r'>:(': '😠',
  r":'(": '😭',
  r':-D': '😄',
  r':D': '😄',
  r':-)': '😊',
  r':)': '😊',
  r':-]': '😊',
  r':-)>': '😊',
  r':-(':  '😢',
  r':(': '😢',
  r';-)': '😉',
  r';)': '😉',
  r':-P': '😛',
  r':P': '😛',
  r':-p': '😛',
  r':p': '😛',
  r':-*': '😘',
  r':*': '😘',
  r':-|': '😐',
  r':|': '😐',
  r':-O': '😮',
  r':O': '😮',
  r':-o': '😮',
  r':o': '😮',
  r'B-)': '😎',
  r'B)': '😎',
  r'</3': '💔',
  r'<3': '❤️',
  r'XD': '😆',
  r'xD': '😆',
  r'D:': '😱',
};

String convertAsciiEmoji(String text) {
  if (text.isEmpty) return text;

  // Build a single alternation sorted longest-first so greedy matching
  // picks the correct variant.
  final sorted = _map.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  final pattern = sorted.map(RegExp.escape).join('|');

  // Match emoticons preceded by start-of-string or whitespace,
  // followed by whitespace or end-of-string (lookahead keeps delimiters
  // available for the next match).
  return text.replaceAllMapped(
    RegExp('(?:^|(?<=[\\s]))($pattern)(?=[\\s]|\$)'),
    (m) => _map[m.group(1)!] ?? m.group(0)!,
  );
}
