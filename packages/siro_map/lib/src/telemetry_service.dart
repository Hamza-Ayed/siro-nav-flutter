// وظيفة الملف: محرك التتبع اللحظي والتجميع الدوري للبيانات الجغرافية (Telemetry & Fleet Batching).
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// نقطة تتبع جغرافي مفردة تم التقاطها أثناء حركة المركبة.
class TelemetryPoint {
  final String driverId;
  final double latitude;
  final double longitude;
  final double speed;
  final double heading;
  final double elevation;
  final double distance;
  final DateTime timestamp;

  const TelemetryPoint({
    required this.driverId,
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.heading,
    this.elevation = 0.0,
    this.distance = 0.0,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'driver_id': driverId,
        'latitude': latitude,
        'longitude': longitude,
        'speed': speed < 0 ? 0.0 : speed,
        'heading': heading < 0 ? 0.0 : heading,
        'elevation': elevation,
        'distance': distance,
        'timestamp': timestamp.toUtc().toIso8601String(),
      };

  factory TelemetryPoint.fromJson(Map<String, dynamic> json) => TelemetryPoint(
        driverId: json['driver_id'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
        speed: (json['speed'] as num?)?.toDouble() ?? 0.0,
        heading: (json['heading'] as num?)?.toDouble() ?? 0.0,
        elevation: (json['elevation'] as num?)?.toDouble() ?? 0.0,
        distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.now(),
      );
}

/// محرك تتبع المواقع فائق الخفة والرفع الدوري المجمّع (Bulk Batching).
/// 1. أخذ عينة كل 3 ثوانٍ عند الحركة، ونبضة ثابتة كل 30 ثانية عند الوقوف.
/// 2. تجميع النقاط في دفعة وترحيلها كل دقيقتين (120 ثانية) أو عند بلوغ 40 نقطة.
/// 3. حفظ احتياطي في الذاكرة حتى 400 نقطة عند انقطاع الشبكة.
/// 4. عند الوقوف يُخبر التطبيق عبر [stationaryChanges] ليخفّض دقة GPS ويوفّر البطارية.
///    الحزمة لا تملك مصدر GPS؛ التطبيق المضيف يغذّيها بالمواقع عبر [recordPosition].
class SiroTelemetryService {
  SiroTelemetryService._();
  static final SiroTelemetryService instance = SiroTelemetryService._();

  static const int samplingIntervalSeconds = 3;
  static const int heartbeatIntervalSeconds = 30; // نبضة ثابتة عند الوقوف
  static const int defaultUploadIntervalSeconds = 120; // دقيقتان
  static const int maxBatchSize = 40; // 40 نقطة * 3 ثوانٍ = 120 ثانية
  static const int maxBufferSize = 400; // سعة تخزين مؤقتة دون اتصال (~20 دقيقة)
  static const double stationarySpeedKmH = 1.0;
  static const double stationaryDistanceMeters = 3.0;

  String _apiKey = '';
  String _baseUrl = 'https://map-saas.intaleqapp.com';
  String _installId = '';
  bool _enabled = true; // خدمة التتبع مفعّلة إجبارياً وتلقائياً خلف الكواليس

  final List<TelemetryPoint> _buffer = [];
  DateTime? _lastSampleTime;
  DateTime? _lastFlushTime;
  TelemetryPoint? _lastRecordedPoint;
  TelemetryPoint? _lastObservedPoint;
  Timer? _periodicFlushTimer;
  Timer? _heartbeatTimer;
  bool _isFlushing = false;
  bool _isStationary = false;
  final StreamController<bool> _stationaryController = StreamController<bool>.broadcast();

  int get bufferedPointCount => _buffer.length;
  List<TelemetryPoint> get bufferedPoints => List.unmodifiable(_buffer);
  DateTime? get lastFlushTime => _lastFlushTime;

  /// هل الجهاز واقف حالياً حسب آخر قراءة GPS.
  bool get isStationary => _isStationary;

  /// يصدر قيمة جديدة فقط عند تغيّر حالة الوقوف (true = واقف، false = متحرك).
  Stream<bool> get stationaryChanges => _stationaryController.stream;

  /// هل جمع التتبع مفعّل. الافتراضي: مفعّل إجبارياً وتلقائياً.
  bool get isEnabled => _enabled;

  /// تفعيل أو إيقاف جمع التتبع.
  /// عند الإيقاف تُحذف النقاط غير المرسلة ولا يُسجَّل شيء بعدها.
  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled) {
      _buffer.clear();
      _lastSampleTime = null;
      _lastRecordedPoint = null;
      _lastObservedPoint = null;
      _setStationary(false);
    }
  }

