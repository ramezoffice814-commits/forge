import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge/core/theme/forge_tokens.dart';

void main() {
  group('ForgeTokens.dark', () {
    final tokens = ForgeTokens.dark();

    test('ports the Nocturne base colors exactly', () {
      expect(tokens.background, const Color(0xFF161826));
      expect(tokens.surface, const Color(0xFF232532));
      expect(tokens.text, const Color(0xFFE9E9ED));
      expect(tokens.accent, const Color(0xFF9184D9));
    });

    test('ports the spacing scale', () {
      expect(tokens.spacing.space1, 2.8);
      expect(tokens.spacing.space4, 11.2);
      expect(tokens.spacing.space8, 22.4);
    });

    test('ports the radius scale', () {
      expect(tokens.radius.sm, 4);
      expect(tokens.radius.md, 8);
      expect(tokens.radius.lg, 14);
    });

    test('lerp is a no-op between two ForgeTokens (dark-only today)', () {
      final other = ForgeTokens.dark();
      final result = tokens.lerp(other, 0.5);
      expect(result, other);
    });
  });
}
