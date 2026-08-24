# Bundled fonts

Two Inter static weights, bundled so `google_fonts` can resolve them from
the app's own asset bundle instead of fetching over the network — see
`docs/ARCHITECTURE.md`'s "Golden tests and font determinism" section for
why this is required for deterministic golden (pixel-comparison) tests.

| File               | Weight        | SHA-256                                                           |
|---------------------|---------------|--------------------------------------------------------------------|
| `Inter-Regular.ttf` | 400 (Regular) | `15b294b67f2f8bbc04d990023ef4aec66502b87dc9040d84abe5f896ccb693de` |
| `Inter-Medium.ttf`  | 500 (Medium)  | `36a36ff7ac46dc2aeceac3a80a87a67e7b844b8fc936699259aac8fba9bcf734` |

These are the only two weights `lib/core/theme/forge_theme.dart` actually
requests via `GoogleFonts.inter(...)`; every other weight seen in the app
(e.g. `FontWeight.w600`/`w700` in a few widgets) is a `copyWith`/plain
`TextStyle` override applied on top of one of these two loaded styles,
which Flutter renders via weight synthesis rather than a separate
`google_fonts` asset lookup — so no other weight file is needed here.

**Source and integrity**: downloaded directly from Google Fonts' CDN
(`fonts.gstatic.com`) at the exact URL the installed `google_fonts`
(pub.dev, v8.2.1) package itself would fetch at runtime for these two
variants — see that package's `lib/src/google_fonts_parts/part_i.dart`
for the expected per-variant file hash. Both downloaded files' SHA-256
hashes were verified to match those expected hashes exactly, i.e. these
are byte-identical to what `google_fonts` would download and cache on a
real device if `GoogleFonts.config.allowRuntimeFetching` were `true` —
bundling them here just makes that same, already-trusted file available
without a network round trip.

**License**: Inter is licensed under the SIL Open Font License 1.1,
which explicitly permits bundling/embedding in software — see `OFL.txt`
in this folder (fetched from the font's own canonical repository,
https://github.com/rsms/inter). Both files carry the embedded copyright
string `Copyright 2016 The Inter Project Authors
(https://github.com/rsms/inter)`, version `4.001`.
