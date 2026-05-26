import 'package:adhan/adhan.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Prayer name helpers
String prayerName(Prayer p) {
  switch (p) {
    case Prayer.fajr:
      return 'Fajr';
    case Prayer.sunrise:
      return 'Sunrise';
    case Prayer.dhuhr:
      return 'Dhuhr';
    case Prayer.asr:
      return 'Asr';
    case Prayer.maghrib:
      return 'Maghrib';
    case Prayer.isha:
      return 'Isha';
    case Prayer.none:
      return 'Fajr';
  }
}

String prayerNameAr(Prayer p) {
  switch (p) {
    case Prayer.fajr:
      return 'الفجر';
    case Prayer.sunrise:
      return 'الشروق';
    case Prayer.dhuhr:
      return 'الظهر';
    case Prayer.asr:
      return 'العصر';
    case Prayer.maghrib:
      return 'المغرب';
    case Prayer.isha:
      return 'العشاء';
    case Prayer.none:
      return 'الفجر';
  }
}

class PrayerTimesState {
  final bool isLoading;
  final String? error;
  final PrayerTimes? times;
  final double? latitude;
  final double? longitude;
  final bool locationDenied;

  const PrayerTimesState({
    this.isLoading = true,
    this.error,
    this.times,
    this.latitude,
    this.longitude,
    this.locationDenied = false,
  });

  PrayerTimesState copyWith({
    bool? isLoading,
    String? error,
    PrayerTimes? times,
    double? latitude,
    double? longitude,
    bool? locationDenied,
  }) {
    return PrayerTimesState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      times: times ?? this.times,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationDenied: locationDenied ?? this.locationDenied,
    );
  }

  // Current prayer (null = none active)
  Prayer get currentPrayer => times?.currentPrayer() ?? Prayer.none;

  // Next prayer, wrapping midnight: if none → fajr tomorrow
  Prayer get nextPrayer {
    if (times == null) return Prayer.fajr;
    final next = times!.nextPrayer();
    return next == Prayer.none ? Prayer.fajr : next;
  }

  DateTime? get nextPrayerTime {
    if (times == null) return null;
    final next = times!.nextPrayer();
    if (next == Prayer.none) {
      // After Isha — next is tomorrow's Fajr
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final coords = Coordinates(latitude!, longitude!);
      final params = CalculationMethod.muslim_world_league().getParameters();
      params.madhab = Madhab.shafi;
      final tomorrowTimes =
          PrayerTimes(coords, DateComponents.from(tomorrow), params);
      return tomorrowTimes.fajr;
    }
    return times!.timeForPrayer(next);
  }

  Duration get timeUntilNext {
    final t = nextPrayerTime;
    if (t == null) return Duration.zero;
    final diff = t.toLocal().difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }
}

class PrayerTimesNotifier extends Notifier<PrayerTimesState> {
  @override
  PrayerTimesState build() {
    _init();
    return const PrayerTimesState();
  }

  Future<void> _init() async {
    // Load cached location to show times immediately while refreshing
    final prefs = await SharedPreferences.getInstance();
    final cachedLat = prefs.getDouble('prayer_lat');
    final cachedLon = prefs.getDouble('prayer_lon');

    if (cachedLat != null && cachedLon != null) {
      _compute(cachedLat, cachedLon);
    }

    await _fetchLiveLocation();
  }

  Future<void> _fetchLiveLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        // Fall back to Mecca if never cached
        if (state.times == null) {
          _compute(21.3891, 39.8579); // Mecca coordinates
        }
        state = state.copyWith(isLoading: false, locationDenied: true);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      ).timeout(const Duration(seconds: 15));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('prayer_lat', position.latitude);
      await prefs.setDouble('prayer_lon', position.longitude);

      _compute(position.latitude, position.longitude);
    } catch (_) {
      if (state.times == null) {
        _compute(21.3891, 39.8579); // Mecca fallback
      }
      state = state.copyWith(isLoading: false);
    }
  }

  void _compute(double lat, double lon) {
    final coords = Coordinates(lat, lon);
    final params = CalculationMethod.muslim_world_league().getParameters();
    params.madhab = Madhab.shafi;
    final date = DateComponents.from(DateTime.now());
    final times = PrayerTimes(coords, date, params);

    state = PrayerTimesState(
      isLoading: false,
      times: times,
      latitude: lat,
      longitude: lon,
    );
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _fetchLiveLocation();
  }
}

final prayerTimesProvider =
    NotifierProvider<PrayerTimesNotifier, PrayerTimesState>(
  PrayerTimesNotifier.new,
);
