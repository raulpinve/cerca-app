import 'package:app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng, Distance, LengthUnit;

class LocationPoint {
  final double latitude;
  final double longitude;
  final double? accuracyM;
  final DateTime recordedAt;

  const LocationPoint({
    required this.latitude,
    required this.longitude,
    this.accuracyM,
    required this.recordedAt,
  });

  LatLng get position => LatLng(latitude, longitude);

  factory LocationPoint.fromJson(Map<String, dynamic> json) {
    return LocationPoint(
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      accuracyM: json['accuracy_m'] == null
          ? null
          : double.parse(json['accuracy_m'].toString()),
      recordedAt: DateTime.parse(json['recorded_at'].toString()),
    );
  }
}

/// Un tramo inferido: "se quedó quieto" o "se estaba moviendo".
/// Se calcula en el cliente a partir de los puntos crudos — tu backend
/// no tiene este concepto, así que no confundir con una tabla real.
class LocationSegment {
  final bool isStop; // true = quieto, false = en movimiento
  final DateTime startTime;
  final DateTime endTime;
  final double distanceKm; // solo tiene sentido si !isStop

  const LocationSegment({
    required this.isStop,
    required this.startTime,
    required this.endTime,
    this.distanceKm = 0,
  });
}

/// Agrupa puntos consecutivos en tramos de "quieto" / "en movimiento",
/// comparando la distancia entre puntos consecutivos contra un umbral.
///
/// [points] debe venir ordenado de más viejo a más nuevo.
/// [stopRadiusMeters]: si dos puntos consecutivos están más cerca que esto,
/// se consideran "el mismo lugar" (quieto). Ajustalo según qué tan seguido
/// registrás la ubicación — con GPS de celular, 60-100m es razonable.
List<LocationSegment> buildSegments(
  List<LocationPoint> points, {
  double stopRadiusMeters = 80,
}) {
  if (points.length < 2) {
    if (points.isEmpty) return [];
    return [
      LocationSegment(
        isStop: true,
        startTime: points.first.recordedAt,
        endTime: points.first.recordedAt,
      ),
    ];
  }

  const distanceCalculator = Distance();
  final segments = <LocationSegment>[];

  bool currentIsStop =
      distanceCalculator.as(
        LengthUnit.Meter,
        points[0].position,
        points[1].position,
      ) <=
      stopRadiusMeters;
  DateTime segmentStart = points[0].recordedAt;
  double segmentDistanceM = 0;

  for (var i = 1; i < points.length; i++) {
    final d = distanceCalculator.as(
      LengthUnit.Meter,
      points[i - 1].position,
      points[i].position,
    );
    final isStop = d <= stopRadiusMeters;

    if (isStop == currentIsStop) {
      segmentDistanceM += d;
      continue;
    }

    // Cambió el tipo de tramo: cerramos el anterior y arrancamos uno nuevo.
    segments.add(
      LocationSegment(
        isStop: currentIsStop,
        startTime: segmentStart,
        endTime: points[i - 1].recordedAt,
        distanceKm: segmentDistanceM / 1000,
      ),
    );

    currentIsStop = isStop;
    segmentStart = points[i - 1].recordedAt;
    segmentDistanceM = d;
  }

  segments.add(
    LocationSegment(
      isStop: currentIsStop,
      startTime: segmentStart,
      endTime: points.last.recordedAt,
      distanceKm: segmentDistanceM / 1000,
    ),
  );

  return segments;
}

double totalDistanceKm(List<LocationPoint> points) {
  if (points.length < 2) return 0;
  const distanceCalculator = Distance();
  double totalM = 0;
  for (var i = 1; i < points.length; i++) {
    totalM += distanceCalculator.as(
      LengthUnit.Meter,
      points[i - 1].position,
      points[i].position,
    );
  }
  return totalM / 1000;
}

// ---------------------------------------------------------------------------
// PANTALLA
// ---------------------------------------------------------------------------

class LocationHistoryPage extends StatefulWidget {
  final String memberName;
  final String initials;
  final Color color;
  final String cartoApiKey;

  /// Puntos crudos, ordenados de más viejo a más nuevo.
  /// Si tu API los devuelve DESC (como getDeviceLocationHistory), invertí
  /// la lista antes de pasarla acá: points.reversed.toList()
  final List<LocationPoint> points;

