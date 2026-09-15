import 'dart:ui';

import 'package:app/core/services/app_location_controller.dart';
import 'package:app/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const _notificationChannelId = 'ubicacion_channel';
const _notificationId = 888;

Future<void> initBackgroundService() async {
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // 1. PASO QUE FALTABA: inicializar el plugin antes de usar
  //    resolvePlatformSpecificImplementation().
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  // 2. Ahora sí, crear el canal (esto ya funcionará porque el plugin
  //    ya está "adjunto" y resolvePlatformSpecificImplementation
  //    devuelve una instancia real, no null).
  const channel = AndroidNotificationChannel(
    _notificationChannelId,
    'Ubicación compartida',
    description: 'Notificación persistente mientras compartes tu ubicación',
    importance: Importance.low,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  // 3. Configurar el background service (sin cambios)
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: _onServiceStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: _notificationChannelId,
      initialNotificationTitle: 'Compartiendo ubicación',
      initialNotificationContent: 'Tu familia puede verte en el mapa',
      foregroundServiceNotificationId: _notificationId,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: _onServiceStart,
      onBackground: _onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
void _onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final controller = AppLocationController.instance;
  await controller.start();

  service.on('stopService').listen((event) {
    controller.stop();
    service.stopSelf();
  });

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
  }
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}
