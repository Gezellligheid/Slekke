/// Fill these in after deploying vercel-notify/.
class NotifyConfig {
  // ↓↓ Paste your Vercel URL and secret here ↓↓
  static const _hardcodedEndpoint = 'https://vercel-notify-green.vercel.app/api/notify';
  static const _hardcodedSecret = '60179550327887944359054607295955';
  // ↑↑──────────────────────────────────────────↑↑

  static const endpointUrl = String.fromEnvironment(
    'NOTIFY_ENDPOINT',
    defaultValue: _hardcodedEndpoint,
  );

  static const secret = String.fromEnvironment(
    'NOTIFY_SECRET',
    defaultValue: _hardcodedSecret,
  );

  /// VAPID key from Firebase Console → Project Settings →
  /// Cloud Messaging → Web Push certificates.
  static const webVapidKey = String.fromEnvironment(
    'NOTIFY_VAPID_KEY',
    defaultValue:
        'BKcsGURZhXmWMsAGBLs92BBibpCbO1_d5DrX8hNovLQ4uQDN5G8KcFJqi68SafQ4-iZJPiqwMFrGBCGQzxcGdYc',
  );
}
