// Comparing versions as the products write them: "4.4.0", "3.4", "6.2", "1.0.3".

/// Negative when [a] is older than [b], 0 when the same (3.4 = 3.4.0), positive when newer
int compareVersions(String a, String b) {
  List<int> parts(String v) => [
    for (final p in v.trim().replaceFirst(RegExp(r'^[vV]'), '').split(RegExp(r'[.+-]'))) int.tryParse(p) ?? 0,
  ];
  final x = parts(a), y = parts(b);
  final n = x.length > y.length ? x.length : y.length;
  for (var i = 0; i < n; i++) {
    final p = i < x.length ? x[i] : 0, q = i < y.length ? y[i] : 0;
    if (p != q) return p < q ? -1 : 1;
  }
  return 0;
}

/// True when [candidate] is a higher version than [current]
bool isNewer(String candidate, String current) => compareVersions(candidate, current) > 0;

/// A version as the products write it, nothing else (for anything read from a file or the registry)
bool looksLikeVersion(String v) => RegExp(r'^[vV]?\d+(\.\d+){0,3}$').hasMatch(v.trim());
