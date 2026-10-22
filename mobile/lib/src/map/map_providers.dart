const _defaultMapStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';

abstract interface class MapStyleProvider {
  Uri get styleUri;
}

class OpenFreeMapStyleProvider implements MapStyleProvider {
  const OpenFreeMapStyleProvider({String? styleUrl})
    : _styleUrl = styleUrl ?? const String.fromEnvironment('MAP_STYLE_URL');

  final String _styleUrl;

  @override
  Uri get styleUri =>
      Uri.parse(_styleUrl.isEmpty ? _defaultMapStyleUrl : _styleUrl);
}

/// A provider port for real place data; no fake or network implementation is
/// bundled with the map foundation.
abstract interface class MapPlacesSource {
  Future<List<MapPlace>> loadWithin(MapViewport viewport);
}

class MapViewport {
  const MapViewport({
    required this.west,
    required this.south,
    required this.east,
    required this.north,
  });

  final double west;
  final double south;
  final double east;
  final double north;
}

class MapPlace {
  const MapPlace({
    required this.providerId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.category,
  });

  final String providerId;
  final String name;
  final double latitude;
  final double longitude;
  final String category;
}
