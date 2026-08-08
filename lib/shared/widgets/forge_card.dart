import 'package:flutter/material.dart';

import '../../core/theme/forge_tokens.dart';

/// Elevation levels matching `.elev-sm` / `.elev-md` / `.elev-lg`.
enum ForgeCardElevation { none, sm, md, lg }

/// Ported from `.card` in the Nocturne styles: surface background,
/// `radius-md` corners, `space-3` padding, `space-2` gap between children.
class ForgeCard extends StatelessWidget {
  const ForgeCard({
    super.key,
    required this.children,
    this.elevation = ForgeCardElevation.none,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  final List<Widget> children;
  final ForgeCardElevation elevation;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ForgeTokens>()!;

    final List<BoxShadow>? shadow = switch (elevation) {
      ForgeCardElevation.none => null,
      ForgeCardElevation.sm => tokens.shadowSm,
      ForgeCardElevation.md => tokens.shadowMd,
      ForgeCardElevation.lg => tokens.shadowLg,
    };

    final spaced = <Widget>[
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) SizedBox(height: tokens.spacing.space2),
        children[i],
      ],
    ];

    return Container(
      padding: EdgeInsets.all(tokens.spacing.space3),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: tokens.radius.mdRadius,
        boxShadow: shadow,
      ),
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: MainAxisSize.min,
        children: spaced,
      ),
    );
  }
}
