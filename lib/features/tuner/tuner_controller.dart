import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/audio/audio_input.dart';
import '../../core/music/guitar_string.dart';
import '../../core/music/tuning.dart';
import '../../core/tuner/tuner_engine.dart';
import '../../core/tuner/tuner_reading.dart';

enum TunerStatus { idle, starting, listening, permissionDenied, unavailable }

/// Estado de apresentação do afinador. Faz a ponte entre o [TunerEngine] e
/// os widgets, que apenas leem este estado.
class TunerController extends ChangeNotifier {
  TunerController(this._engine);

  final TunerEngine _engine;
  StreamSubscription<TunerReading?>? _subscription;

  TunerStatus _status = TunerStatus.idle;
  TunerReading? _reading;
  GuitarString? _activeString;
  final Set<GuitarString> _tunedStrings = {};
  bool _disposed = false;

  /// Incrementado a cada start/stop, para detectar chamadas sobrepostas.
  int _session = 0;

  Tuning get tuning => _engine.config.tuning;

  TunerStatus get status => _status;

  /// Leitura atual, ou `null` se nenhuma nota está soando.
  TunerReading? get reading => _reading;

  /// Corda em destaque: no manual, a escolhida; no automático, a última
  /// detectada (permanece durante o silêncio para a interface não piscar).
  GuitarString? get activeString => _manualString ?? _activeString;

  GuitarString? _manualString;

  /// `true` no modo automático (padrão): a corda é identificada pelo som.
  bool get isAutoMode => _manualString == null;

  /// Liga/desliga o automático (o switch "AUTO"). Ao entrar no manual pelo
  /// switch, fica escolhida a corda em destaque (ou a 6ª, se nenhuma).
  void setAutoMode(bool auto) {
    if (auto == isAutoMode) return;
    _applyTarget(auto ? null : (_activeString ?? tuning.strings.first));
  }

  /// Escolhe a corda manualmente (tocar numa corda). Entra no modo manual;
  /// só o switch volta ao automático.
  void selectString(GuitarString string) => _applyTarget(string);

  void _applyTarget(GuitarString? string) {
    _manualString = string;
    _engine.setTargetString(string);
    if (string != null) _activeString = string;
    _reading = null;
    notifyListeners();
  }

  /// Cordas que já atingiram a tolerância de afinação nesta sessão.
  Set<GuitarString> get tunedStrings => Set.unmodifiable(_tunedStrings);

  Future<void> start() async {
    if (_status == TunerStatus.listening || _status == TunerStatus.starting) {
      return;
    }
    final session = ++_session;
    _setStatus(TunerStatus.starting);
    _subscription ??= _engine.readings.listen(
      _onReading,
      onError: _onEngineError,
    );
    try {
      await _engine.start();
      if (session != _session) {
        // stop() foi chamado enquanto aguardávamos (ex.: app foi para
        // segundo plano durante o pedido de permissão).
        await _engine.stop();
        return;
      }
      _setStatus(TunerStatus.listening);
    } on AudioInputException catch (e) {
      if (session != _session) return;
      _setStatus(switch (e.failure) {
        AudioInputFailure.permissionDenied => TunerStatus.permissionDenied,
        AudioInputFailure.unavailable => TunerStatus.unavailable,
      });
    }
  }

  Future<void> stop() async {
    _session++;
    await _engine.stop();
    _reading = null;
    _setStatus(TunerStatus.idle);
  }

  /// Falha da captura durante o uso: para o engine e mostra o motivo; o
  /// usuário pode tentar de novo.
  void _onEngineError(Object error) {
    if (_disposed) return;
    _session++;
    unawaited(_engine.stop());
    _reading = null;
    _setStatus(
      error is AudioInputException &&
              error.failure == AudioInputFailure.permissionDenied
          ? TunerStatus.permissionDenied
          : TunerStatus.unavailable,
    );
  }

  void _onReading(TunerReading? reading) {
    if (_disposed) return;
    _reading = reading;
    if (reading != null) {
      if (reading.string != _activeString) {
        _activeString = reading.string;
      }
      if (reading.isInTune) _tunedStrings.add(reading.string);
    }
    notifyListeners();
  }

  void _setStatus(TunerStatus status) {
    if (_disposed) return;
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    unawaited(_engine.dispose());
    super.dispose();
  }
}
