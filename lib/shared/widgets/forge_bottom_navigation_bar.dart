import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/forge_motion.dart';
import '../../core/theme/forge_tokens.dart';

/// A single tab definition for [ForgeBottomNavigationBar].
class ForgeNavItem {
  const ForgeNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Ported from the mockup's `.fg-navbar` / `.fg-tab` / `.fg-tab-pill`: a
/// floating, blurred, rounded pill bar with an animated active-tab
/// indicator. Purely presentational and reusable — [items], [currentIndex],
/// and [onTap] are all it needs; it has no navigation/routing knowledge.
class ForgeBottomNavigationBar extends StatelessWidget {
  const ForgeBottomNavigationBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<ForgeNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// This bar's own intrinsic content height: [_ForgeTab]'s
  /// `Padding(EdgeInsets.fromLTRB(0, 9, 0, 7))` (16) + the always-present
  /// active-pill placeholder (3, kept in layout by `AnimatedOpacity` even
  /// when invisible) + the gap below it (4) + the icon (21) + the gap
  /// below that (4) + one line of the 10px label (~14 with its default
  /// line height). Kept as one named constant here, next to the layout
  /// it describes, rather than re-measured/guessed at every call site.
  static const double _contentHeight = 62;

  /// Extra headroom for [ForgeShadows.lg]'s `blurRadius: 40, offset:
  /// Offset(0, 16)` — a shadow with a downward offset still visually
  /// bleeds upward by roughly `blurRadius - offset.dy`, which is what
  /// let this bar read as "sliding under" the last scrolled item even
  /// though Flutter's `Scaffold` already keeps `body` content
  /// geometrically clear of it.
  static const double _shadowBleedAllowance = 24;

  /// The bottom padding a scrollable shell-tab page (Home/Rank/Progress/
  /// Awards/Profile — every [StatefulShellRoute] branch root) should add
  /// below its last item so it clears this floating bar comfortably, not
  /// just technically. `Scaffold` already reserves exactly this bar's own
  /// rendered height (content + its outer margin) above system safe-area
  /// insets automatically — that part needs no help here. What it doesn't
  /// know about is this bar's own drop shadow, which paints outside its
  /// layout bounds; [_shadowBleedAllowance] is this method's contribution
  /// on top of the bar's real footprint.
  ///
  /// Every shell-tab page should call this instead of a hand-picked
  /// bottom-padding value, so all five stay consistent and this is the
  /// one place to retune if this bar's own size/margin/shadow ever
  /// changes.
  static double shellContentBottomClearance(ForgeTokens tokens) =>
      _contentHeight + tokens.spacing.space3 + _shadowBleedAllowance;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;

    return Container(
      margin: EdgeInsets.fromLTRB(
        tokens.spacing.space4,
        0,
        tokens.spacing.space4,
        tokens.spacing.space3,
      ),
      decoration: BoxDecoration(
        color: tokens.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tokens.text.withValues(alpha: 0.08)),
        boxShadow: tokens.shadowLg,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _ForgeTab(
                    item: items[i],
                    selected: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForgeTab extends StatelessWidget {
  const _ForgeTab({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ForgeNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;
    final active = tokens.accent;
    final inactive = tokens.text.withValues(alpha: 0.45);
    final color = selected ? active : inactive;
    final pillDuration = ForgeMotion.duration(
      context,
      const Duration(milliseconds: 250),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 9, 0, 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedOpacity(
                duration: pillDuration,
                opacity: selected ? 1 : 0,
                child: Container(
                  width: 34,
                  height: 3,
                  decoration: BoxDecoration(
                    color: active,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Icon(item.icon, size: 21, color: color),
              const SizedBox(height: 4),
              Text(item.label, style: TextStyle(fontSize: 10, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
