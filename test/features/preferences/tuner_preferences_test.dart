import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_zero/features/preferences/preferences_store.dart';
import 'package:guitar_zero/features/preferences/tuner_preferences.dart';

void main() {
  test('padrões: violão, instrumento visível, letras + solfejo', () {
    final prefs = TunerPreferences(InMemoryPreferencesStore());
    expect(prefs.instrument, InstrumentStyle.acoustic);
    expect(prefs.showInstrument, isTrue);
    expect(prefs.noteNaming, NoteNaming.both);
  });

  test('alterações são salvas e recarregadas', () async {
    final store = InMemoryPreferencesStore();
    TunerPreferences(store)
      ..instrument = InstrumentStyle.electric
      ..showInstrument = false
      ..noteNaming = NoteNaming.solfege;
    await pumpEventQueue();
    final reloaded = TunerPreferences(store);
    expect(reloaded.instrument, InstrumentStyle.electric);
    expect(reloaded.showInstrument, isFalse);
    expect(reloaded.noteNaming, NoteNaming.solfege);
  });

  test('valores desconhecidos no armazenamento caem no padrão', () {
    final prefs = TunerPreferences(
      InMemoryPreferencesStore({'instrument': 'banjo', 'note_naming': '?'}),
    );
    expect(prefs.instrument, InstrumentStyle.acoustic);
    expect(prefs.noteNaming, NoteNaming.both);
  });

  test('notifica ouvintes só quando muda', () {
    final prefs = TunerPreferences(InMemoryPreferencesStore());
    var notified = 0;
    prefs
      ..addListener(() => notified++)
      ..instrument = InstrumentStyle.acoustic
      ..instrument = InstrumentStyle.electric;
    expect(notified, 1);
  });
}