  const LocationHistoryPage({
    super.key,
    required this.memberName,
    required this.initials,
    required this.color,
    required this.points,
    required this.cartoApiKey,
  });

  @override
  State<LocationHistoryPage> createState() => _LocationHistoryPageState();
}

class _LocationHistoryPageState extends State<LocationHistoryPage> {
  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final segments = buildSegments(widget.points);
    final distance = totalDistanceKm(widget.points);

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                memberName: widget.memberName,
                initials: widget.initials,
                color: widget.color,
              ),
              const SizedBox(height: 14),
              if (widget.points.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      'Todavía no hay ubicaciones registradas',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ),
                )
              else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 160,
                    child: _MiniTrailMap(
                      points: widget.points,
                      color: widget.color,
                      cartoApiKey: widget.cartoApiKey,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${distance.toStringAsFixed(1)} km recorridos · ${widget.points.length} puntos registrados',
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView.builder(
                    itemCount: segments.length,
                    itemBuilder: (context, index) {
                      final segment = segments[index];
                      final isLast = index == segments.length - 1;
                      return _SegmentTile(
                        segment: segment,
                        color: widget.color,
                        isLast: isLast,
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HEADER
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final String memberName;
  final String initials;
  final Color color;

  const _Header({
    required this.memberName,
    required this.initials,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).pop(),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.arrow_back, size: 20, color: colors.unselected),
          ),
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          radius: 18,
          backgroundColor: color,
          child: Text(
            initials,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              memberName,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
            ),
            Text(
              'Historial de ubicaciones',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// MINI MAPA CON EL RECORRIDO
// ---------------------------------------------------------------------------

class _MiniTrailMap extends StatelessWidget {
  final List<LocationPoint> points;
  final Color color;
  final String cartoApiKey;

  const _MiniTrailMap({
    required this.points,
    required this.color,
    required this.cartoApiKey,
  });

  @override
  Widget build(BuildContext context) {
    final trail = points.map((p) => p.position).toList();
    final uniquePoints = trail
        .toSet()
        .length; // cuántas posiciones distintas hay

    return FlutterMap(
      options: MapOptions(
        // Si solo hay 1 posición única, usa centro+zoom fijo en vez de CameraFit
        initialCenter: uniquePoints <= 1 ? trail.first : const LatLng(0, 0),
        initialZoom: uniquePoints <= 1 ? 15 : 13,
        initialCameraFit: uniquePoints > 1
            ? CameraFit.coordinates(
                coordinates: trail,
                padding: const EdgeInsets.all(24),
              )
            : null,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      children: [
        ColorFiltered(
          colorFilter: const ColorFilter.mode(
            Color(0x06B5673A),
            BlendMode.srcATop,
          ),
          child: TileLayer(
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png?key=$cartoApiKey',
            subdomains: const ['a', 'b', 'c', 'd'],
            userAgentPackageName: 'com.tuapp.cerca',
          ),
        ),
        if (trail.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: trail,
                strokeWidth: 3,
                color: color,
                pattern: const StrokePattern.dotted(),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: trail.first,
              width: 16,
              height: 16,
              child: const _TrailDot(color: Color(0xFF8FAE7C)),
            ),
            Marker(
              point: trail.last,
              width: 16,
              height: 16,
              child: const _TrailDot(color: Color(0xFFE9A0A0)),
            ),
          ],
        ),
      ],
    );
  }
}

class _TrailDot extends StatelessWidget {
  final Color color;
  const _TrailDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FILA DE TRAMO EN LA LÍNEA DE TIEMPO
// ---------------------------------------------------------------------------

class _SegmentTile extends StatelessWidget {
  final LocationSegment segment;
  final Color color;
  final bool isLast;

  const _SegmentTile({
    required this.segment,
    required this.color,
    required this.isLast,
  });

  String _formatTimeRange() {
    return '${_formatTime(segment.startTime)} – ${_formatTime(segment.endTime)}';
  }

  String _formatTime(DateTime t) {
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.hour < 12 ? 'a. m.' : 'p. m.';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              const SizedBox(height: 4),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: segment.isStop ? color : colors.unselected,
                ),
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: colors.border)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatTimeRange(),
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    segment.isStop ? 'Se quedó en un lugar' : 'En movimiento',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                  ),
                  if (!segment.isStop)
                    Text(
                      '${segment.distanceKm.toStringAsFixed(1)} km',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
