class AppConstants {
  static const backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://localhost:5000',
  );

  static const maxCaptionLength = 1024;
}
