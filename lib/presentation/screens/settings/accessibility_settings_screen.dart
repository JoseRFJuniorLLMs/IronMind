import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/accessibility_provider.dart';

/// Tela de configuracoes de acessibilidade
/// Permite ajustar fonte, contraste e outras preferencias
class AccessibilitySettingsScreen extends StatelessWidget {
  const AccessibilitySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AccessibilityProvider>(
      builder: (context, accessibility, child) {
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF9F70D8),
                  Color(0xFFFFB6C1),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => context.pop(),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Acessibilidade',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Configuracoes
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Secao: Texto
                          _buildSectionHeader('Texto'),
                          const SizedBox(height: 8),

                          _buildSettingTile(
                            icon: Icons.format_size,
                            title: 'Texto Grande',
                            subtitle: 'Aumenta o tamanho de todas as letras',
                            value: accessibility.isLargeText,
                            onChanged: (_) => accessibility.toggleLargeText(),
                          ),

                          _buildSettingTile(
                            icon: Icons.format_bold,
                            title: 'Texto em Negrito',
                            subtitle: 'Deixa todas as letras mais grossas',
                            value: accessibility.isBoldText,
                            onChanged: (_) => accessibility.toggleBoldText(),
                          ),

                          const Divider(height: 32),

                          // Secao: Visual
                          _buildSectionHeader('Visual'),
                          const SizedBox(height: 8),

                          _buildSettingTile(
                            icon: Icons.contrast,
                            title: 'Alto Contraste',
                            subtitle: 'Cores mais fortes para melhor visibilidade',
                            value: accessibility.isHighContrast,
                            onChanged: (_) => accessibility.toggleHighContrast(),
                          ),

                          _buildSettingTile(
                            icon: Icons.motion_photos_off,
                            title: 'Reduzir Animacoes',
                            subtitle: 'Remove efeitos de movimento',
                            value: accessibility.isReduceMotion,
                            onChanged: (_) => accessibility.toggleReduceMotion(),
                          ),

                          const Divider(height: 32),

                          // Secao: Interacao
                          _buildSectionHeader('Interacao'),
                          const SizedBox(height: 8),

                          _buildSettingTile(
                            icon: Icons.mic,
                            title: 'Comandos de Voz',
                            subtitle: 'Controlar o app falando',
                            value: accessibility.isVoiceEnabled,
                            onChanged: (_) => accessibility.toggleVoiceEnabled(),
                          ),

                          const Divider(height: 32),

                          // Tamanho da Fonte (Slider)
                          _buildSectionHeader('Tamanho da Fonte'),
                          const SizedBox(height: 16),

                          _buildFontSizePreview(accessibility.effectiveTextScale),

                          Slider(
                            value: accessibility.effectiveTextScale,
                            min: 0.8,
                            max: 2.0,
                            divisions: 12,
                            activeColor: const Color(0xFF9F70D8),
                            onChanged: (value) {
                              accessibility.setTextScaleFactor(value);
                            },
                          ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text('Pequeno', style: TextStyle(fontSize: 14)),
                              Text('Grande', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // Botao Reset
                          Center(
                            child: TextButton.icon(
                              onPressed: () => _showResetDialog(context, accessibility),
                              icon: const Icon(Icons.restore, color: Colors.grey),
                              label: const Text(
                                'Restaurar Padrao',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Color(0xFF9F70D8),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF9F70D8).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF9F70D8),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 1.2,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF9F70D8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontSizePreview(double scale) {
    final previewSize = 18 * scale;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Center(
        child: Text(
          'Exemplo de Texto',
          style: TextStyle(
            fontSize: previewSize,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context, AccessibilityProvider accessibility) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar Padrao?'),
        content: const Text(
          'Isso vai resetar todas as configuracoes de acessibilidade para o padrao.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              accessibility.resetToDefaults();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Configuracoes restauradas'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9F70D8),
            ),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
  }
}
