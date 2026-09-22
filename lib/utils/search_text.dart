/// Null-safe text match for customer and product search.
bool matchesSearch(String? query, List<String?> fields) {
  final needle = query?.trim().toLowerCase() ?? '';
  if (needle.isEmpty) return true;
  for (final field in fields) {
    final hay = field?.trim().toLowerCase() ?? '';
    if (hay.isEmpty) continue;
    if (hay.contains(needle)) return true;
  }
  return false;
}
