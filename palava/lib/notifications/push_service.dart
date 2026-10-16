import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// A notification, e.g. "New episode of Market Queen". Notifications can
/// carry `series` (a series id) and `episode` (a number) to open on tap.
class PushMessage {
  const PushMessage({this.title, this.body, this.seriesId, this.episode});

  final String? title;
  final String? body;
  final String? seriesId;
  final int? episode;
}

/// Push notifications. [FirebasePush] on phones; [NoPush] in tests and
/// wherever Firebase is not set up.
abstract class PushService {
  /// Connects to the notification service. False if it is not set up.
  Future<bool> start();

  /// Turns notifications on (asking the phone for permission the first
  /// time) or off. Returns whether they are on afterwards.
  Future<bool> setEnabled(bool enabled);

  /// Notifications that arrive while the app is open (the phone does not
  /// show those itself).
  Stream<PushMessage> get foreground;

  /// Notifications the viewer tapped to open the app.
  Stream<PushMessage> get opened;
}

class NoPush implements PushService {
  const NoPush();

  @override
  Future<bool> start() async => false;

  @override
  Future<bool> setEnabled(bool enabled) async => false;

  @override
  Stream<PushMessage> get foreground => const Stream.empty();

  @override
  Stream<PushMessage> get opened => const Stream.empty();
}

/// Firebase Cloud Messaging. Every viewer with notifications on is subscribed
/// to the [topic], so a message sent to it from the Firebase console reaches
/// everyone who wants notifications.
class FirebasePush implements PushService {
  static const topic = 'new-episodes';

  final _foreground = StreamController<PushMessage>.broadcast();
  final _opened = StreamController<PushMessage>.broadcast();
  bool _ready = false;

  @override
  Stream<PushMessage> get foreground => _foreground.stream;

  @override
  Stream<PushMessage> get opened => _opened.stream;

  @override
  Future<bool> start() async {
    try {
      // Reads android/app/google-services.json, built into the app.
      await Firebase.initializeApp();
    } on Object catch (e) {
      debugPrint('Palava: notifications are off (Firebase not set up: $e)');
      return false;
    }
    _ready = true;
    FirebaseMessaging.onMessage.listen((m) => _foreground.add(_convert(m)));
    FirebaseMessaging.onMessageOpenedApp.listen(
      (m) => _opened.add(_convert(m)),
    );
    // Shown in the `flutter run` window, for sending a test to this phone.
    FirebaseMessaging.instance.onRegistered.listen(
      (id) => debugPrint('Palava: notification ID $id'),
    );
    // The app was closed and opened by tapping a notification.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      // Give the screens a moment to start listening.
      Timer(const Duration(seconds: 1), () => _opened.add(_convert(initial)));
    }
    return true;
  }

  @override
  Future<bool> setEnabled(bool enabled) async {
    if (!_ready) return false;
    final messaging = FirebaseMessaging.instance;
    try {
      if (!enabled) {
        await messaging.unsubscribeFromTopic(topic);
        await messaging.unregister();
        await messaging.setAutoInitEnabled(false);
        return false;
      }
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return false;
      }
      await messaging.setAutoInitEnabled(true);
      await messaging.register();
      await messaging.subscribeToTopic(topic);
      return true;
    } on Object catch (e) {
      // e.g. no connection: try again next time the app opens.
      debugPrint('Palava: could not update notifications: $e');
      return enabled;
    }
  }

  static PushMessage _convert(RemoteMessage message) => PushMessage(
    title: message.notification?.title,
    body: message.notification?.body,
    seriesId: message.data['series'] as String?,
    episode: int.tryParse('${message.data['episode'] ?? ''}'),
  );
}
