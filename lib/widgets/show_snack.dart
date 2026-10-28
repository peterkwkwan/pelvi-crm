import 'package:flutter/material.dart';

/// SnackBar anchored just below the app bar (floating + top margin).
void showPelviSnackBar(BuildContext context, String message) {
  final media = MediaQuery.of(context);
  final top = media.padding.top + kToolbarHeight + 8;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        top: top,
        bottom: media.size.height - top - 56,
      ),
    ),
  );
}
