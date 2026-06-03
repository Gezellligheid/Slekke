import 'dart:js_interop';
import 'package:web/web.dart' as web;

Future<void> playNotificationSound() async {
  try {
    final audio = web.HTMLAudioElement()..src = 'assets/sounds/notification.mp3';
    await audio.play().toDart;
  } catch (_) {}
}
