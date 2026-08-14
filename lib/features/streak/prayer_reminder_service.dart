import 'package:adhan/adhan.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Handles prayer-time calculation and local notification scheduling.
class PrayerReminderService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _channelId = 'quran_streak_reminder';
  static const _notifId   = 101;

  static Future<void> init() async {
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios     = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  /// Request notification + location permissions. Returns true if both granted.
  static Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final notifGranted = await android?.requestNotificationsPermission() ?? false;
    if (!notifGranted) return false;

    LocationPermission lp = await Geolocator.checkPermission();
    if (lp == LocationPermission.denied) {
      lp = await Geolocator.requestPermission();
    }
    return lp != LocationPermission.denied &&
        lp != LocationPermission.deniedForever;
  }

  /// Schedule a daily reminder at the given prayer (0=Fajr, 1=Dhuhr, 2=Isha).
  static Future<void> scheduleForPrayer(int prayer) async {
    await _plugin.cancel(_notifId);

    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.low),
      );
    } catch (_) {
      return; // Location unavailable — silently skip
    }

    final coords = Coordinates(pos.latitude, pos.longitude);
    final params  = CalculationMethod.muslimWorldLeague().getParameters();

    DateTime? target = _prayerTime(prayer, DateTime.now(), coords, params);
    if (target == null) return;

    // If prayer has already passed today, use tomorrow's occurrence
    if (target.isBefore(DateTime.now())) {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      target = _prayerTime(prayer, tomorrow, coords, params);
    }
    if (target == null) return;

    final scheduled = tz.TZDateTime.from(target, tz.local);

    await _plugin.zonedSchedule(
      _notifId,
      'وقت قراءة القرآن 📖',
      'داوم على وردك اليومي · Keep your daily streak going',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Daily Quran Reminder',
          channelDescription:
              'Reminds you to maintain your daily Quran reading streak',
          importance: Importance.high,
          priority:   Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancel() => _plugin.cancel(_notifId);

  static DateTime? _prayerTime(
    int prayer,
    DateTime date,
    Coordinates coords,
    CalculationParameters params,
  ) {
    final times = PrayerTimes(
      coords,
      DateComponents(date.year, date.month, date.day),
      params,
    );
    return switch (prayer) {
      0 => times.fajr,
      1 => times.dhuhr,
      2 => times.isha,
      _ => null,
    };
  }
}
