import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/game_state.dart';
import '../theme.dart';

class GalaxyMapScreen extends StatefulWidget {
  const GalaxyMapScreen({super.key});

  @override
  State<GalaxyMapScreen> createState() => _GalaxyMapScreenState();
}

class _GalaxyMapScreenState extends State<GalaxyMapScreen> {
  int? _selected;
  final _transform = TransformationController();

  @override
  Widget build(BuildContext context) {
    final gs = context.watch<GameState>();
    if (gs.galaxySectors.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final adjacent = gs.warpsOut.toSet();
    final currentId = gs.sector?.id;

    var minX = 0, minY = 0, maxX = 0, maxY = 0;
    for (final s in gs.galaxySectors) {
      if (s.x < minX) minX = s.x;
      if (s.y < minY) minY = s.y;
      if (s.x > maxX) maxX = s.x;
      if (s.y > maxY) maxY = s.y;
    }
    const pad = 200.0;
    final offsetX = -minX + pad;
    final offsetY = -minY + pad;
    final canvasW = (maxX - minX) + pad * 2;
    final canvasH = (maxY - minY) + pad * 2;

    return Stack(
      children: [
        InteractiveViewer(
          transformationController: _transform,
          minScale: 0.1,
          maxScale: 4,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(400),
          child: SizedBox(
            width: canvasW,
            height: canvasH,
            child: GestureDetector(
              onTapUp: (details) => _handleTap(details, gs, offsetX, offsetY),
              child: CustomPaint(
                painter: _GalaxyPainter(
                  sectors: gs.galaxySectors,
                  warps: gs.galaxyWarps,
                  currentId: currentId,
                  adjacent: adjacent,
                  selected: _selected,
                  offsetX: offsetX,
                  offsetY: offsetY,
                ),
                size: Size(canvasW, canvasH),
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          top: 12,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Galaxy Map', style: TextStyle(fontWeight: FontWeight.bold, color: TWColors.accent)),
                  Text('${gs.galaxySectors.length} sectors charted', style: const TextStyle(color: TWColors.textDim, fontSize: 12)),
                  const SizedBox(height: 6),
                  _legendDot(TWColors.accent2, 'Your ship'),
                  _legendDot(TWColors.accent, 'Reachable this turn'),
                  _legendDot(TWColors.warning, 'Federation / Stardock'),
                  _legendDot(TWColors.textDim, 'Deep space'),
                ],
              ),
            ),
          ),
        ),
        if (_selected != null)
          Positioned(
            right: 12,
            top: 12,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Sector $_selected', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (adjacent.contains(_selected))
                      ElevatedButton(
                        onPressed: () async {
                          final err = await gs.moveTo(_selected!);
                          if (err != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                          } else {
                            setState(() => _selected = null);
                          }
                        },
                        child: const Text('Warp here'),
                      )
                    else
                      const Text('Not adjacent — plot a course through\nconnected sectors first.',
                          style: TextStyle(color: TWColors.textDim, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _legendDot(Color c, String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );

  void _handleTap(TapUpDetails details, GameState gs, double offsetX, double offsetY) {
    final pos = details.localPosition;
    SectorInfo? closest;
    double bestDist = double.infinity;
    for (final s in gs.galaxySectors) {
      final dx = s.x.toDouble() + offsetX - pos.dx;
      final dy = s.y.toDouble() + offsetY - pos.dy;
      final dist = dx * dx + dy * dy;
      if (dist < bestDist) {
        bestDist = dist;
        closest = s;
      }
    }
    if (closest != null && bestDist < 400) {
      setState(() => _selected = closest!.id);
    }
  }
}

class _GalaxyPainter extends CustomPainter {
  final List<SectorInfo> sectors;
  final List<Warp> warps;
  final int? currentId;
  final Set<int> adjacent;
  final int? selected;
  final double offsetX;
  final double offsetY;

  _GalaxyPainter({
    required this.sectors,
    required this.warps,
    required this.currentId,
    required this.adjacent,
    required this.selected,
    required this.offsetX,
    required this.offsetY,
  });

  Offset _pos(int x, int y) => Offset(x.toDouble() + offsetX, y.toDouble() + offsetY);

  @override
  void paint(Canvas canvas, Size size) {
    final byId = {for (final s in sectors) s.id: s};

    final linePaint = Paint()
      ..color = TWColors.border.withValues(alpha: 0.5)
      ..strokeWidth = 1;

    for (final w in warps) {
      final a = byId[w.from];
      final b = byId[w.to];
      if (a == null || b == null) continue;
      canvas.drawLine(_pos(a.x, a.y), _pos(b.x, b.y), linePaint);
    }

    for (final s in sectors) {
      final center = _pos(s.x, s.y);
      Color color = TWColors.textDim;
      double radius = 5;
      if (s.isFederation) {
        color = TWColors.warning;
        radius = 9;
      } else if (s.hasPort) {
        color = TWColors.accent;
        radius = 6;
      }
      if (adjacent.contains(s.id)) {
        color = TWColors.accent;
      }
      if (s.id == currentId) {
        color = TWColors.accent2;
        radius = 10;
      }
      if (s.id == selected) {
        canvas.drawCircle(center, radius + 6, Paint()..color = Colors.white.withValues(alpha: 0.15));
      }
      canvas.drawCircle(center, radius, Paint()..color = color);
      if (s.id == currentId) {
        canvas.drawCircle(
            center, radius + 3, Paint()..color = TWColors.accent2..style = PaintingStyle.stroke..strokeWidth = 2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GalaxyPainter oldDelegate) =>
      oldDelegate.currentId != currentId || oldDelegate.selected != selected || oldDelegate.sectors.length != sectors.length;
}
