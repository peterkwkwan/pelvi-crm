import 'dart:math' as math;

import 'package:flutter/material.dart';

/// SnackBar anchored just below the app bar (floating + top margin).
void showPelviSnackBar(BuildContext context, String message) {
  final media = MediaQuery.of(context);
  final theme = Theme.of(context);
  final top = media.padding.top + kToolbarHeight + 8;
  const side = 16.0;
  // Match SnackBar content inset so measured wrap matches on-screen wrap.
  const contentInset = 16.0;
  final style = theme.snackBarTheme.contentTextStyle ??
      theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onInverseSurface,
      );
  final painter = TextPainter(
    text: TextSpan(text: message, style: style),
    textDirection: Directionality.of(context),
    textScaler: media.textScaler,
  )..layout(maxWidth: media.size.width - side * 2 - contentInset * 2);
  // Floating snack is bottom-aligned in the margin slot — slot ≈ bar height
  // keeps the top edge under the app bar as content wraps.
  final barHeight = math.max(48.0, painter.height + contentInset * 2);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, softWrap: true),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(
        left: side,
        right: side,
        top: top,
        bottom: media.size.height - top - barHeight,
      ),
    ),
  );
}
