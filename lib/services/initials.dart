/// Two-letter avatar initials: first letter of the first name and first letter
/// of the last name ("Pankaj Bhardwaj" -> "PB"). A single name gives one
/// letter; [fallback] is used when there is no name at all.
String initialsFor(String? fullName, {String fallback = 'U'}) {
  final parts = (fullName ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return fallback;
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}
