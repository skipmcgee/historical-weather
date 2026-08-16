/// How the per-day metrics are collapsed into a single figure for the
/// selected date range. Totals (precipitation, snowfall, ET0) are always
/// sums regardless, and wind direction is always a circular mean (a plain
/// median of compass degrees is meaningless) -- this only affects the
/// "typical value" fields like temperature, humidity, wind speed, etc.
enum AggregationMethod {
  median,
  average;

  String get label => switch (this) {
        AggregationMethod.median => 'Median',
        AggregationMethod.average => 'Average',
      };
}
