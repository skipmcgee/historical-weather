/// Formats a [DateTime] as an `YYYY-MM-DD` date string -- the format
/// Open-Meteo's API expects and this app's JSON export uses everywhere a
/// date appears. Deliberately not `DateTime.toIso8601String()`, which
/// includes a time component this app never wants.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
