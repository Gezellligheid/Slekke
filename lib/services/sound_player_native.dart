import 'package:audioplayers/audioplayers.dart';

AudioPlayer? _player;

Future<void> playNotificationSound() async {
  try {
    _player ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
    await _player!.stop();
    await _player!.play(AssetSource('sounds/notification.mp3'));
  } catch (e) {
    // Reset so the next call recreates it (e.g. after a hot restart)
    _player?.dispose();
    _player = null;
  }
}
