class AppConstants {
  static const backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://backend-production-e947.up.railway.app',
  );

  static const maxCaptionLength = 1024;
}
