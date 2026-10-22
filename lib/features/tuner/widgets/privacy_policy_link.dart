import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre a política no navegador, sem carregar conteúdo remoto no afinador.
class PrivacyPolicyLink extends StatelessWidget {
  const PrivacyPolicyLink({super.key});

  static const policyUrl = 'https://guitarzero.com.br/privacidade.html';

  Future<void> _openPolicy(BuildContext context) async {
    try {
      if (await launchUrl(
        Uri.parse(policyUrl),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } on Exception {
      // Mantém o link disponível se o sistema não conseguir abrir o navegador.
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Não foi possível abrir o navegador.'),
        action: SnackBarAction(
          label: 'Copiar link',
          onPressed: () =>
              Clipboard.setData(const ClipboardData(text: policyUrl)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => _openPolicy(context),
      icon: const Icon(Icons.privacy_tip_outlined, size: 18),
      label: const Text('Política de privacidade'),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.centerLeft,
      ),
    );
  }
}
