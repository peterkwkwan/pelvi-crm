import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Full-screen quiet empty state — pink.950 title, muted body, optional CTA.
class QuietEmptyState extends StatelessWidget {
  const QuietEmptyState({
    super.key,
    required this.title,
    required this.body,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final String body;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PelviSpace.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 270),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: PelviColors.pink950,
                      fontSize: 28,
                      height: 34 / 28,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: PelviSpace.md),
              Text(
                body,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: PelviColors.inkMuted,
                    ),
              ),
              if (primaryLabel != null && onPrimary != null) ...[
                const SizedBox(height: PelviSpace.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onPrimary,
                    child: Text(primaryLabel!),
                  ),
                ),
              ],
              if (secondaryLabel != null && onSecondary != null) ...[
                const SizedBox(height: PelviSpace.sm),
                TextButton(
                  onPressed: onSecondary,
                  style: TextButton.styleFrom(
                    foregroundColor: PelviColors.pink700,
                  ),
                  child: Text(secondaryLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Dashed empty well for list regions (“No clients yet”, etc.).
class DashedEmptyWell extends StatelessWidget {
  const DashedEmptyWell({
    super.key,
    required this.message,
    this.ctaLabel,
    this.onCta,
  });

  final String message;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: PelviColors.border,
        radius: PelviRadius.lg,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: PelviSpace.lg,
          vertical: PelviSpace.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: PelviColors.pink50,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add,
                color: PelviColors.pink700,
                size: 22,
              ),
            ),
            const SizedBox(height: PelviSpace.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: PelviColors.inkMuted,
                  ),
            ),
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: PelviSpace.sm),
              TextButton(
                onPressed: onCta,
                style: TextButton.styleFrom(
                  foregroundColor: PelviColors.pink700,
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: PelviColors.pink700,
                        fontSize: 13,
                      ),
                ),
                child: Text(ctaLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final dashed = _dashPath(path, dashLength: 6, gapLength: 4);
    canvas.drawPath(dashed, paint);
  }

  Path _dashPath(Path source, {required double dashLength, required double gapLength}) {
    final metrics = source.computeMetrics();
    final out = Path();
    for (final metric in metrics) {
      var distance = 0.0;
      var draw = true;
      while (distance < metric.length) {
        final len = draw ? dashLength : gapLength;
        final next = distance + len;
        if (draw) {
          out.addPath(
            metric.extractPath(distance, next.clamp(0, metric.length)),
            Offset.zero,
          );
        }
        distance = next;
        draw = !draw;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
