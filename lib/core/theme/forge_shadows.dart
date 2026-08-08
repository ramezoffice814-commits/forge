import 'package:flutter/painting.dart';

import 'forge_colors.dart';

/// Elevation ported from the Nocturne `--shadow-*` tokens. Each token is a
/// hairline edge (a zero-blur, 1px-spread "shadow" standing in for a border)
/// plus, for md/lg, an ambient drop shadow.
abstract final class ForgeShadows {
  // `static final`, not `const`: a field-access chain through another const
  // instance (`ForgeColors.neutral.c800`) isn't a valid constant expression
  // in Dart, even though `ForgeColors.neutral` is itself const.
  static final sm = <BoxShadow>[
    BoxShadow(color: ForgeColors.neutral.c800, spreadRadius: 1),
  ];

  static final md = <BoxShadow>[
    BoxShadow(color: ForgeColors.neutral.c700, spreadRadius: 1),
    const BoxShadow(
      color: Color(0x8C000000), // rgba(0,0,0,0.55)
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];

  static final lg = <BoxShadow>[
    BoxShadow(color: ForgeColors.neutral.c500, spreadRadius: 1),
    const BoxShadow(
      color: Color(0xA6000000), // rgba(0,0,0,0.65)
      blurRadius: 40,
      offset: Offset(0, 16),
    ),
  ];
}
