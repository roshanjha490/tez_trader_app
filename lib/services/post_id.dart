/// Post ids travel as 6-character codes in links, e.g. the
/// `/community/post/<code>` link inside a notification. This is a port of
/// the backend's `utils/postId.js` / the portal's `lib/postId.ts`.
const String _alphabet =
    'qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM0123456789';
const int _base = 62;
const int _length = 6;
const int _mod = 4294967296; // 2^32
const int _mult = 0x9e3779b1;
const int _key = 0x5bd1e995;
const int _mask = 0xFFFFFFFF;

int _imul(int a, int b) => (a * b) & _mask;

// Modular inverse of _mult mod 2^32 (Newton iteration).
final int _inv = () {
  var inv = _mult;
  for (var i = 0; i < 5; i++) {
    inv = _imul(inv, (2 - _imul(_mult, inv)) & _mask);
  }
  return inv;
}();

String encodePostId(int id) {
  var x = (_imul(id, _mult) ^ _key) & _mask;
  var out = '';
  for (var i = 0; i < _length; i++) {
    out = _alphabet[x % _base] + out;
    x ~/= _base;
  }
  return out;
}

/// Returns the numeric post id, or null if [code] isn't a valid post code.
int? decodePostId(String code) {
  if (code.length != _length) return null;
  var x = 0;
  for (final ch in code.split('')) {
    final idx = _alphabet.indexOf(ch);
    if (idx == -1) return null;
    x = x * _base + idx;
  }
  if (x >= _mod) return null;
  return _imul((x ^ _key) & _mask, _inv);
}

/// Pulls the post id out of a notification link such as
/// `https://teztrader.com/community/post/AbC123`, or null if the link
/// isn't a post link.
int? postIdFromLink(String? link) {
  if (link == null) return null;
  final match = RegExp(r'/community/post/([A-Za-z0-9]{6})(?:[/?#]|$)')
      .firstMatch(link);
  if (match == null) return null;
  return decodePostId(match.group(1)!);
}
