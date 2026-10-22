import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'map_location.dart';
import 'map_providers.dart';

const _startArea = LatLng(0, 0);
const _startZoom = 1.7;
const _mapLoadTimeout = Duration(seconds: 25);

final mapStyleProvider = Provider<MapStyleProvider>(
  (ref) => const OpenFreeMapStyleProvider(),
);

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  MapLibreMapController? _mapController;
  Timer? _loadTimer;
  bool _loaded = false;
  bool _loadFailed = false;
  bool _locating = false;
  int _mapGeneration = 0;

  @override
  void initState() {
    super.initState();
    _startLoadTimer();
  }

  @override
  void dispose() {
    _loadTimer?.cancel();
    super.dispose();
  }

  void _startLoadTimer() {
    _loadTimer?.cancel();
    _loadTimer = Timer(_mapLoadTimeout, () {
      if (!mounted || _loaded) return;
      setState(() => _loadFailed = true);
    });
  }

  void _onStyleLoaded() {
    _loadTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _loaded = true;
      _loadFailed = false;
    });
  }

  void _retry() {
    setState(() {
      _loaded = false;
      _loadFailed = false;
      _mapController = null;
      _mapGeneration++;
    });
    _startLoadTimer();
  }

  Future<void> _returnToStart() async {
    final controller = _mapController;
    if (controller == null) return;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(_startArea, _startZoom),
    );
  }

  Future<void> _locateMe() async {
    final shouldContinue = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Перейти к вашему местоположению?'),
        content: const Text(
          'Разрешение нужно только для перемещения карты к вам. Social World '
          'не отправляет координаты на свой сервер. Сервис карт может '
          'получать запросы тайлов для видимой области.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Не сейчас'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
    if (shouldContinue != true || !mounted) return;

    setState(() => _locating = true);
    final result = await ref.read(mapLocationServiceProvider).locate();
    if (!mounted) return;
    setState(() => _locating = false);

    if (result.coordinates case final coordinates?) {
      final controller = _mapController;
      if (controller != null) {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(coordinates.latitude, coordinates.longitude),
            14,
          ),
        );
      }
      return;
    }

    _showLocationIssue(result.issue ?? MapLocationIssue.unavailable);
  }

  void _showLocationIssue(MapLocationIssue issue) {
    final message = switch (issue) {
      MapLocationIssue.permissionDenied =>
        'Доступ к местоположению не разрешён. Можно продолжать пользоваться картой.',
      MapLocationIssue.permissionDeniedForever =>
        'Доступ запрещён в настройках устройства. Его можно включить в настройках приложения.',
      MapLocationIssue.serviceOff =>
        'Службы геолокации выключены. Включите их в настройках устройства и повторите попытку.',
      MapLocationIssue.unavailable =>
        'Не удалось определить местоположение. Попробуйте ещё раз.',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: issue == MapLocationIssue.permissionDeniedForever
            ? const SnackBarAction(
                label: 'Настройки',
                onPressed: Geolocator.openAppSettings,
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = ref.watch(mapStyleProvider).styleUri.toString();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Карта'),
        leading: IconButton(
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Назад',
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: MapLibreMap(
              key: ValueKey(_mapGeneration),
              styleString: style,
              initialCameraPosition: const CameraPosition(
                target: _startArea,
                zoom: _startZoom,
              ),
              onMapCreated: (controller) => _mapController = controller,
              onStyleLoadedCallback: _onStyleLoaded,
              compassEnabled: true,
              rotateGesturesEnabled: true,
              scrollGesturesEnabled: true,
              zoomGesturesEnabled: true,
              attributionButtonPosition: AttributionButtonPosition.topLeft,
            ),
          ),
          if (!_loaded && !_loadFailed)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0xA6F6F5F2),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 14),
                      Text('Загружаем карту…'),
                    ],
                  ),
                ),
              ),
            ),
          if (_loadFailed)
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0xFFF6F5F2),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.map_outlined, size: 42),
                        const SizedBox(height: 12),
                        const Text(
                          'Не удалось загрузить карту',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Проверьте подключение к интернету и попробуйте снова.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _retry,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 16,
            top: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'map-start',
                  onPressed: _mapController == null ? null : _returnToStart,
                  tooltip: 'Вернуться к стартовой области',
                  child: const Icon(Icons.public),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'map-location',
                  onPressed: _locating ? null : _locateMe,
                  tooltip: 'Моё местоположение',
                  child: _locating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
          Positioned(
            left: 12,
            bottom: 12,
            child: Material(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                child: InkWell(
                  onTap: () => launchUrl(
                    Uri.parse('https://www.openstreetmap.org/copyright'),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text(
                    '© OpenStreetMap contributors',
                    style: TextStyle(fontSize: 11, color: Color(0xFF34323D)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
