import 'package:package_info_plus/package_info_plus.dart';

/// The running build's identity.
///
/// Read from the installed package rather than from a constant compiled into
/// Dart, so it reports what is *actually* on the device. A constant can be
/// stale in a way this cannot: the whole point is answering "is this the build
/// I just installed?" without having to trust that it is.
class AppVersion {
  const AppVersion({
    required this.name,
    required this.build,
    required this.commit,
  });

  /// Semantic version, e.g. `1.1.0`.
  final String name;

  /// Build number, e.g. `2`. Increases on every release.
  final String build;

  /// Short git SHA, when the build was given one. Empty otherwise.
  ///
  /// Passed at build time with
  /// `--dart-define=GIT_SHA=$(git rev-parse --short HEAD)`. Absent for a
  /// plain local build, which is the honest answer: nothing ties such a build
  /// to a commit.
  final String commit;

  /// Never baked into a committed file: it would be stale the moment the next
  /// commit landed, and a staleness check could never pass.
  static const String _commitFromBuild = String.fromEnvironment('GIT_SHA');

  /// Null when the platform cannot say -- in a widget test, for instance,
  /// where the plugin is not registered. The Info screen then omits the line
  /// rather than showing a wrong or half-known version, and goldens stay
  /// stable across version bumps instead of needing a rebaseline each time.
  static Future<AppVersion?> load() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      return AppVersion(
        name: info.version,
        build: info.buildNumber,
        commit: _commitFromBuild,
      );
    } catch (_) {
      return null;
    }
  }

  /// `v1.1.0 (2)`, plus the commit when there is one.
  String get label {
    final String base = 'v$name ($build)';
    return commit.isEmpty ? base : '$base · $commit';
  }
}
