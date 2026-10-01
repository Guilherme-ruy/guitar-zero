import 'package:shared_preferences/shared_preferences.dart';

import '../features/preferences/preferences_store.dart';
import '../features/preferences/tuner_preferences.dart';

/// [PreferencesStore] com `shared_preferences` (BSD-3-Clause): arquivo de
/// preferências local do app; nada é sincronizado ou enviado.
class SharedPreferencesStore implements PreferencesStore {
  SharedPreferencesStore._(this._prefs);

  final SharedPreferencesWithCache _prefs;

  static Future<SharedPreferencesStore> open() async =>
      SharedPreferencesStore._(
        await SharedPreferencesWithCache.create(
          cacheOptions: const SharedPreferencesWithCacheOptions(
            allowList: TunerPreferences.keys,
          ),
        ),
      );

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);
}
