import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/tuner/tuner_engine.dart';
import 'tuner_controller.dart';
import 'widgets/note_display.dart';
import 'widgets/string_board.dart';
import 'widgets/tuner_hint.dart';
import 'widgets/zero_meter.dart';

/// Tela principal do afinador.
///
/// Inicia a escuta ao abrir e a interrompe quando o app vai para segundo
/// plano, para que o microfone nunca fique ativo sem o app visível.
class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key, required this.engine, this.isDemo = false});

  final TunerEngine engine;
  final bool isDemo;

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> with WidgetsBindingObserver {
  late final TunerController _controller = TunerController(widget.engine);

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
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final reading = _controller.reading;
            final activeColor = reading == null
                ? GzColors.textSecondary
                : GzColors.forCents(reading.cents);
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                children: [
                  _Header(
                    tuningName: _controller.tuning.name,
                    isDemo: widget.isDemo,
                  ),
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
                        ),
                        const SizedBox(height: 28),
                        ZeroMeter(
                          cents: reading?.cents,
                          isInTune: reading?.isInTune ?? false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TunerHint(
                    status: _controller.status,
                    reading: reading,
                    onRetry: _controller.start,
                  ),
                  const Spacer(),
                  Expanded(
                    flex: 3,
                    child: StringBoard(
                      strings: _controller.tuning.strings,
                      activeString: _controller.activeString,
                      activeColor: activeColor,
                      tunedStrings: _controller.tunedStrings,
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
  const _Header({required this.tuningName, required this.isDemo});

  final String tuningName;
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    final label = Theme.of(context).textTheme.labelSmall;
    return Row(
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
        const Spacer(),
        if (isDemo) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: GzColors.off),
            ),
            child: Text('DEMO', style: label?.copyWith(color: GzColors.off)),
          ),
          const SizedBox(width: 12),
        ],
        Text(tuningName.toUpperCase(), style: label),
      ],
    );
  }
}
