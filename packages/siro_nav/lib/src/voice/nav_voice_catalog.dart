import 'dart:convert';
import 'package:flutter/services.dart';

/// Navigation prompt descriptor from manifest.
class NavVoicePrompt {
  final String id;
  final String file;
  final String text;
  final String category;
  final int priority;

  const NavVoicePrompt({
    required this.id,
    required this.file,
    required this.text,
    required this.category,
    required this.priority,
  });

  factory NavVoicePrompt.fromJson(String id, Map<String, dynamic> json) {
    return NavVoicePrompt(
      id: id,
      file: json['file'] as String,
      text: json['text'] as String,
      category: json['category'] as String,
      priority: json['priority'] as int? ?? 2,
    );
  }
}

/// Sovereign offline voice guidance manager for Siro Nav.
/// Resolves maneuvers, speed limits, cameras, and distances to pre-baked audio files.
class NavVoiceCatalog {
  final Map<String, NavVoicePrompt> _prompts;

  NavVoiceCatalog._(this._prompts);

  /// Direct constructor with explicit prompts map (for testing and runtime config).
  factory NavVoiceCatalog.fromMap(Map<String, NavVoicePrompt> prompts) {
    _instance = NavVoiceCatalog._(prompts);
    return _instance!;
  }

  static NavVoiceCatalog? _instance;
  static NavVoiceCatalog get instance {
    if (_instance == null) {
      throw StateError(
          'NavVoiceCatalog must be initialized with loadFromManifest() first.');
    }
    return _instance!;
  }

  /// Initializes the catalog from the embedded manifest asset.
  static Future<NavVoiceCatalog> loadFromAsset({
    String manifestPath = 'packages/siro_nav/assets/audio/ar/manifest.json',
  }) async {
    try {
      final String jsonString = await rootBundle.loadString(manifestPath);
      final Map<String, dynamic> data =
          jsonDecode(jsonString) as Map<String, dynamic>;
      final rawPrompts = data['prompts'] as Map<String, dynamic>? ?? {};

      final map = <String, NavVoicePrompt>{};
      rawPrompts.forEach((key, val) {
        if (val is Map<String, dynamic>) {
          map[key] = NavVoicePrompt.fromJson(key, val);
        }
      });

      _instance = NavVoiceCatalog._(map);
      return _instance!;
    } catch (_) {
      // Fallback empty catalog if assets not bound yet
      _instance = NavVoiceCatalog._({});
      return _instance!;
    }
  }

  /// Resolves an asset path for a specific prompt ID.
  String? getAudioPath(String promptId) {
    final prompt = _prompts[promptId];
    if (prompt == null) return null;
    return 'packages/siro_nav/assets/audio/ar/${prompt.file}';
  }

  /// Checks if a prompt ID is supported offline.
  bool hasPrompt(String promptId) => _prompts.containsKey(promptId);

  /// All registered prompt keys (93 prompts).
  int get totalPrompts => _prompts.length;
}
