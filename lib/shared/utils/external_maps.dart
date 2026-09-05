import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// `geo:` intent that lets Android offer any installed maps app for viewing
/// the point. [label] is shown as the pin title.
Uri mapsViewUri(double latitude, double longitude, String label) {
  final coords = '$latitude,$longitude';
  return Uri.parse('geo:$coords?q=$coords(${Uri.encodeComponent(label)})');
}

/// Universal Google Maps directions link — routing is handled entirely by the
/// external app, so we never need a routing API of our own.
Uri mapsDirectionsUri(double latitude, double longitude) {
  return Uri.parse(
    'https://www.google.com/maps/dir/?api=1'
    '&destination=$latitude,$longitude&travelmode=driving',
  );
}

/// A restaurant search centered on the itinerary day's stored coordinates.
///
/// Android's `geo:` intent lets the device choose Google Maps or another
/// installed maps app. Apple Maps receives its native web URL on iOS.
Uri nearbyFoodUri(
  double latitude,
  double longitude, {
  TargetPlatform? platform,
}) {
  final targetPlatform = platform ?? defaultTargetPlatform;
  final coords = '$latitude,$longitude';
  if (targetPlatform == TargetPlatform.iOS) {
    return Uri.https('maps.apple.com', '/', {'q': 'Restaurants', 'll': coords});
  }
  return Uri.parse('geo:$coords?q=restaurants');
}

/// Opens a URI in an external maps-capable application.
Future<bool> launchExternalMap(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
