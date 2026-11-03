# Siro Nav for Flutter
### حزمة الملاحة التوجيهية الحية داخل التطبيق (Flutter 3.x • iOS & Android)

[![Flutter](https://img.shields.io/badge/Flutter-3.x%2B-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0%2B-teal.svg)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Siro Maps](https://img.shields.io/badge/Maps-Siro%20Limestone%20Vector-purple.svg)](https://map.intaleqapp.com)

ملاحة كاملة ومباشرة داخل تطبيقك لخدمات النقل الذكي والتوصيل (Ride-Hailing & Delivery) بدون الحاجة إلى إخراج السائق لتطبيقات خارجية (مثل خرائط جوجل أو ويز). المسار، الخريطة الفيكتور ثلاثية الأبعاد، التوجيه الصوتي العربي، وعداد احتساب الأجرة والانتظار تعمل جميعها داخل كود فلاتر مباشرة.

---

## 📸 معاينة حية للمحرك (Live Visuals)

<div align="center">
  <img src="docs/media/screen_flutter_roundabout_polyline.png" width="370" alt="Siro Nav Roundabout Exit Maneuver" />
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="docs/media/screen_flutter_navigation_hud.png" width="370" alt="Siro Nav Fare & Distance Progression" />
</div>

- **خط المسار الأزرق الملاحي (Blue Route Polyline)**: يلتزم بشبكة الطرق الحقيقية ويدعم مناورات الدواوير والتقاطعات بدقة متناهية.
- **توجيه الدواوير الصوتي الذكي**: نطق رقم المخرج واسم الشارع (`عند الدوار، اسلك المخرج السادس إلى شارع الكلية العلمية الإسلامية`).
- **الماركر وسهم التوجيه التفاعلي**: يتجه فورياً مع زاوية الـ Heading ونظام الـ GPS.
- **عداد الأجرة والانتظار المباشر**: احتساب فوري للمسافة، زمن الانتظار، والأجرة بالعملة المحددة (JOD, SAR, AED, USD).
- **عداد السرعة المرتفع**: شارة دائرية بارزة واضحة للسائق أثناء القيادة.

---

## 📦 التثبيت (Installation)

أضف الحزمة إلى ملف `pubspec.yaml`:

```yaml
dependencies:
  siro_nav:
    git:
      url: https://github.com/Hamza-Ayed/siro-nav-flutter.git
      path: packages/siro_nav
```

ثم شغّل:
```bash
flutter pub get
```

---

## ⚡ البدء السريع في ٥ أسطر (Quick Start)

### ١. تهيئة المحرك وتحديد تسعيرة الرحلة (Fare Configuration)

```dart
import 'package:flutter/material.dart';
import 'package:siro_nav/siro_nav.dart';

// تهيئة المتحكم مع مفتاح منصة سيرو
final nav = await SiroNavController.create(
  config: NavConfig(apiKey: 'YOUR_SIRO_API_KEY'),
);

// تحديد تسعيرة الرحلة والعملة للمطور
final fareConfig = NavFareConfig(
  baseFare: 0.50,            // فتحة العداد المبدئية
  perKilometer: 0.35,        // سعر الكيلومتر
  perWaitingMinute: 0.05,    // سعر دقيقة الانتظار (عند سرعة أقل من 5 كم/س)
  currency: 'JOD',           // العملة: JOD, SAR, AED, USD
  waitingSpeedKmh: 5.0,
);

// بدء الملاحة نحو الوجهة
await nav.startNavigation(
  destination: NavPoint(latitude: 31.9650, longitude: 35.8900),
  phase: NavTripPhase.trip,
  fare: fareConfig,
);
```

### ٢. عرض واجهة الملاحة الجاهزة (`SiroNavView`)

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: SiroNavView(
      controller: nav,
      locale: 'ar',                // لغة الواجهة والصوت (ar / en)
      showFareMetrics: true,       // إظهار شريط الأجرة والمسافة للمطور
      onExit: () {
        nav.stopNavigation();
        Navigator.of(context).pop();
      },
    ),
  );
}
```

---

## 🎛️ الاستماع لأحداث الرحلة ومحصلة الأجرة (Trip Totals & Events)

```dart
nav.addListener((event) {
  if (event is NavProgressEvent) {
    print('المسافة المتبقية: ${event.distanceRemainingMeters} م');
    print('الأجرة الحالية: ${event.currentFare} ${fareConfig.currency}');
  } else if (event is NavArrivedEvent) {
    print('تم الوصول! إجمالي الأجرة: ${event.totals.totalFare} ${fareConfig.currency}');
    print('إجمالي المسافة: ${event.totals.totalDistanceKm} كم');
    print('دقائق الانتظار: ${event.totals.waitingMinutes} دقيقة');
  }
});
```

---

## 🧪 تشغيل الاختبارات الآلية (Unit Tests)

```bash
cd packages/siro_nav_core && dart test
cd packages/siro_nav && flutter test
```

---

## 📄 الترخيص (License)
MIT License. © 2026 Siro Maps & Hamza Ayed.
