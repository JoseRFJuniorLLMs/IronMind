import 'dart:convert';
import 'package:flutter/material.dart';
import '../data/services/websocket_service.dart';
import '../screens/medication_scanner_screen.dart';

/// Handler para processar comandos de scanner de medicamentos via WebSocket
class MedicationScannerHandler {
  static final MedicationScannerHandler _instance = MedicationScannerHandler._internal();

  factory MedicationScannerHandler() => _instance;

  MedicationScannerHandler._internal();

  /// Inicializa o listener de mensagens WebSocket
  void initialize(BuildContext context) {
    final webSocketService = WebSocketService();

    // Escutar todas as mensagens do WebSocket
    webSocketService.messages.listen((message) {
      try {
        final decoded = jsonDecode(message as String);

        if (decoded is Map<String, dynamic>) {
          final action = decoded['action'] as String?;

          // Detectar comando para abrir scanner de medicamentos
          if (action == 'open_medication_scanner') {
            _handleOpenScanner(context, decoded);
          }
        }
      } catch (e) {
        print('Erro ao processar mensagem de medicação: $e');
      }
    });
  }

  /// Processa o comando de abertura do scanner
  void _handleOpenScanner(BuildContext context, Map<String, dynamic> data) {
    final sessionId = data['session_id'] as String?;
    final candidateMedications = data['candidate_medications'] as List<dynamic>? ?? [];
    final instructions = data['instructions'] as String? ?? 'Aponte a câmera para os frascos de medicamento';

    if (sessionId == null) {
      print('❌ session_id não fornecido no comando open_medication_scanner');
      return;
    }

    // Navegar para a tela do scanner
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MedicationScannerScreen(
          sessionId: sessionId,
          candidateMedications: candidateMedications,
          instructions: instructions,
        ),
        fullscreenDialog: true,
      ),
    ).then((result) {
      // Processar resultado quando voltar da tela
      if (result != null && result is Map<String, dynamic>) {
        final confirmed = result['confirmed'] as bool? ?? false;

        if (confirmed) {
          print('✅ Medicamento confirmado pelo paciente');
        } else {
          print('❌ Scan cancelado pelo paciente');
        }
      }
    });
  }

  /// Método estático para fácil acesso
  static void setup(BuildContext context) {
    MedicationScannerHandler().initialize(context);
  }
}
