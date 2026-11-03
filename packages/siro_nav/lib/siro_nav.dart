/// Siro Navigation SDK for Flutter (Jordan, Syria & MENA).
/// Drop-in Turn-by-Turn Navigation UI and Headless Fleet Controller.
library siro_nav;

// Export all core types, events, and models
export 'package:siro_nav_core/siro_nav_core.dart';

// Controller & Services
export 'src/controller/siro_nav_controller.dart';
export 'src/controller/nav_trip_summary.dart';
export 'src/services/routing_client.dart';
export 'src/services/geocoding_client.dart';
export 'src/background/nav_background_service.dart';
export 'src/billing/nav_trip_meter.dart';
export 'src/diagnostics/nav_diagnostics.dart';
export 'src/permissions/nav_location_permission.dart';
export 'src/simulation/nav_route_simulator.dart';
export 'src/voice/nav_voice_catalog.dart';
export 'src/voice/nav_voice_engine.dart';

// Drop-in UI
export 'src/ui/siro_nav_view.dart';
export 'src/ui/nav_vehicle_icon.dart';
export 'src/ui/widgets/nav_instruction_banner.dart';
export 'src/ui/widgets/nav_bottom_bar.dart';
export 'src/ui/widgets/nav_speed_badge.dart';
