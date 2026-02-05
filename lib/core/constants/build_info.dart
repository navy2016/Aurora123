class BuildInfo {
  static const buildName =
      String.fromEnvironment('FLUTTER_BUILD_NAME', defaultValue: 'dev');
  static const buildNumber =
      String.fromEnvironment('FLUTTER_BUILD_NUMBER', defaultValue: '0');

  static const version = buildName;
  static const fullVersion = '$buildName+$buildNumber';
}
