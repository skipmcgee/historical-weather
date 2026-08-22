import '../models/location.dart';
import 'nominatim_service.dart';
import 'open_meteo_service.dart';

/// Searches both Open-Meteo's place/city geocoder and OpenStreetMap's
/// Nominatim (which additionally resolves specific street addresses and
/// points of interest), merging and de-duplicating the results into one
/// list. Tolerant of either source failing individually -- one being
/// temporarily unavailable shouldn't break location search entirely --
/// but surfaces an error if *both* fail, rather than silently reporting
/// "no matches found" for what's actually a network problem.
Future<List<Location>> searchAllLocations({
  required OpenMeteoService openMeteo,
  required NominatimService nominatim,
  required String query,
}) async {
  Object? openMeteoError;
  Object? nominatimError;

  final openMeteoFuture = openMeteo.searchLocations(query).catchError((Object e) {
    openMeteoError = e;
    return <Location>[];
  });
  final nominatimFuture = nominatim.searchAddresses(query).catchError((Object e) {
    nominatimError = e;
    return <Location>[];
  });

  final openMeteoResults = await openMeteoFuture;
  final nominatimResults = await nominatimFuture;

  if (openMeteoError != null && nominatimError != null) {
    throw openMeteoError!;
  }

  return _dedupe([...openMeteoResults, ...nominatimResults]);
}

/// Collapses results that resolve to essentially the same point (~100m)
/// down to one -- Open-Meteo's city-centroid result and Nominatim's
/// equivalent city-boundary result for the same place are common
/// duplicates otherwise. Keeps whichever copy was added first (Open-Meteo's
/// results are placed first by the caller, since its labels are typically
/// the cleaner of the two for a plain place name).
List<Location> _dedupe(List<Location> locations) {
  final seen = <String>{};
  final result = <Location>[];
  for (final location in locations) {
    final key = '${location.latitude.toStringAsFixed(3)},${location.longitude.toStringAsFixed(3)}';
    if (seen.add(key)) result.add(location);
  }
  return result;
}
