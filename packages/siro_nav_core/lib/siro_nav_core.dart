/// Siro Navigation Core - Pure Dart Headless Navigation & Telemetry Engine.
library siro_nav_core;

// Models
export 'src/models/nav_point.dart';
export 'src/models/nav_step.dart';
export 'src/models/nav_route.dart';
export 'src/models/nav_route_details.dart';
export 'src/models/speed_camera.dart';
export 'src/models/telemetry_point.dart';
export 'src/models/nav_config.dart';

// Events
export 'src/events/nav_events.dart';

// Geometry
export 'src/geo/polyline_codec.dart';

// Engine
export 'src/engine/navigation_engine.dart';
export 'src/engine/map_matcher.dart';
export 'src/engine/instruction_scheduler.dart';
export 'src/engine/camera_tracker.dart';

// Telemetry & Security
export 'src/telemetry/telemetry_collector.dart';
export 'src/auth/api_key_validator.dart';
