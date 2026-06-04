// Get a free API key at https://developers.giphy.com/
// Add GIPHY_API_KEY to your .env.json and run with --dart-define-from-file=.env.json
class GiphyConfig {
  static const apiKey = String.fromEnvironment(
    'GIPHY_API_KEY',
    defaultValue: '',
  );
}
