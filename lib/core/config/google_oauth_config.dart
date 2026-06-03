// Google OAuth credentials.
//
// Desktop (Windows) client — type "Desktop app":
//   console.cloud.google.com/apis/credentials → project slekke-5f041
//   Authorized redirect URIs: http://localhost
//
// Web client — type "Web application":
//   Same credentials page → create/find the web client
//   Authorized JavaScript origins: http://localhost (dev) + your prod domain
//   No client secret needed for web.

class GoogleOAuthConfig {
  // Desktop app client (Windows sign-in)
  static const clientId =
      '224585099790-2dfsa0ucdil20umj2dljdtn9a19tsds9.apps.googleusercontent.com';
  static const clientSecret = String.fromEnvironment('GOOGLE_CLIENT_SECRET');
  // Web application client (browser sign-in)
  static const webClientId =
      '224585099790-vh9ttkdre75m8ae6gvloufcvcni5a5fv.apps.googleusercontent.com';
}
