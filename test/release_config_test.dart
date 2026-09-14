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
    final Iterable<RegExpMatch> comments =
        RegExp(r'<!--(.*?)-->', dotAll: true).allMatches(xml);
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
        File(
          'android/app/src/main/res/drawable-$density/ic_stat_bridge.png',
        ).existsSync(),
        isTrue,
        reason: 'ic_stat_bridge missing for $density',
      );
    }
  });

  test('the version carries a build number', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final RegExp pattern = RegExp(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$',
        multiLine: true);
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
}
