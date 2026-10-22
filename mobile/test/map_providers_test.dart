import 'package:flutter_test/flutter_test.dart';
import 'package:social_world_mobile/src/map/map_providers.dart';

void main() {
  test('uses OpenFreeMap Liberty as the development style by default', () {
    expect(
      const OpenFreeMapStyleProvider().styleUri.toString(),
      'https://tiles.openfreemap.org/styles/liberty',
    );
  });

  test('allows replacing the map style provider URL', () {
    expect(
      const OpenFreeMapStyleProvider(
        styleUrl: 'https://maps.example.test/styles/social-world',
      ).styleUri.toString(),
      'https://maps.example.test/styles/social-world',
    );
  });
}
