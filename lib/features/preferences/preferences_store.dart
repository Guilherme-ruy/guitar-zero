/// Armazenamento chave-valor local e síncrono para leitura (carregado antes
/// do app iniciar). Nada sai do aparelho.
abstract interface class PreferencesStore {
  String? getString(String key);

  Future<void> setString(String key, String value);
}

/// Implementação em memória (testes e fallback).
class InMemoryPreferencesStore implements PreferencesStore {
  InMemoryPreferencesStore([Map<String, String>? initial])
    : _values = {...?initial};

  final Map<String, String> _values;

  @override
  String? getString(String key) => _values[key];

  @override
  Future<void> setString(String key, String value) async =>
      _values[key] = value;
}
