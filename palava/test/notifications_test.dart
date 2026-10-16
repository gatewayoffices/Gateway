import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palava/main.dart';
import 'package:palava/notifications/push_service.dart';
import 'package:palava/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'fake_video_platform.dart';

class FakePush implements PushService {
  FakePush({this.permission = true});

  bool permission;
  final calls = <bool>[];
  final _foreground = StreamController<PushMessage>.broadcast();
  final _opened = StreamController<PushMessage>.broadcast();

  @override
  Future<bool> start() async => true;

  @override
  Future<bool> setEnabled(bool enabled) async {
    calls.add(enabled);
    return enabled && permission;
  }

  @override
  Stream<PushMessage> get foreground => _foreground.stream;

  @override
  Stream<PushMessage> get opened => _opened.stream;

  void arrive(PushMessage m) => _foreground.add(m);
  void tap(PushMessage m) => _opened.add(m);
}

void main() {
  setUp(() {
    VideoPlayerPlatform.instance = FakeVideoPlatform();
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2280);
    view.devicePixelRatio = 3;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  test('permission is asked only once the viewer is in the app', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final push = FakePush();
    final state = AppState(push: push, prefs: prefs);
    await state.start();
    expect(push.calls, isEmpty, reason: 'not on the Welcome screen');

    state.browseAsGuest();
    await Future<void>.delayed(Duration.zero);
    expect(push.calls, [true]);

    state.setNotifications(false);
    await Future<void>.delayed(Duration.zero);
    expect(push.calls, [true, false]);
    expect(prefs.getBool('notifications'), isFalse);
  });

  test('if the phone refuses, the switch turns off', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = AppState(push: FakePush(permission: false), prefs: prefs);
    await state.start();
    state.browseAsGuest();
    await Future<void>.delayed(Duration.zero);
    expect(state.notifications, isFalse);
    expect(prefs.getBool('notifications'), isFalse);
  });

  testWidgets('a notification shows in the app and opens its series', (
    tester,
  ) async {
    final push = FakePush();
    final state = AppState(push: push)..browseAsGuest();
    await tester.pumpWidget(PalavaApp(state: state));
    await tester.pump();

    push.arrive(
      const PushMessage(
        title: 'New episode',
        body: 'The Bride Price, episode 9 is out',
        seriesId: 'bride-price',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.text('New episode\nThe Bride Price, episode 9 is out'),
      findsOneWidget,
    );

    push.tap(const PushMessage(seriesId: 'bride-price'));
    await tester.pumpAndSettle();
    expect(find.text('Play episode 1'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
