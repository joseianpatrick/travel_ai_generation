import 'package:kalsada/shared/utils/external_maps.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mapsViewUri builds a geo intent with a labelled query', () {
    final uri = mapsViewUri(10.5, 119.2, 'Port Barton');

    expect(uri.scheme, 'geo');
    expect(uri.toString(), startsWith('geo:10.5,119.2?q=10.5,119.2'));
    expect(uri.toString(), contains('Port%20Barton'));
  });

  test('mapsDirectionsUri builds a Google Maps directions link', () {
    final uri = mapsDirectionsUri(11.18, 119.39);

    expect(uri.scheme, 'https');
    expect(uri.host, 'www.google.com');
    expect(uri.queryParameters['destination'], '11.18,119.39');
    expect(uri.queryParameters['travelmode'], 'driving');
  });

  test('nearbyFoodUri creates an Android maps-app restaurant search', () {
    final uri = nearbyFoodUri(11.18, 119.39, platform: TargetPlatform.android);

    expect(uri.scheme, 'geo');
    expect(uri.toString(), 'geo:11.18,119.39?q=restaurants');
  });

  test('nearbyFoodUri creates an Apple Maps restaurant search on iOS', () {
    final uri = nearbyFoodUri(11.18, 119.39, platform: TargetPlatform.iOS);

    expect(uri.host, 'maps.apple.com');
    expect(uri.queryParameters['q'], 'Restaurants');
    expect(uri.queryParameters['ll'], '11.18,119.39');
  });
}
