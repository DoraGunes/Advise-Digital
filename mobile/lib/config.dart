class AppConfig {
  static const String defaultApiBaseUrl = String.fromEnvironment(
    'ADVISE_API_URL',
    defaultValue: 'https://advisedigital.poyrazteknikservis.com.tr',
  );
  static const String appName = 'AdVise AI';
}
