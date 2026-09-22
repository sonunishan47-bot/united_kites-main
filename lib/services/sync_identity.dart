/// Keeps the first row for each id so a retry of the same offline
/// invoice or collection cannot be stored twice.
List<T> uniqueById<T>(Iterable<T> rows, String Function(T row) idOf) {
  final seen = <String>{};
  final out = <T>[];
  for (final row in rows) {
    final id = idOf(row).trim();
    if (id.isEmpty || !seen.add(id)) continue;
    out.add(row);
  }
  return out;
}
