import 'package:material_ui/material_ui.dart';

import '../../domain/models.dart';
import '../../l10n/l10n.dart';
import '../theme.dart';
import 'vehicle_part_map.dart';

/// Interactive vehicle: drag to orbit, tap a part to select it.
///
/// The vehicle is a photoreal turntable rendered in Blender, one per
/// [VehicleType]; [VehiclePartMap] tells which part is under the pointer.
/// Damaged parts are tinted (amber = cosmetic, bad = broken/missing).
class VehicleViewer extends StatefulWidget {
  const VehicleViewer({
    super.key,
    required this.type,
    required this.damages,
    this.onPartTap,
    this.height = 280,
  });

  final VehicleType type;
  final Map<CarPart, DamageMark> damages;
  final ValueChanged<CarPart>? onPartTap;
  final double height;

  @override
  State<VehicleViewer> createState() => _VehicleViewerState();
}

/// Camera presets; [angle] is the orbit position in degrees (null = plan).
enum _View {
  threeQuarter('3/4', -40),
  front('Front', 0),
  left('Left', 90),
  right('Right', -90),
  rear('Rear', 180),
  top('Top', null);

  const _View(this.label, this.angle);

  final String label;
  final double? angle;
}

class _VehicleViewerState extends State<VehicleViewer>
    with SingleTickerProviderStateMixin {
  static const _aspect = 800 / 420;
  static const _degreesPerFrame = 360 / VehiclePartMap.ringFrames;
  static const _degreesPerPixel = 0.55;

  double _angle = _View.threeQuarter.angle!;
  bool _top = false;
  CarPart? _hover;
  VehiclePartMap? _map;
  bool _precached = false;

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  Animation<double>? _tween;

  int get _frame {
    if (_top) return VehiclePartMap.topFrame;
    final k = (_angle / _degreesPerFrame).round() % VehiclePartMap.ringFrames;
    return k < 0 ? k + VehiclePartMap.ringFrames : k;
  }

  @override
  void initState() {
    super.initState();
    _anim.addListener(() => setState(() => _angle = _tween!.value));
    _loadMap();
  }

  void _loadMap() {
    final type = widget.type;
    _map = VehiclePartMap.cached(type);
    if (_map != null) return;
    VehiclePartMap.load(type).then((map) {
      if (mounted && widget.type == type) setState(() => _map = map);
    });
  }

  // Decode the whole orbit up front so dragging never shows a blank frame.
  void _precache() {
    for (var f = 0; f <= VehiclePartMap.topFrame; f++) {
      precacheImage(
        AssetImage(VehiclePartMap.frameAsset(widget.type, f)),
        context,
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    _precache();
  }

  @override
  void didUpdateWidget(VehicleViewer old) {
    super.didUpdateWidget(old);
    if (VehiclePartMap.assetDir(old.type) ==
        VehiclePartMap.assetDir(widget.type)) {
      return;
    }
    _hover = null;
    _loadMap();
    _precache();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _goTo(_View view) {
    final angle = view.angle;
    _anim.stop();
    if (angle == null) {
      setState(() => _top = true);
      return;
    }
    if (_top) {
      setState(() {
        _top = false;
        _angle = angle;
      });
      return;
    }
    // Orbit the short way round.
    var target = angle;
    while (target - _angle > 180) {
      target -= 360;
    }
    while (target - _angle < -180) {
      target += 360;
    }
    _tween = Tween(
      begin: _angle,
      end: target,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOutCubic));
    _anim.forward(from: 0);
  }

  Rect _imageRect(Size size) {
    var w = size.width, h = w / _aspect;
    if (h > size.height) {
      h = size.height;
      w = h * _aspect;
    }
    return Rect.fromCenter(
      center: size.center(Offset.zero),
      width: w,
      height: h,
    );
  }

  CarPart? _partAt(Rect rect, Offset p) => _map?.partAt(
    _frame,
    (p.dx - rect.left) / rect.width,
    (p.dy - rect.top) / rect.height,
  );

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.ofContext(context);
    final readOnly = widget.onPartTap == null;
    final frame = _frame;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, c) {
              final rect = _imageRect(Size(c.maxWidth, widget.height));
              return MouseRegion(
                cursor: _hover != null && !readOnly
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.grab,
                onHover: (e) {
                  final part = _partAt(rect, e.localPosition);
                  if (part != _hover) setState(() => _hover = part);
                },
                onExit: (_) => setState(() => _hover = null),
                child: GestureDetector(
                  key: const Key('vehicle-viewer'),
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (d) => setState(() {
                    _anim.stop();
                    _top = false;
                    // The near side of the car follows the finger.
                    _angle -= d.delta.dx * _degreesPerPixel;
                  }),
                  onTapUp: readOnly
                      ? null
                      : (d) {
                          final part = _partAt(rect, d.localPosition);
                          if (part != null) widget.onPartTap!(part);
                        },
                  child: Stack(
                    children: [
                      Positioned.fromRect(
                        rect: rect,
                        child: Image.asset(
                          VehiclePartMap.frameAsset(widget.type, frame),
                          fit: BoxFit.fill,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.medium,
                          excludeFromSemantics: true,
                        ),
                      ),
                      if (_map case final map?)
                        Positioned.fromRect(
                          rect: rect,
                          child: CustomPaint(
                            painter: _DamagePainter(
                              map: map,
                              frame: frame,
                              damages: Map.of(widget.damages),
                              hover: readOnly ? null : _hover,
                              palette: palette,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(
          height: 22,
          child: Center(
            child: Text(
              context.t(
                _hover?.label ??
                    (readOnly
                        ? 'Drag to rotate'
                        : 'Drag to rotate · tap a part to record damage'),
              ),
              style: TextStyle(fontSize: 12, color: palette.muted),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final v in _View.values)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ActionChip(
                    label: Text(context.t(v.label)),
                    onPressed: () => _goTo(v),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tints the damaged and hovered parts over the current frame.
class _DamagePainter extends CustomPainter {
  _DamagePainter({
    required this.map,
    required this.frame,
    required this.damages,
    required this.hover,
    required this.palette,
  });

  final VehiclePartMap map;
  final int frame;
  final Map<CarPart, DamageMark> damages;
  final CarPart? hover;
  final AppPalette palette;

  static const _cosmetic = 0, _severe = 1, _hover = 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (damages.isEmpty && hover == null) return;
    final paths = map.regions(frame, 3, (part) {
      if (part == hover) return _hover;
      final damage = damages[part];
      if (damage == null) return null;
      return damage.type.severe ? _severe : _cosmetic;
    });
    canvas.save();
    canvas.scale(size.width / map.width, size.height / map.height);
    final hovered = hover == null ? null : damages[hover];
    final colors = [
      palette.amber,
      palette.bad,
      switch (hovered) {
        null => palette.accent,
        final d => d.type.severe ? palette.bad : palette.amber,
      },
    ];
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.45);
    for (var g = 0; g < paths.length; g++) {
      final strong = g != _hover || hovered != null;
      // Recolour the paint keeping the render's shading and reflections,
      // then a light wash so dark trim and glass show the tint too.
      canvas.drawPath(
        paths[g],
        paint
          ..blendMode = BlendMode.color
          ..color = colors[g].withValues(alpha: strong ? 0.95 : 0.6),
      );
      canvas.drawPath(
        paths[g],
        paint
          ..blendMode = BlendMode.srcOver
          ..color = colors[g].withValues(alpha: strong ? 0.3 : 0.16),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DamagePainter old) =>
      old.map != map ||
      old.frame != frame ||
      old.hover != hover ||
      old.palette != palette ||
      !_sameDamages(old.damages, damages);

  static bool _sameDamages(
    Map<CarPart, DamageMark> a,
    Map<CarPart, DamageMark> b,
  ) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key]?.type != e.value.type) return false;
    }
    return true;
  }
}
