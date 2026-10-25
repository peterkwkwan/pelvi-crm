import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import '../calendar/calendar_screen.dart';
import '../clients/clients_screen.dart';
import '../more/more_screen.dart';
import '../today/today_screen.dart';
import 'quick_add_sheet.dart';

/// Root chrome: Today · Calendar · Clients · More + center-docked FAB.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _pages = <Widget>[
    TodayScreen(),
    CalendarScreen(),
    ClientsScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      floatingActionButton: _CenterFab(
        onPressed: () => showQuickAddSheet(context),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _PelviBottomBar(
        index: _index,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _CenterFab extends StatelessWidget {
  const _CenterFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: FloatingActionButton(
        onPressed: onPressed,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        backgroundColor: PelviColors.pink700,
        foregroundColor: PelviColors.inkInverse,
        shape: const CircleBorder(
          side: BorderSide(color: PelviColors.canvas, width: 3),
        ),
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }
}

class _PelviBottomBar extends StatelessWidget {
  const _PelviBottomBar({
    required this.index,
    required this.onChanged,
  });

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PelviColors.surface,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: PelviColors.chromeBorder, width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                Expanded(
                  child: _TabItem(
                    icon: Icons.today_outlined,
                    selectedIcon: Icons.today,
                    label: 'Today',
                    selected: index == 0,
                    onTap: () => onChanged(0),
                  ),
                ),
                Expanded(
                  child: _TabItem(
                    icon: Icons.calendar_month_outlined,
                    selectedIcon: Icons.calendar_month,
                    label: 'Calendar',
                    selected: index == 1,
                    onTap: () => onChanged(1),
                  ),
                ),
                const SizedBox(width: 56), // FAB gap
                Expanded(
                  child: _TabItem(
                    icon: Icons.people_outline,
                    selectedIcon: Icons.people,
                    label: 'Clients',
                    selected: index == 2,
                    onTap: () => onChanged(2),
                  ),
                ),
                Expanded(
                  child: _TabItem(
                    icon: Icons.more_horiz,
                    selectedIcon: Icons.more_horiz,
                    label: 'More',
                    selected: index == 3,
                    onTap: () => onChanged(3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? PelviColors.pink700 : PelviColors.inkMuted;
    return InkWell(
      onTap: onTap,
      splashColor: PelviColors.surfaceMuted,
      highlightColor: PelviColors.surfaceMuted,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? selectedIcon : icon, size: 22, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              height: 14 / 11,
              letterSpacing: 0.2,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