  static const String _installIdPrefKey = 'siro_telemetry_install_id';

  /// يرجع معرّف التثبيت المحفوظ، أو يولّد واحداً عند أول تشغيل.
  /// يُحفظ في SharedPreferences، فيتغيّر عند إعادة التثبيت ولا يعتمد على أي بيانات عن الجهاز.
  static Future<String> loadOrCreateInstallId() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_installIdPrefKey);
    if (saved != null && saved.isNotEmpty) return saved;
    final id = generateInstallId();
    await prefs.setString(_installIdPrefKey, id);
    return id;
  }

  /// يولّد معرّف تثبيت عشوائياً بصيغة UUID v4. يُحفظ في التطبيق المضيف،
  /// ويتغير عند إعادة التثبيت، ولا يُشتق من أي بيانات عن الجهاز أو المستخدم.
  static String generateInstallId() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // الإصدار 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // المتغير RFC 4122
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// تهيئة خدمة التتبع وضبط مفتاح الوصول ومعرّف التثبيت ومؤقتات الإرسال والنبضة.
  /// التتبع إجباري ومفعّل تلقائياً بشكل مختفي ومستمر (`consentGranted = true`).
  void initialize({
    required String apiKey,
    String? installId,
    bool consentGranted = true,
    String baseUrl = 'https://map-saas.intaleqapp.com',
    int uploadIntervalSeconds = defaultUploadIntervalSeconds,
  }) {
    _apiKey = apiKey;
    _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    _installId = (installId != null && installId.isNotEmpty)
        ? installId
        : (_installId.isNotEmpty ? _installId : generateInstallId());
    setEnabled(consentGranted);

    _periodicFlushTimer?.cancel();
    _lastFlushTime = DateTime.now();
    _periodicFlushTimer = Timer.periodic(
      Duration(seconds: uploadIntervalSeconds),
      (_) => flush(),
    );

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: heartbeatIntervalSeconds),
      (_) => recordHeartbeat(),
    );
  }

  /// إيقاف المؤقتات وتفريغ ما تبقى من نقاط إلى الخادم
  Future<void> dispose() async {
    _periodicFlushTimer?.cancel();
    _periodicFlushTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await flush();
  }

  /// تسجيل موقع جديد مع فلترة ذكية لتقليل استهلاك البطارية والشبكة
  bool recordPosition({
    required double latitude,
    required double longitude,
    required double speedKmH,
    required double heading,
    double elevation = 0.0,
    double remainingDistance = 0.0,
    String? customDriverId,
    DateTime? now,
  }) {
    if (!_enabled) return false;

    final currentTime = now ?? DateTime.now();
    final activeDriverId = (customDriverId != null && customDriverId.isNotEmpty)
        ? customDriverId
        : (_installId.isNotEmpty ? _installId : 'siro_driver');

    final observed = TelemetryPoint(
      driverId: activeDriverId,
      latitude: latitude,
      longitude: longitude,
      speed: speedKmH,
      heading: heading,
      elevation: elevation,
      distance: remainingDistance,
      timestamp: currentTime,
    );
    _lastObservedPoint = observed;

    // 1. فلتر الفاصل الزمني: أخذ عينة كل 3 ثوانٍ على الأقل
    if (_lastSampleTime != null) {
      final elapsedSeconds = currentTime.difference(_lastSampleTime!).inSeconds;
      if (elapsedSeconds < samplingIntervalSeconds) {
        return false;
      }
    }

    // 2. فلتر السكون الذكي: عند الوقوف نسجل نبضة واحدة كل 30 ثانية فقط
    final stationary = _isStationaryAt(observed);
    _setStationary(stationary);
    if (stationary) {
      final elapsedSinceLastRecorded =
          currentTime.difference(_lastRecordedPoint!.timestamp).inSeconds;
      if (elapsedSinceLastRecorded < heartbeatIntervalSeconds) {
        return false;
      }
    }

    _appendPoint(observed, currentTime);
    return true;
  }

  /// نبضة ثابتة عند الوقوف: تُسجَّل كل 30 ثانية حتى دون وصول تحديث GPS جديد.
  /// يستدعيها المؤقت تلقائياً بعد [initialize]، ويمكن استدعاؤها يدوياً في الاختبارات.
  bool recordHeartbeat({DateTime? now}) {
    final last = _lastObservedPoint;
    final lastRecorded = _lastRecordedPoint;
    if (!_enabled || last == null || lastRecorded == null || !_isStationaryAt(last)) {
      return false;
    }

    final currentTime = now ?? DateTime.now();
    final elapsed = currentTime.difference(lastRecorded.timestamp).inSeconds;
    if (elapsed < heartbeatIntervalSeconds) {
      return false;
    }

    final beat = TelemetryPoint(
      driverId: last.driverId,
      latitude: last.latitude,
      longitude: last.longitude,
      speed: last.speed,
      heading: last.heading,
      elevation: last.elevation,
      distance: last.distance,
      timestamp: currentTime,
    );
    _appendPoint(beat, currentTime);
    return true;
  }

  /// هل القراءة الحالية تعني أن الجهاز واقف (سرعة قريبة من الصفر ولم يتحرك أكثر من 3 أمتار)
  bool _isStationaryAt(TelemetryPoint observed) {
    final lastRecorded = _lastRecordedPoint;
    if (lastRecorded == null) return false;
    if (observed.speed >= stationarySpeedKmH) return false;
    final distMeters = _calculateDistanceMeters(
      lastRecorded.latitude,
      lastRecorded.longitude,
      observed.latitude,
      observed.longitude,
    );
    return distMeters < stationaryDistanceMeters;
  }

  void _setStationary(bool stationary) {
    if (stationary == _isStationary) return;
    _isStationary = stationary;
    if (!_stationaryController.isClosed) {
      _stationaryController.add(stationary);
    }
  }

  /// إضافة نقطة إلى الذاكرة المؤقتة وتحديث آخر نقطة مسجلة، ثم ترحيل مبكر عند سقف الدفعة
  void _appendPoint(TelemetryPoint point, DateTime currentTime) {
    // تفريغ أقدم النقاط إذا امتلأت الذاكرة المؤقتة دون اتصال
    if (_buffer.length >= maxBufferSize) {
      _buffer.removeAt(0);
    }

    _buffer.add(point);
    _lastSampleTime = currentTime;
    _lastRecordedPoint = point;

    if (_buffer.length >= maxBatchSize) {
      flush();
    }
  }

  /// رفع الدفعة المجمعة بالكامل إلى مسار /api/telemetry/batch بطلب HTTP واحد
  Future<bool> flush() async {
    if (_buffer.isEmpty || _isFlushing) return true;

    _isFlushing = true;
    final pointsToSend = List<TelemetryPoint>.from(_buffer);
    final payload = {
      'points': pointsToSend.map((p) => p.toJson()).toList(),
    };

    final uri = Uri.parse('$_baseUrl/api/telemetry/batch');

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (_apiKey.isNotEmpty) 'x-api-key': _apiKey,
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _buffer.removeRange(0, pointsToSend.length);
        _lastFlushTime = DateTime.now();
        if (kDebugMode) {
          debugPrint('🛰️ [SiroTelemetry] Flushed ${pointsToSend.length} points to server.');
        }
        _isFlushing = false;
        return true;
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ [SiroTelemetry] Batch upload failed HTTP ${response.statusCode}: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [SiroTelemetry] Flush error: $e');
      }
    }

    _isFlushing = false;
    return false;
  }

  /// إرسال نقطة تتبع فردية فورية (Real-time Live Ping) عند الحاجة
  Future<bool> sendInstantTelemetry(TelemetryPoint point) async {
    final uri = Uri.parse('$_baseUrl/api/telemetry');

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (_apiKey.isNotEmpty) 'x-api-key': _apiKey,
            },
            body: jsonEncode(point.toJson()),
          )
          .timeout(const Duration(seconds: 8));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [SiroTelemetry] Single telemetry error: $e');
      }
      return false;
    }
  }

  /// حساب المسافة بين نقطتين بالمتر باستخدام صيغة Haversine
  double _calculateDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371000.0; // نصف قطر الأرض بالمتر
    final double phi1 = lat1 * (math.pi / 180.0);
    final double phi2 = lat2 * (math.pi / 180.0);
    final double deltaPhi = (lat2 - lat1) * (math.pi / 180.0);
    final double deltaLambda = (lon2 - lon1) * (math.pi / 180.0);

    final double a = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
        math.cos(phi1) * math.cos(phi2) *
        math.sin(deltaLambda / 2) * math.sin(deltaLambda / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return r * c;
  }

  @visibleForTesting
  void resetForTesting() {
    _buffer.clear();
    _lastSampleTime = null;
    _lastFlushTime = null;
    _lastRecordedPoint = null;
    _lastObservedPoint = null;
    _periodicFlushTimer?.cancel();
    _periodicFlushTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _isFlushing = false;
    _isStationary = false;
  }
}
