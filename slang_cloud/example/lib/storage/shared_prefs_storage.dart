import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slang_cloud/slang_cloud.dart';

/// SharedPreferences implementation of SlangCloudStorage.
/// Persists translations with metadata to device storage.
class SharedPreferencesSlangCloudStorage implements SlangCloudStorage {
  static const String _cacheKey = 'slang_cloud_cached';

  SharedPreferences? _prefs;

  /// Private constructor
  SharedPreferencesSlangCloudStorage._();

  /// Factory constructor that initializes SharedPreferences
  static Future<SharedPreferencesSlangCloudStorage> create() async {
    final storage = SharedPreferencesSlangCloudStorage._();
    await storage._init();
    return storage;
  }

  Future<void> _init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<CachedTranslations?> getCached() async {
    final jsonStr = _prefs!.getString(_cacheKey);
    if (jsonStr == null) return null;

    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return CachedTranslations.fromJson(map);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> setCached(CachedTranslations cached) async {
    final jsonStr = jsonEncode(cached.toJson());
    await _prefs!.setString(_cacheKey, jsonStr);
  }

  @override
  Future<void> clear() async {
    await _prefs!.remove(_cacheKey);
  }
}
