import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

class StorageService {
  final _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  Future<String> uploadMessageImage({
    required String channelId,
    required File file,
  }) async {
    final ext = p.extension(file.path);
    final name = _uuid.v4();
    final ref = _storage.ref('channels/$channelId/images/$name$ext');
    final task = await ref.putFile(file);
    return task.ref.getDownloadURL();
  }

  Future<String> uploadProfilePicture({
    required String uid,
    required Uint8List bytes,
    required String extension,
  }) async {
    final ext = extension.startsWith('.') ? extension : '.$extension';
    final ref = _storage.ref('users/$uid/avatar$ext');
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/${ext.replaceFirst('.', '')}'),
    );
    return task.ref.getDownloadURL();
  }

  Future<void> deleteFile(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
  }
}
