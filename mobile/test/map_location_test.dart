import 'package:flutter_test/flutter_test.dart';
import 'package:social_world_mobile/src/map/map_location.dart';

void main() {
  group('MapLocationService', () {
    test('does not request coordinates before explicit permission', () async {
      final gateway = _FakeLocationGateway(
        permission: DeviceLocationPermission.denied,
        requestedPermission: DeviceLocationPermission.denied,
      );

      final result = await MapLocationService(gateway).locate();

      expect(result.issue, MapLocationIssue.permissionDenied);
      expect(gateway.requestCount, 1);
      expect(gateway.positionCount, 0);
    });

    test('returns coordinates only after permission is granted', () async {
      const coordinates = MapCoordinates(latitude: 40.18, longitude: 44.51);
      final gateway = _FakeLocationGateway(
        permission: DeviceLocationPermission.denied,
        requestedPermission: DeviceLocationPermission.granted,
        coordinates: coordinates,
      );

      final result = await MapLocationService(gateway).locate();

      expect(result.coordinates?.latitude, coordinates.latitude);
      expect(result.coordinates?.longitude, coordinates.longitude);
      expect(gateway.requestCount, 1);
      expect(gateway.positionCount, 1);
    });

    test('does not request permission again when permanently denied', () async {
      final gateway = _FakeLocationGateway(
        permission: DeviceLocationPermission.deniedForever,
      );

      final result = await MapLocationService(gateway).locate();

      expect(result.issue, MapLocationIssue.permissionDeniedForever);
      expect(gateway.requestCount, 0);
      expect(gateway.positionCount, 0);
    });

    test(
      'reports disabled location services without requesting permission',
      () async {
        final gateway = _FakeLocationGateway(enabled: false);

        final result = await MapLocationService(gateway).locate();

        expect(result.issue, MapLocationIssue.serviceOff);
        expect(gateway.requestCount, 0);
        expect(gateway.positionCount, 0);
      },
    );

    test(
      'does not expose platform errors or coordinates in an error result',
      () async {
        final gateway = _FakeLocationGateway(failToGetPosition: true);

        final result = await MapLocationService(gateway).locate();

        expect(result.issue, MapLocationIssue.unavailable);
        expect(result.coordinates, isNull);
      },
    );
  });
}

class _FakeLocationGateway implements DeviceLocationGateway {
  _FakeLocationGateway({
    this.enabled = true,
    this.permission = DeviceLocationPermission.granted,
    this.requestedPermission = DeviceLocationPermission.granted,
    this.coordinates = const MapCoordinates(latitude: 0, longitude: 0),
    this.failToGetPosition = false,
  });

  final bool enabled;
  final DeviceLocationPermission permission;
  final DeviceLocationPermission requestedPermission;
  final MapCoordinates coordinates;
  final bool failToGetPosition;
  int requestCount = 0;
  int positionCount = 0;

  @override
  Future<DeviceLocationPermission> checkPermission() async => permission;

  @override
  Future<bool> isLocationEnabled() async => enabled;

  @override
  Future<MapCoordinates> currentPosition() async {
    positionCount++;
    if (failToGetPosition) throw StateError('location lookup failed');
    return coordinates;
  }

  @override
  Future<DeviceLocationPermission> requestPermission() async {
    requestCount++;
    return requestedPermission;
  }
}
