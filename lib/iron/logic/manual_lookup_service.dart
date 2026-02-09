import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:yaml/yaml.dart';
import '../detection/yolo_engine.dart';

/// Entrada do manual para um componente específico
class ManualEntry {
  final String className;
  final String nome;
  final String estado;
  final String fala;
  final String acao;
  final String? severidade;
  final String? prazo;
  final String? pecas;
  final String? intervalo;
  final String? especificacao;
  final String? aviso;

  ManualEntry({
    required this.className,
    required this.nome,
    required this.estado,
    required this.fala,
    required this.acao,
    this.severidade,
    this.prazo,
    this.pecas,
    this.intervalo,
    this.especificacao,
    this.aviso,
  });

  bool get isDefect => estado == 'defeito';
  bool get isCritical => severidade == 'critica';
  bool get isImmediate => prazo == 'imediato';

  /// Texto completo para TTS (fala + acao resumida)
  String get ttsText {
    if (isDefect) {
      return '$fala Acao recomendada: $acao';
    }
    return fala;
  }

  /// Texto curto para TTS (só a fala)
  String get ttsShort => fala;

  /// Texto para overlay na tela
  String get displayText => fala;

  /// Cor sugerida baseada na severidade
  String get severityColor {
    switch (severidade) {
      case 'critica':
        return 'red';
      case 'alta':
        return 'orange';
      case 'media':
        return 'yellow';
      case 'baixa':
        return 'blue';
      default:
        return 'green';
    }
  }
}

/// Serviço de lookup de manuais técnicos
/// Carrega YAMLs estruturados e mapeia classes YOLO → texto de manual
class ManualLookupService {
  // Cache: className → ManualEntry
  final Map<String, ManualEntry> _entries = {};

  // Manuais carregados por tipo de equipamento
  final Map<String, Map<String, ManualEntry>> _manualsByType = {};

  bool _isLoaded = false;
  String _currentEquipmentType = 'universal';

  bool get isLoaded => _isLoaded;
  int get entryCount => _entries.length;

  /// Lista de YAMLs de manuais disponíveis
  static const List<String> _manualAssets = [
    'assets/config/manuals/universal.yaml',
    'assets/config/manuals/trator.yaml',
    'assets/config/manuals/caminhao.yaml',
    'assets/config/manuals/mineracao.yaml',
    'assets/config/manuals/escavadeira.yaml',
  ];

  /// Carrega todos os manuais YAML dos assets
  Future<void> initialize() async {
    if (_isLoaded) return;

    debugPrint('[ManualLookup] Carregando manuais...');

    for (final assetPath in _manualAssets) {
      try {
        final yamlString = await rootBundle.loadString(assetPath);
        final yamlDoc = loadYaml(yamlString);

        if (yamlDoc is YamlMap) {
          final equipType = yamlDoc['equipamento']?.toString() ?? 'unknown';
          final componentes = yamlDoc['componentes'];

          if (componentes is YamlMap) {
            final typeEntries = <String, ManualEntry>{};

            for (final key in componentes.keys) {
              final comp = componentes[key];
              if (comp is YamlMap) {
                final entry = ManualEntry(
                  className: key.toString(),
                  nome: comp['nome']?.toString() ?? key.toString(),
                  estado: comp['estado']?.toString() ?? 'unknown',
                  fala: comp['fala']?.toString() ?? '',
                  acao: comp['acao']?.toString() ?? '',
                  severidade: comp['severidade']?.toString(),
                  prazo: comp['prazo']?.toString(),
                  pecas: comp['pecas']?.toString(),
                  intervalo: comp['intervalo']?.toString(),
                  especificacao: comp['especificacao']?.toString(),
                  aviso: comp['aviso']?.toString(),
                );

                typeEntries[key.toString()] = entry;
                // Universal entra no cache global diretamente
                // Específicos sobrescrevem universal quando tipo selecionado
                _entries[key.toString()] = entry;
              }
            }

            _manualsByType[equipType] = typeEntries;
            debugPrint('[ManualLookup] $assetPath: ${typeEntries.length} componentes ($equipType)');
          }
        }
      } catch (e) {
        debugPrint('[ManualLookup] Erro ao carregar $assetPath: $e');
      }
    }

    _isLoaded = true;
    debugPrint('[ManualLookup] ${_entries.length} entradas carregadas');
  }

  /// Define tipo de equipamento ativo (prioriza manual específico)
  void setEquipmentType(String type) {
    _currentEquipmentType = type.toLowerCase();
    _rebuildCache();
    debugPrint('[ManualLookup] Tipo de equipamento: $_currentEquipmentType');
  }

  /// Reconstrói cache priorizando manual do tipo selecionado
  void _rebuildCache() {
    _entries.clear();

    // 1. Carrega universal como base
    final universal = _manualsByType['universal'];
    if (universal != null) {
      _entries.addAll(universal);
    }

    // 2. Sobrescreve com específico do tipo
    final specific = _manualsByType[_currentEquipmentType];
    if (specific != null) {
      _entries.addAll(specific);
    }

    // 3. Se escavadeira, carrega mineracao tambem
    if (_currentEquipmentType == 'escavadeira') {
      final mineracao = _manualsByType['mineracao'];
      if (mineracao != null) {
        _entries.addAll(mineracao);
      }
    }
  }

  /// Busca entrada do manual para uma classe YOLO
  ManualEntry? lookup(String className) {
    return _entries[className];
  }

  /// Busca entrada do manual para uma detecção
  ManualEntry? lookupDetection(Detection detection) {
    return _entries[detection.className];
  }

  /// Gera texto TTS para uma lista de detecções
  /// Retorna texto resumido priorizando defeitos
  String generateTTS(List<Detection> detections) {
    if (detections.isEmpty) {
      return 'Nenhum componente detectado no campo de visao.';
    }

    final defects = <ManualEntry>[];
    final okItems = <ManualEntry>[];

    for (final det in detections) {
      final entry = lookupDetection(det);
      if (entry != null) {
        if (entry.isDefect) {
          defects.add(entry);
        } else {
          okItems.add(entry);
        }
      }
    }

    final buffer = StringBuffer();

    // Defeitos críticos primeiro
    final criticals = defects.where((e) => e.isCritical).toList();
    final others = defects.where((e) => !e.isCritical).toList();

    if (criticals.isNotEmpty) {
      for (final d in criticals) {
        buffer.writeln(d.ttsText);
      }
    }

    if (others.isNotEmpty) {
      for (final d in others) {
        buffer.writeln(d.ttsShort);
      }
    }

    // Componentes OK (resumido)
    if (okItems.isNotEmpty && defects.isEmpty) {
      if (okItems.length == 1) {
        buffer.write(okItems.first.ttsShort);
      } else {
        buffer.write('${okItems.length} componentes inspecionados. Todos em bom estado.');
      }
    } else if (okItems.isNotEmpty) {
      buffer.write('${okItems.length} componentes OK.');
    }

    return buffer.toString().trim();
  }

  /// Gera texto resumido para overlay na tela
  String generateDisplayText(List<Detection> detections) {
    if (detections.isEmpty) return '';

    final texts = <String>[];
    for (final det in detections) {
      final entry = lookupDetection(det);
      if (entry != null && entry.isDefect) {
        final conf = (det.confidence * 100).toInt();
        texts.add('${entry.nome}: ${entry.fala} ($conf%)');
      }
    }

    if (texts.isEmpty) {
      // Se só tem OKs, mostra resumo
      final okEntry = lookupDetection(detections.first);
      if (okEntry != null) {
        return okEntry.nome;
      }
    }

    return texts.join('\n');
  }
}
