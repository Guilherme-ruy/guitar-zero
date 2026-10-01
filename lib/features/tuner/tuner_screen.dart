import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/tuner/tuner_engine.dart';
import '../preferences/tuner_preferences.dart';
import 'tuner_controller.dart';
import 'widgets/diagnostics_panel.dart';
import 'widgets/headstock/headstock_view.dart';
import 'widgets/note_display.dart';
import 'widgets/settings_sheet.dart';
import 'widgets/string_board.dart';
import 'widgets/tuner_hint.dart';
import 'widgets/zero_meter.dart';

/// Tela principal do afinador.
///
/// Inicia a escuta ao abrir e a interrompe quando o app vai para segundo
/// plano, para que o microfone nunca fique ativo sem o app visível.
class TunerScreen extends StatefulWidget {
  const TunerScreen({
    super.key,
    required this.engine,
    required this.preferences,
    this.isDemo = false,
  });

  final TunerEngine engine;
  final TunerPreferences preferences;
  final bool isDemo;

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> with WidgetsBindingObserver {
  late final TunerController _controller = TunerController(widget.engine);
  bool _showDiagnostics = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_controller.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_controller.start());
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        unawaited(_controller.stop());
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = widget.preferences;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([_controller, prefs]),
          builder: (context, _) {
            final reading = _controller.reading;
            final activeColor = reading == null
                ? GzColors.textPrimary
                : GzColors.forCents(reading.cents);
            final manual = _controller.isAutoMode
                ? null
                : _controller.activeString;
            final strings = _controller.tuning.strings;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: [
                  _Header(
                    isAuto: _controller.isAutoMode,
                    onAutoChanged: _controller.setAutoMode,
                    onLongPressLogo: () =>
                        setState(() => _showDiagnostics = !_showDiagnostics),
                  ),
                  const SizedBox(height: 4),
                  _InstrumentBar(
                    label:
                        '${prefs.instrument == InstrumentStyle.acoustic ? 'Violão' : 'Guitarra'}'
                        ' · ${_controller.tuning.name}',
                    isDemo: widget.isDemo,
                    onTap: () => showTunerSettings(context, prefs),
                  ),
                  if (_showDiagnostics) ...[
                    const SizedBox(height: 8),
                    DiagnosticsPanel(diagnostics: widget.engine.diagnostics),
                  ],
                  const Spacer(),
                  // Leitura mantida após o som acabar (hold): atenuada.
                  AnimatedOpacity(
                    duration: GzDurations.state,
                    opacity: reading?.isHeld ?? false ? 0.45 : 1,
                    child: Column(
                      children: [
                        NoteDisplay(
                          note: _controller.activeString?.note,
                          frequency: reading?.frequency,
                          cents: reading?.cents,
                          naming: prefs.noteNaming,
                          // Telas baixas: mais altura para o instrumento.
                          compact: MediaQuery.sizeOf(context).height < 720,
                        ),
                        const SizedBox(height: 16),
                        ZeroMeter(
                          cents: reading?.cents,
                          isInTune: reading?.isInTune ?? false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TunerHint(
                    status: _controller.status,
                    reading: reading,
                    onRetry: _controller.start,
                    manualString: manual,
                    naming: prefs.noteNaming,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    flex: prefs.showInstrument ? 7 : 4,
                    child: AnimatedSwitcher(
                      duration: GzDurations.state,
                      child: prefs.showInstrument
                          ? HeadstockView(
                              key: ValueKey(prefs.instrument),
                              style: prefs.instrument,
                              strings: strings,
                              activeString: _controller.activeString,
                              selectedString: manual,
                              activeColor: activeColor,
                              tunedStrings: _controller.tunedStrings,
                              naming: prefs.noteNaming,
                              onSelect: _controller.selectString,
                            )
                          : StringBoard(
                              strings: strings,
                              activeString: _controller.activeString,
                              selectedString: manual,
                              activeColor: activeColor,
                              tunedStrings: _controller.tunedStrings,
                              naming: prefs.noteNaming,
                              onSelect: _controller.selectString,
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.isAuto,
    required this.onAutoChanged,
    required this.onLongPressLogo,
  });

  final bool isAuto;
  final ValueChanged<bool> onAutoChanged;
  final VoidCallback onLongPressLogo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: GestureDetector(
            onLongPress: onLongPressLogo,
            // Encolhe em telas estreitas em vez de estourar a linha.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: GzColors.zero, width: 2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'GUITAR ZERO',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text('AUTO', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(width: 6),
        Switch(
          value: isAuto,
          onChanged: onAutoChanged,
          activeThumbColor: GzColors.background,
          activeTrackColor: GzColors.zero,
          inactiveThumbColor: GzColors.textSecondary,
          inactiveTrackColor: GzColors.surface,
          trackOutlineColor: const WidgetStatePropertyAll(GzColors.line),
        ),
      ],
    );
  }
}

/// Instrumento e afinação atuais; abre os ajustes.
class _InstrumentBar extends StatelessWidget {
  const _InstrumentBar({
    required this.label,
    required this.isDemo,
    required this.onTap,
  });

  final String label;
  final bool isDemo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Row(
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Text(
                  label.toUpperCase(),
                  style: style?.copyWith(color: GzColors.textPrimary),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.expand_more,
                  size: 18,
                  color: GzColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        if (isDemo)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: GzColors.off),
            ),
            child: Text('DEMO', style: style?.copyWith(color: GzColors.off)),
          ),
      ],
    );
  }
}
