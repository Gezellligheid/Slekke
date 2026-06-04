import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/tenor_config.dart';

class GifResult {
  final String id;
  final String gifUrl;      // full GIF (sent in message)
  final String previewUrl;  // downsized preview (shown in picker)
  final String title;

  const GifResult({
    required this.id,
    required this.gifUrl,
    required this.previewUrl,
    required this.title,
  });

  factory GifResult.fromJson(Map<String, dynamic> json) {
    final images = json['images'] as Map<String, dynamic>? ?? {};
    final original = images['original'] as Map<String, dynamic>? ?? {};
    final preview = images['fixed_height_small'] as Map<String, dynamic>? ?? images['downsized'] as Map<String, dynamic>? ?? {};
    return GifResult(
      id: json['id'] as String? ?? '',
      gifUrl: original['url'] as String? ?? '',
      previewUrl: preview['url'] as String? ?? original['url'] as String? ?? '',
      title: json['title'] as String? ?? '',
    );
  }
}

class GifService {
  static const _base = 'https://api.giphy.com/v1/gifs';

  Future<List<GifResult>> trending({int limit = 24}) async {
    final uri = Uri.parse('$_base/trending').replace(queryParameters: {
      'api_key': GiphyConfig.apiKey,
      'limit': '$limit',
      'rating': 'pg-13',
    });
    return _fetch(uri);
  }

  Future<List<GifResult>> search(String query, {int limit = 24}) async {
    final uri = Uri.parse('$_base/search').replace(queryParameters: {
      'api_key': GiphyConfig.apiKey,
      'q': query,
      'limit': '$limit',
      'rating': 'pg-13',
    });
    return _fetch(uri);
  }

  Future<List<GifResult>> _fetch(Uri uri) async {
    try {
      final res = await http.get(uri);
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = (body['data'] as List<dynamic>?) ?? [];
      return data
          .map((r) => GifResult.fromJson(r as Map<String, dynamic>))
          .where((r) => r.gifUrl.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
