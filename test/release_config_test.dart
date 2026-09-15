import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Android release configuration.
///
/// Both of the bugs these cover were invisible to every other test and to
/// debug builds, and both shipped: the release APK had no network permission
/// and no notification icon. They are build configuration, so the only way to
/// catch them in CI is to assert on the files themselves.
void main() {
  final File mainManifest = File('android/app/src/main/AndroidManifest.xml');

  test('the release build can reach the network', () {
    // Flutter only declares INTERNET in the debug and profile manifests. Left
    // to that, release builds cannot fetch at all -- every refresh fails and
    // the app shows its cache forever -- while debug builds work perfectly.
    expect(
      mainManifest.readAsStringSync(),
      contains('android.permission.INTERNET'),
      reason: 'the main manifest must declare INTERNET, not just debug',
    );
  });

  test('the notification icon survives resource shrinking', () {
    // Release builds minify, and the shrinker removes resources it cannot see
    // referenced. ic_stat_bridge is only ever named by a string passed from
    // Dart, so without an explicit keep rule it is stripped and the plugin
    // throws PlatformException(invalid_icon) on startup.
    final File keep = File('android/app/src/main/res/raw/keep.xml');
    expect(keep.existsSync(), isTrue, reason: 'res/raw/keep.xml is missing');
    final String xml = keep.readAsStringSync();
    expect(xml, contains('ic_stat_bridge'));

    // Substring matching is not enough: a keep.xml that does not parse fails
    // the whole release build inside R8, with an error that points at a row
    // and column and never mentions this file. `--` inside an XML comment is
    // illegal, and is exactly how this first went wrong.
    final Iterable<RegExpMatch> comments = RegExp(
      r'<!--(.*?)-->',
      dotAll: true,
    ).allMatches(xml);
    expect(comments, isNotEmpty);
    for (final RegExpMatch comment in comments) {
      expect(
        comment.group(1)!.contains('--'),
        isFalse,
        reason: 'XML comments cannot contain "--"',
      );
    }
  });

  test('the notification icon exists at every density', () {
    for (final String density in <String>[
      'mdpi',
      'hdpi',
      'xhdpi',
      'xxhdpi',
      'xxxhdpi',
    ]) {
      expect(
        File('android/app/src/main/res/drawable-$density/ic_stat_bridge.png')
            .existsSync(),
        isTrue,
        reason: 'ic_stat_bridge missing for $density',
      );
    }
  });

  test('the version carries a build number', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final RegExp pattern = RegExp(
      r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$',
      multiLine: true,
    );
    final RegExpMatch? match = pattern.firstMatch(pubspec);
    expect(
      match,
      isNotNull,
      reason: 'pubspec version must be <semver>+<build>, e.g. 1.1.0+2',
    );
    // Android refuses an install whose versionCode is not greater than the
    // installed one, so a build number stuck at 1 silently blocks upgrades.
    expect(int.parse(match!.group(2)!), greaterThan(1));
  });

  group('signing', () {
    test('no signing secret is tracked by git', () {
      // The keystore and its passwords are what let anyone publish an update
      // Android accepts as genuine. Losing them is bad; committing them is
      // worse, and a commit is not something you can take back.
      final ProcessResult tracked = Process.runSync('git', <String>[
        'ls-files',
      ]);
      final List<String> offenders = (tracked.stdout as String)
          .split('\n')
          .where(
            (String f) =>
                f.endsWith('key.properties') ||
                f.endsWith('.jks') ||
                f.endsWith('.keystore'),
          )
          .toList();
      expect(offenders, isEmpty, reason: 'secrets must never be committed');
    });

    test('the keystore format is documented', () {
      // Without this, the only description of key.properties lives in the
      // Gradle file that reads it.
      final File example = File('android/key.properties.example');
      expect(example.existsSync(), isTrue);
      final String text = example.readAsStringSync();
      for (final String key in <String>[
        'storeFile',
        'storePassword',
        'keyAlias',
        'keyPassword',
      ]) {
        expect(text, contains(key));
      }
    });

    test('a missing keystore falls back rather than failing the build', () {
      // A fresh clone and CI have no keystore. Requiring one would break both.
      final String gradle = File('android/app/build.gradle.kts')
          .readAsStringSync();
      expect(gradle, contains('hasReleaseKey'));
      expect(gradle, contains('signingConfigs.getByName("debug")'));
    });
  });

  group('F-Droid recipe', () {
    final File recipe = File('fdroid/fr.vinylourson.is_the_bridge_up.yml');

    String? field(String key) {
      final RegExpMatch? m = RegExp(
        '^\\s*-?\\s*$key:\\s*(\\S+)',
        multiLine: true,
      ).firstMatch(recipe.readAsStringSync());
      return m?.group(1);
    }

    test('targets the version in pubspec', () {
      // The recipe has drifted from pubspec twice already, and a stale one
      // makes F-Droid rebuild the wrong commit and compare it against an APK
      // it was never going to match.
      final RegExpMatch version = RegExp(
        r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$',
        multiLine: true,
      ).firstMatch(File('pubspec.yaml').readAsStringSync())!;
      final String name = version.group(1)!;
      final int code = int.parse(version.group(2)!);

      expect(field('versionName'), name);
      expect(field('commit'), 'v$name');
      expect(field('CurrentVersion'), name);
      // Splits offset arm64 by 2000; the recipe builds the arm64 APK.
      expect(field('versionCode'), '${2000 + code}');
      expect(field('CurrentVersionCode'), '${2000 + code}');
    });

    test('pins the signing key the releases actually use', () {
      // F-Droid refuses any binary not signed by this certificate, so a wrong
      // fingerprint here fails the build rather than accepting the wrong APK.
      expect(
        field('AllowedAPKSigningKeys'),
        'f6428f82d1c634a8dd154ebb22a141ff716e93bd0442b35f0900f433497384a5',
      );
    });

    test('builds with the same command as the release workflow', () {
      // A divergence here is invisible until F-Droid rebuilds and gets
      // different bytes, which is how the first rebuild check failed.
      for (final String path in <String>[
        '.github/workflows/release.yml',
        '.github/workflows/reproducible.yml',
        'fdroid/fr.vinylourson.is_the_bridge_up.yml',
      ]) {
        final String text = File(path).readAsStringSync();
        expect(
          text,
          contains('--split-per-abi'),
          reason: '$path must build split APKs',
        );
        expect(
          text,
          contains('--short=10'),
          reason:
              "$path must pin the abbreviation length; git's default "
              'scales with repository size',
        );
      }
    });
  });
}
