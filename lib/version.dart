/// Version of the running build. CI passes these with `--dart-define`: the
/// version from `pubspec.yaml`, the workflow run number and the commit.
/// Local builds say `dev`.
class AppVersion {
  const AppVersion._();

  static const name = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');
  static const build = String.fromEnvironment('APP_BUILD');
  static const commit = String.fromEnvironment('APP_COMMIT');

  /// The GitHub repository this copy was built from: a fork links to its own secrets.
  static const repo = String.fromEnvironment('APP_REPO', defaultValue: upstream);
  static const upstream = 'Nikityyy/the-future';

  static String get label => build.isEmpty ? name : '$name ($build)';
}
