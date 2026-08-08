/// Six competitive tiers, lowest to highest. Declaration order is the
/// ordinal order — catalog-driven [LeagueDefinition]s reference these by
/// value rather than any code branching on tier, so adding/removing a tier
/// is a catalog change, not an if/else rewrite.
enum LeagueTier { ember, iron, steel, titanium, obsidian, mythic }

extension LeagueTierOrdinal on LeagueTier {
  bool get isFloor => index == 0;
  bool get isCeiling => index == LeagueTier.values.length - 1;
}

String leagueTierLabel(LeagueTier tier) {
  return switch (tier) {
    LeagueTier.ember => 'Ember',
    LeagueTier.iron => 'Iron',
    LeagueTier.steel => 'Steel',
    LeagueTier.titanium => 'Titanium',
    LeagueTier.obsidian => 'Obsidian',
    LeagueTier.mythic => 'Mythic',
  };
}
