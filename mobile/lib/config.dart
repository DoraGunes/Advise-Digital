class AppConfig {
  static const String defaultApiBaseUrl = String.fromEnvironment(
    'ADVISE_API_URL',
    defaultValue: 'https://childhood-stored-maintenance-cell.trycloudflare.com',
  );
  static const String appName = 'AdVise AI';
}
