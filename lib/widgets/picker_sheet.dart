import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// One row in [showPelviPickerSheet].
class PelviPickerOption<T> {
  const PelviPickerOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.searchText,
    this.labelColor,
    this.subtitleColor,
  });

  final T value;
  final String label;
  final String? subtitle;

  /// Lowercased haystack for search (defaults to [label] + [subtitle]).
  final String? searchText;

  /// Optional tint for [label] / [subtitle] (e.g. appointment status words).
  final Color? labelColor;
  final Color? subtitleColor;
}

/// Full-height paper-white sheet with hairline rows and optional search.
Future<T?> showPelviPickerSheet<T>({
  required BuildContext context,
  required String title,
  required List<PelviPickerOption<T>> options,
  T? selected,
  bool searchable = false,
  String searchHint = 'Search',
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: PelviColors.surface,
    barrierColor: PelviColors.overlay,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(PelviRadius.lg)),
    ),
    builder: (context) {
      return _PelviPickerSheet<T>(
        title: title,
        options: options,
        selected: selected,
        searchable: searchable,
        searchHint: searchHint,
      );
    },
  );
}

class _PelviPickerSheet<T> extends StatefulWidget {
  const _PelviPickerSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.searchable,
    required this.searchHint,
  });

  final String title;
  final List<PelviPickerOption<T>> options;
  final T? selected;
  final bool searchable;
  final String searchHint;

  @override
  State<_PelviPickerSheet<T>> createState() => _PelviPickerSheetState<T>();
}

class _PelviPickerSheetState<T> extends State<_PelviPickerSheet<T>> {
  String _query = '';

  List<PelviPickerOption<T>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return widget.options.where((o) {
      final hay =
          (o.searchText ?? '${o.label} ${o.subtitle ?? ''}').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final height = MediaQuery.sizeOf(context).height * 0.92;
    final filtered = _filtered;

    return SizedBox(
      height: height,
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: PelviSpace.sm),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: PelviColors.border,
                  borderRadius: BorderRadius.circular(PelviRadius.full),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PelviSpace.md,
                PelviSpace.md,
                PelviSpace.sm,
                PelviSpace.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.title, style: text.titleLarge),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: PelviColors.inkMuted),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: PelviColors.chromeBorder),
            if (widget.searchable) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  PelviSpace.md,
                  PelviSpace.md,
                  PelviSpace.md,
                  PelviSpace.sm,
                ),
                child: TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: widget.searchHint,
                    prefixIcon: const Icon(
                      Icons.search,
                      color: PelviColors.inkMuted,
                    ),
                    filled: true,
                    fillColor: PelviColors.surfaceMuted,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(PelviRadius.md),
                      borderSide: const BorderSide(color: PelviColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(PelviRadius.md),
                      borderSide: const BorderSide(color: PelviColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(PelviRadius.md),
                      borderSide: const BorderSide(
                        color: PelviColors.pink700,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        _query.trim().isEmpty ? 'Nothing here yet.' : 'No matches.',
                        style: text.bodyMedium?.copyWith(
                          color: PelviColors.inkMuted,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final o = filtered[i];
                        final isSelected = o.value == widget.selected;
                        return InkWell(
                          onTap: () => Navigator.of(context).pop(o.value),
                          splashColor: PelviColors.surfaceMuted,
                          highlightColor: PelviColors.surfaceMuted,
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 56),
                            padding: const EdgeInsets.symmetric(
                              horizontal: PelviSpace.md,
                              vertical: PelviSpace.sm + 4,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? PelviColors.pink50
                                  : PelviColors.surface,
                              border: isSelected
                                  ? const Border(
                                      bottom: BorderSide(
                                        color: PelviColors.pink200,
                                      ),
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        o.label,
                                        style: text.labelLarge?.copyWith(
                                          color: o.labelColor ??
                                              (isSelected
                                                  ? PelviColors.pink700
                                                  : PelviColors.ink),
                                        ),
                                      ),
                                      if (o.subtitle != null &&
                                          o.subtitle!.isNotEmpty)
                                        Text(
                                          o.subtitle!,
                                          style: text.labelMedium?.copyWith(
                                            color: o.subtitleColor,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check,
                                    color: PelviColors.pink700,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
