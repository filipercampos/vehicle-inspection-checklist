import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';

/// Dependency-free signature capture. Strokes are stored normalized (0..1)
/// so they render identically at any size (form vs. report).
class SignaturePad extends StatefulWidget {
  const SignaturePad({
    super.key,
    required this.strokes,
    required this.onChanged,
    this.height = 160,
  });

  final List<List<Offset>> strokes;
  final ValueChanged<List<List<Offset>>> onChanged;
  final double height;

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  late List<List<Offset>> _strokes = [...widget.strokes];

  Offset _normalize(Offset p, Size size) =>
      Offset((p.dx / size.width).clamp(0, 1), (p.dy / size.height).clamp(0, 1));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, widget.height);
            return GestureDetector(
              key: const Key('signature-pad'),
              onPanStart: (d) => setState(
                () => _strokes = [
                  ..._strokes,
                  [_normalize(d.localPosition, size)],
                ],
              ),
              onPanUpdate: (d) => setState(() {
                _strokes.last = [
                  ..._strokes.last,
                  _normalize(d.localPosition, size),
                ];
              }),
              onPanEnd: (_) => widget.onChanged(_strokes),
              child: Container(
                height: widget.height,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Stack(
                  children: [
                    if (_strokes.isEmpty)
                      Center(
                        child: Text(
                          context.t('Sign here'),
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: SignaturePainter(_strokes, scheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _strokes.isEmpty
                ? null
                : () {
                    setState(() => _strokes = []);
                    widget.onChanged(const []);
                  },
            icon: const Icon(Icons.clear, size: 18),
            label: Text(context.t('Clear')),
          ),
        ),
      ],
    );
  }
}

class SignaturePainter extends CustomPainter {
  SignaturePainter(this.strokes, this.color);

  final List<List<Offset>> strokes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()
        ..moveTo(stroke.first.dx * size.width, stroke.first.dy * size.height);
      for (final p in stroke.skip(1)) {
        path.lineTo(p.dx * size.width, p.dy * size.height);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(SignaturePainter old) =>
      old.strokes != strokes || old.color != color;
}
