import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Roadmap Item 21 (final visual patch) — deterministic file-existence
/// and content-reference checks for the CAN icon/splash integration.
/// Deliberately NOT pixel-comparison tests: native OS icon/splash
/// rendering (adaptive-icon masking, Windows Explorer's own icon-picker
/// logic, actual home-screen composition) isn't something `flutter test`
/// can observe, and asserting on it would be exactly the kind of fragile
/// screenshot test this item's own brief says not to write. What *is*
/// deterministic and worth checking here: the right files exist, at the
/// right paths, with the right basic properties, and the stock Flutter
/// defaults this pass was supposed to replace are actually gone.
void main() {
  // Tests run from the repo root (`flutter test`'s own working directory).
  final repoRoot = Directory.current.path;
  String p(String relative) =>
      '$repoRoot${Platform.pathSeparator}'
      '${relative.replaceAll('/', Platform.pathSeparator)}';

  group('canonical source', () {
    test('the approved CAN icon source is preserved in the repo', () {
      final file = File(p('assets/branding/can_icon_source.png'));
      expect(
        file.existsSync(),
        isTrue,
        reason: 'expected assets/branding/can_icon_source.png to exist',
      );
      expect(file.lengthSync(), greaterThan(0));
    });
  });

  group('Android icon assets', () {
    const densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];

    for (final density in densities) {
      test('legacy ic_launcher.png exists for $density', () {
        final file = File(
          p('android/app/src/main/res/mipmap-$density/ic_launcher.png'),
        );
        expect(file.existsSync(), isTrue, reason: file.path);
        expect(file.lengthSync(), greaterThan(0));
      });

      test('adaptive ic_launcher_foreground.png exists for $density', () {
        final file = File(
          p(
            'android/app/src/main/res/mipmap-$density/'
            'ic_launcher_foreground.png',
          ),
        );
        expect(file.existsSync(), isTrue, reason: file.path);
        expect(file.lengthSync(), greaterThan(0));
      });
    }

    test('adaptive icon XML descriptor references the right drawables', () {
      final xml = File(
        p('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml'),
      ).readAsStringSync();
      expect(xml, contains('@color/ic_launcher_background'));
      expect(xml, contains('@mipmap/ic_launcher_foreground'));
    });

    test('the adaptive background color is defined and dark (CAN navy)', () {
      final xml = File(
        p('android/app/src/main/res/values/colors.xml'),
      ).readAsStringSync();
      expect(xml, contains('name="ic_launcher_background"'));
      expect(xml, contains('#161826'));
    });

    test('AndroidManifest declares the CAN label, not the old Forge one', () {
      final manifest = File(
        p('android/app/src/main/AndroidManifest.xml'),
      ).readAsStringSync();
      expect(manifest, contains('android:label="CAN"'));
      expect(manifest, isNot(contains('android:label="forge"')));
    });
  });

  group('Android native launch screen', () {
    test('launch_background.xml no longer uses the stock white default', () {
      final xml = File(
        p('android/app/src/main/res/drawable/launch_background.xml'),
      ).readAsStringSync();
      expect(xml, isNot(contains('@android:color/white')));
      expect(xml, contains('@color/launch_background_color'));
    });

    test('drawable-v21 variant also uses the fixed CAN navy, not the '
        'dynamic system default', () {
      final xml = File(
        p('android/app/src/main/res/drawable-v21/launch_background.xml'),
      ).readAsStringSync();
      // Checks the functional attribute usage specifically, not a bare
      // substring — this file's own explanatory comment mentions the old
      // value as history, which a naive contains() check would wrongly
      // flag.
      expect(
        xml,
        isNot(contains('android:drawable="?android:colorBackground"')),
      );
      expect(
        xml,
        contains('android:drawable="@color/launch_background_color"'),
      );
    });

    test('launch_background_color resolves to the CAN navy, not white', () {
      final xml = File(
        p('android/app/src/main/res/values/colors.xml'),
      ).readAsStringSync();
      expect(xml, contains('name="launch_background_color"'));
      expect(xml, contains('#161826'));
    });

    test('both light and dark NormalTheme use the fixed CAN navy window '
        'background', () {
      for (final path in [
        'android/app/src/main/res/values/styles.xml',
        'android/app/src/main/res/values-night/styles.xml',
      ]) {
        final xml = File(p(path)).readAsStringSync();
        expect(xml, contains('@color/launch_background_color'), reason: path);
      }
    });
  });

  group('Web icon assets', () {
    for (final rel in [
      'web/favicon.png',
      'web/icons/Icon-192.png',
      'web/icons/Icon-512.png',
      'web/icons/Icon-maskable-192.png',
      'web/icons/Icon-maskable-512.png',
    ]) {
      test('$rel exists', () {
        final file = File(p(rel));
        expect(file.existsSync(), isTrue, reason: file.path);
        expect(file.lengthSync(), greaterThan(0));
      });
    }

    test('manifest.json only references icon files that actually exist', () {
      final manifestFile = File(p('web/manifest.json'));
      final manifest =
          jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
      expect(manifest['name'], 'CAN');
      expect(manifest['short_name'], 'CAN');

      final icons = manifest['icons'] as List<dynamic>;
      expect(icons, isNotEmpty);
      for (final icon in icons) {
        final src = (icon as Map<String, dynamic>)['src'] as String;
        final file = File(p('web/$src'));
        expect(
          file.existsSync(),
          isTrue,
          reason: 'manifest.json references web/$src, which does not exist',
        );
      }
    });

    test('index.html title and theme-color reflect CAN', () {
      final html = File(p('web/index.html')).readAsStringSync();
      expect(html, contains('<title>CAN</title>'));
      expect(html, contains('#161826'));
    });
  });

  group('Windows icon asset', () {
    test('app_icon.ico exists and is a plausible multi-resolution size', () {
      final file = File(p('windows/runner/resources/app_icon.ico'));
      expect(file.existsSync(), isTrue, reason: file.path);
      // A single-size placeholder ICO is a few KB; a real multi-resolution
      // (16/32/48/64/128/256) PNG-embedded ICO for this artwork is
      // reliably well over 50KB — a loose but meaningful floor that
      // would catch an accidental empty/truncated file without pinning
      // to an exact byte count.
      expect(file.lengthSync(), greaterThan(50 * 1024));
    });
  });
}
