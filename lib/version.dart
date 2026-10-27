/// Version of the running build. CI passes these with `--dart-define`: the
/// version from `pubspec.yaml`, the workflow run number and the commit.
/// Local builds say `dev`.
class AppVersion {
  const AppVersion._();

  static const name = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');
  static const build = String.fromEnvironment('APP_BUILD');
  static const commit = String.fromEnvironment('APP_COMMIT');

  static String get label => build.isEmpty ? name : '$name ($build)';
}
