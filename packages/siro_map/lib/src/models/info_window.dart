// وظيفة الملف: تنفيذ أو إعداد info window ضمن هذا الجزء من المشروع.
import 'package:flutter/foundation.dart' show VoidCallback;

/// Text labels and a tap callback shown when a [Marker] is tapped.
///
/// Mirrors `InfoWindow` from `google_maps_flutter`.
class InfoWindow {
  const InfoWindow({
    this.title,
    this.snippet,
    this.onTap,
  });

  /// Displayed as the window heading.
  final String? title;

  /// Displayed below the title as secondary text.
  final String? snippet;

  /// Called when the info window itself is tapped.
  final VoidCallback? onTap;

  /// An [InfoWindow] with no text (the default).
  static const InfoWindow noText = InfoWindow();

  InfoWindow copyWith({
    String? title,
    String? snippet,
    VoidCallback? onTap,
  }) {
    return InfoWindow(
      title: title ?? this.title,
      snippet: snippet ?? this.snippet,
      onTap: onTap ?? this.onTap,
    );
  }

  @override
  String toString() => 'InfoWindow(title: $title, snippet: $snippet)';
}
