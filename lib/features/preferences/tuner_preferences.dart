import 'package:flutter/foundation.dart';

import 'preferences_store.dart';

/// Instrumento desenhado ao fundo (só visual: a afinação é a mesma).
enum InstrumentStyle {
  /// Violão: headstock com 3 tarraxas de cada lado.
  acoustic,

  /// Guitarra: 6 tarraxas em linha.
  electric,
}

/// Como os nomes das notas aparecem.
enum NoteNaming {
  /// E A D G B E
  letters,

  /// Mi Lá Ré Sol Si Mi
  solfege,

  /// Letra em destaque e solfejo pequeno.
  both,
}

/// Preferências visuais do afinador, persistidas localmente.
class TunerPreferences extends ChangeNotifier {
  TunerPreferences(this._store)
    : _instrument = _read(
        _store,
        _instrumentKey,
        InstrumentStyle.values,
        InstrumentStyle.acoustic,
      ),
      _noteNaming = _read(
        _store,
        _namingKey,
        NoteNaming.values,
        NoteNaming.both,
      ),
      _showInstrument = _store.getString(_showInstrumentKey) != 'false';

  final PreferencesStore _store;

  static const _instrumentKey = 'instrument';
  static const _namingKey = 'note_naming';
  static const _showInstrumentKey = 'show_instrument';

  /// Todas as chaves usadas (para a lista de permissão do armazenamento).
  static const Set<String> keys = {
    _instrumentKey,
    _namingKey,
    _showInstrumentKey,
  };

  InstrumentStyle _instrument;
  NoteNaming _noteNaming;
  bool _showInstrument;

  InstrumentStyle get instrument => _instrument;
  NoteNaming get noteNaming => _noteNaming;

  /// `false` = visual minimalista (só as cordas).
  bool get showInstrument => _showInstrument;

  set instrument(InstrumentStyle value) {
    if (value == _instrument) return;
    _instrument = value;
    _save(_instrumentKey, value.name);
  }

  set noteNaming(NoteNaming value) {
    if (value == _noteNaming) return;
    _noteNaming = value;
    _save(_namingKey, value.name);
  }

  set showInstrument(bool value) {
    if (value == _showInstrument) return;
    _showInstrument = value;
    _save(_showInstrumentKey, '$value');
  }

  void _save(String key, String value) {
    notifyListeners();
    // Falha ao salvar não deve afetar o uso; a preferência vale na sessão.
    _store.setString(key, value).ignore();
  }

  static T _read<T extends Enum>(
    PreferencesStore store,
    String key,
    List<T> values,
    T fallback,
  ) {
    final name = store.getString(key);
    for (final v in values) {
      if (v.name == name) return v;
    }
    return fallback;
  }
}
