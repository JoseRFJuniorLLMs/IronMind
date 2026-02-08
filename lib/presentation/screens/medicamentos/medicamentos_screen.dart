import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import '../../../data/models/medicamento.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/notification_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../core/constants/text_styles.dart';

class MedicamentosScreen extends StatefulWidget {
  const MedicamentosScreen({super.key});

  @override
  State<MedicamentosScreen> createState() => _MedicamentosScreenState();
}

class _MedicamentosScreenState extends State<MedicamentosScreen> {
  final Logger _logger = Logger();
  final ApiService _apiService = ApiService();
  final NotificationService _notificationService = NotificationService();

  List<Medicamento> _medicamentos = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _carregarMedicamentos();
  }

  Future<void> _carregarMedicamentos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final idosoId = StorageService.getIdosoId();
      if (idosoId == null) {
        throw Exception('ID do idoso nao encontrado');
      }

      final response = await _apiService.getMedicamentos(idosoId);

      if (response['success'] == true) {
        final lista = (response['medicamentos'] as List<dynamic>?)
            ?.map((e) => Medicamento.fromJson(e))
            .toList() ?? [];

        setState(() {
          _medicamentos = lista;
          _isLoading = false;
        });

        // Agenda lembretes para todos os medicamentos ativos
        for (final med in lista.where((m) => m.ativo)) {
          await _notificationService.agendarLembreteMedicamento(med);
        }
      } else {
        throw Exception(response['message'] ?? 'Erro ao carregar medicamentos');
      }
    } catch (e) {
      _logger.e('Erro ao carregar medicamentos: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
        // Dados de exemplo para desenvolvimento
        _medicamentos = _dadosExemplo();
      });
    }
  }

  List<Medicamento> _dadosExemplo() {
    return [
      Medicamento(
        id: 1,
        idosoId: 1,
        nome: 'Losartana',
        principioAtivo: 'Losartana Potassica',
        dosagem: '50',
        unidade: 'mg',
        frequencia: '1x ao dia',
        horarios: ['08:00'],
        instrucoes: 'Tomar em jejum',
        cor: '#2196F3',
        formato: 'comprimido',
        estoque: 25,
        estoqueMinimo: 10,
        ativo: true,
      ),
      Medicamento(
        id: 2,
        idosoId: 1,
        nome: 'Metformina',
        principioAtivo: 'Cloridrato de Metformina',
        dosagem: '850',
        unidade: 'mg',
        frequencia: '2x ao dia',
        horarios: ['08:00', '20:00'],
        instrucoes: 'Tomar apos as refeicoes',
        cor: '#4CAF50',
        formato: 'comprimido',
        estoque: 8,
        estoqueMinimo: 10,
        ativo: true,
      ),
      Medicamento(
        id: 3,
        idosoId: 1,
        nome: 'Rivotril',
        principioAtivo: 'Clonazepam',
        dosagem: '2',
        unidade: 'mg',
        frequencia: '1x ao dia',
        horarios: ['22:00'],
        instrucoes: 'Tomar antes de dormir',
        cor: '#9C27B0',
        formato: 'comprimido',
        estoque: 15,
        estoqueMinimo: 5,
        ativo: true,
      ),
    ];
  }

  Future<void> _confirmarTomada(Medicamento med) async {
    try {
      // Atualiza localmente
      setState(() {
        final index = _medicamentos.indexWhere((m) => m.id == med.id);
        if (index != -1) {
          _medicamentos[index] = med.copyWith(
            ultimaTomada: DateTime.now(),
            estoque: med.estoque > 0 ? med.estoque - 1 : 0,
          );
        }
      });

      // Envia para o backend
      await _apiService.registrarTomadaMedicamento(
        medicamentoId: med.id,
        status: 'tomado',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${med.nome} registrado!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _logger.e('Erro ao confirmar tomada: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'Meus Remedios',
          style: AppTextStyles.elderlySubtitle.copyWith(color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        toolbarHeight: 70, // Maior para melhor usabilidade
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 32),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, size: 32),
            onPressed: () => context.push('/medication-scanner'),
            tooltip: 'Escanear Medicamento',
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 32),
            onPressed: _mostrarDialogAdicionar,
            tooltip: 'Adicionar Medicamento',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _medicamentos.isEmpty
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medication_outlined, size: 100, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'Nenhum remedio cadastrado',
              style: AppTextStyles.elderlySubtitle.copyWith(
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Adicione seus remedios para receber lembretes',
              textAlign: TextAlign.center,
              style: AppTextStyles.elderlyBody.copyWith(
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 64, // Touch target minimo
              child: ElevatedButton.icon(
                onPressed: _mostrarDialogAdicionar,
                icon: const Icon(Icons.add, size: 28),
                label: const Text('Adicionar Remedio'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: AppTextStyles.elderlyButton,
                  backgroundColor: const Color(0xFF9F70D8),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    // Agrupa por horario
    final agora = DateTime.now();
    final proximoHorario = _medicamentos
        .where((m) => m.ativo && !m.tomouHoje)
        .toList();
    final jaTomados = _medicamentos
        .where((m) => m.ativo && m.tomouHoje)
        .toList();
    final inativos = _medicamentos.where((m) => !m.ativo).toList();

    return RefreshIndicator(
      onRefresh: _carregarMedicamentos,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Alerta de estoque baixo
          ..._buildAlertasEstoque(),

          // Proximos a tomar
          if (proximoHorario.isNotEmpty) ...[
            _buildSectionHeader('A Tomar', Icons.schedule, Colors.orange),
            ...proximoHorario.map((m) => _buildMedicamentoCard(m, false)),
            const SizedBox(height: 20),
          ],

          // Ja tomados hoje
          if (jaTomados.isNotEmpty) ...[
            _buildSectionHeader('Tomados Hoje', Icons.check_circle, Colors.green),
            ...jaTomados.map((m) => _buildMedicamentoCard(m, true)),
            const SizedBox(height: 20),
          ],

          // Inativos
          if (inativos.isNotEmpty) ...[
            _buildSectionHeader('Inativos', Icons.pause_circle, Colors.grey),
            ...inativos.map((m) => _buildMedicamentoCard(m, false, inativo: true)),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildAlertasEstoque() {
    final medicamentosEstoqueBaixo = _medicamentos.where((m) => m.estoqueBaixo && m.ativo).toList();

    if (medicamentosEstoqueBaixo.isEmpty) return [];

    return [
      Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange[700], size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estoque Baixo',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.orange[800],
                    ),
                  ),
                  Text(
                    medicamentosEstoqueBaixo.map((m) => m.nome).join(', '),
                    style: TextStyle(color: Colors.orange[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildSectionHeader(String titulo, IconData icon, Color cor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: cor, size: 24),
          const SizedBox(width: 8),
          Text(
            titulo,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicamentoCard(Medicamento med, bool tomado, {bool inativo = false}) {
    final cor = med.cor != null
        ? Color(int.parse(med.cor!.replaceFirst('#', '0xFF')))
        : Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: inativo ? 0 : 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Opacity(
        opacity: inativo ? 0.5 : 1.0,
        child: InkWell(
          onTap: () => _mostrarDetalhes(med),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icone colorido
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: cor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getIconeFormato(med.formato),
                    color: cor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med.nome,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${med.dosagem} ${med.unidade} - ${med.frequencia}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            med.horarios.join(', '),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                          ),
                          if (med.estoqueBaixo) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.inventory_2, size: 14, color: Colors.orange[600]),
                            const SizedBox(width: 4),
                            Text(
                              '${med.estoque}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Botao de acao
                if (!inativo)
                  tomado
                      ? Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.check, color: Colors.green[600], size: 28),
                        )
                      : ElevatedButton(
                          onPressed: () => _confirmarTomada(med),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cor,
                            foregroundColor: Colors.white,
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(12),
                          ),
                          child: const Icon(Icons.check, size: 28),
                        ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconeFormato(String? formato) {
    switch (formato?.toLowerCase()) {
      case 'comprimido':
        return Icons.medication;
      case 'capsula':
        return Icons.medication_liquid;
      case 'liquido':
        return Icons.local_drink;
      case 'injecao':
        return Icons.vaccines;
      case 'pomada':
        return Icons.spa;
      default:
        return Icons.medication;
    }
  }

  void _mostrarDetalhes(Medicamento med) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              med.nome,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            if (med.principioAtivo != null) ...[
              const SizedBox(height: 4),
              Text(
                med.principioAtivo!,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 20),
            _buildDetalheRow(Icons.straighten, 'Dosagem', '${med.dosagem} ${med.unidade}'),
            _buildDetalheRow(Icons.repeat, 'Frequencia', med.frequencia),
            _buildDetalheRow(Icons.schedule, 'Horarios', med.horarios.join(', ')),
            if (med.instrucoes != null)
              _buildDetalheRow(Icons.info_outline, 'Instrucoes', med.instrucoes!),
            _buildDetalheRow(Icons.inventory_2, 'Estoque', '${med.estoque} unidades'),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _mostrarDialogEditar(med);
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Editar'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmarTomada(med);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Tomar Agora'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetalheRow(IconData icon, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogAdicionar() {
    _mostrarDialogEditar(null);
  }

  void _mostrarDialogEditar(Medicamento? med) {
    final nomeController = TextEditingController(text: med?.nome ?? '');
    final dosagemController = TextEditingController(text: med?.dosagem ?? '');
    final instrucoesController = TextEditingController(text: med?.instrucoes ?? '');
    String unidade = med?.unidade ?? 'mg';
    List<String> horarios = List.from(med?.horarios ?? ['08:00']);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(med == null ? 'Novo Medicamento' : 'Editar Medicamento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do Medicamento',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: dosagemController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Dosagem',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: unidade,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: ['mg', 'ml', 'g', 'UI', 'gotas', 'comprimido']
                            .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (v) => setDialogState(() => unidade = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: instrucoesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Instrucoes (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Horarios:', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ...horarios.map((h) => Chip(
                      label: Text(h),
                      onDeleted: horarios.length > 1
                          ? () => setDialogState(() => horarios.remove(h))
                          : null,
                    )),
                    ActionChip(
                      label: const Icon(Icons.add, size: 18),
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null) {
                          setDialogState(() {
                            horarios.add(
                              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                            );
                            horarios.sort();
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nomeController.text.isEmpty || dosagemController.text.isEmpty) {
                  return;
                }

                final novoMed = Medicamento(
                  id: med?.id ?? DateTime.now().millisecondsSinceEpoch,
                  idosoId: StorageService.getIdosoId() ?? 0,
                  nome: nomeController.text,
                  dosagem: dosagemController.text,
                  unidade: unidade,
                  frequencia: '${horarios.length}x ao dia',
                  horarios: horarios,
                  instrucoes: instrucoesController.text.isEmpty ? null : instrucoesController.text,
                  ativo: true,
                  estoque: med?.estoque ?? 30,
                  estoqueMinimo: med?.estoqueMinimo ?? 5,
                );

                Navigator.pop(context);

                // Atualiza lista local
                setState(() {
                  if (med != null) {
                    final index = _medicamentos.indexWhere((m) => m.id == med.id);
                    if (index != -1) {
                      _medicamentos[index] = novoMed;
                    }
                  } else {
                    _medicamentos.add(novoMed);
                  }
                });

                // Agenda lembretes
                await _notificationService.agendarLembreteMedicamento(novoMed);

                // Salva no backend
                try {
                  if (med != null) {
                    await _apiService.atualizarMedicamento(novoMed);
                  } else {
                    await _apiService.criarMedicamento(novoMed);
                  }
                } catch (e) {
                  _logger.e('Erro ao salvar medicamento: $e');
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
