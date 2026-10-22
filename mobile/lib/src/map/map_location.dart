import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

final mapLocationServiceProvider = Provider<MapLocationService>(
  (ref) => MapLocationService(GeolocatorDeviceLocationGateway()),
);

enum MapLocationIssue {
  permissionDenied,
  permissionDeniedForever,
  serviceOff,
  unavailable,
}

class MapCoordinates {
  const MapCoordinates({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class MapLocationResult {
  const MapLocationResult._({this.coordinates, this.issue});

  const MapLocationResult.success(MapCoordinates value)
    : this._(coordinates: value);

  const MapLocationResult.failure(MapLocationIssue value)
    : this._(issue: value);

  final MapCoordinates? coordinates;
  final MapLocationIssue? issue;

  bool get isSuccess => coordinates != null;
}

enum DeviceLocationPermission { granted, denied, deniedForever }

abstract interface class DeviceLocationGateway {
  Future<bool> isLocationEnabled();
  Future<DeviceLocationPermission> checkPermission();
  Future<DeviceLocationPermission> requestPermission();
  Future<MapCoordinates> currentPosition();
}

/// Requests location only when explicitly called by the map's location action.
class MapLocationService {
  const MapLocationService(this._gateway);

  final DeviceLocationGateway _gateway;

  Future<MapLocationResult> locate() async {
    try {
      if (!await _gateway.isLocationEnabled()) {
        return const MapLocationResult.failure(MapLocationIssue.serviceOff);
      }

      var permission = await _gateway.checkPermission();
      if (permission == DeviceLocationPermission.denied) {
        permission = await _gateway.requestPermission();
      }
      if (permission == DeviceLocationPermission.denied) {
        return const MapLocationResult.failure(
          MapLocationIssue.permissionDenied,
        );
      }
      if (permission == DeviceLocationPermission.deniedForever) {
        return const MapLocationResult.failure(
          MapLocationIssue.permissionDeniedForever,
        );
      }

      return MapLocationResult.success(await _gateway.currentPosition());
    } catch (_) {
      // Never include location or platform exception details in logs or UI.
      return const MapLocationResult.failure(MapLocationIssue.unavailable);
    }
  }
}

class GeolocatorDeviceLocationGateway implements DeviceLocationGateway {
  @override
  Future<bool> isLocationEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<DeviceLocationPermission> checkPermission() async =>
      _mapPermission(await Geolocator.checkPermission());

  @override
  Future<DeviceLocationPermission> requestPermission() async =>
      _mapPermission(await Geolocator.requestPermission());

  @override
  Future<MapCoordinates> currentPosition() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
    return MapCoordinates(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  DeviceLocationPermission _mapPermission(LocationPermission permission) =>
      switch (permission) {
        LocationPermission.always ||
        LocationPermission.whileInUse => DeviceLocationPermission.granted,
        LocationPermission.deniedForever =>
          DeviceLocationPermission.deniedForever,
        _ => DeviceLocationPermission.denied,
      };
}
