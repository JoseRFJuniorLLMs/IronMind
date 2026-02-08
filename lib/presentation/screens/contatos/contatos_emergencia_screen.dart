import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/models/contato_emergencia.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../core/constants/text_styles.dart';

class ContatosEmergenciaScreen extends StatefulWidget {
  const ContatosEmergenciaScreen({super.key});

  @override
  State<ContatosEmergenciaScreen> createState() =>
      _ContatosEmergenciaScreenState();
}

class _ContatosEmergenciaScreenState extends State<ContatosEmergenciaScreen> {
  final Logger _logger = Logger();
  final ApiService _apiService = ApiService();

  List<ContatoEmergencia> _contatos = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _carregarContatos();
  }

  Future<void> _carregarContatos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final idosoId = StorageService.getIdosoId();
      if (idosoId == null) {
        throw Exception('ID do idoso nao encontrado');
      }

      final response = await _apiService.getContatosEmergencia(idosoId);

      if (response['success'] == true) {
        final lista = (response['contatos'] as List<dynamic>?)
                ?.map((e) => ContatoEmergencia.fromJson(e))
                .toList() ??
            [];

        setState(() {
          _contatos = lista
            ..sort((a, b) => a.prioridade.compareTo(b.prioridade));
          _isLoading = false;
        });
      } else {
        throw Exception(response['message'] ?? 'Erro ao carregar contatos');
      }
    } catch (e) {
      _logger.e('Erro ao carregar contatos: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
        // Dados de exemplo para desenvolvimento
        _contatos = _dadosExemplo();
      });
    }
  }

  List<ContatoEmergencia> _dadosExemplo() {
    return [
      ContatoEmergencia(
        id: 1,
        idosoId: 1,
        nome: 'Maria Silva',
        telefone: '+5511999999999',
        email: 'maria@email.com',
        parentesco: 'Filha',
        prioridade: 1,
        recebeAlertas: true,
        recebeRelatorios: true,
        canaisHabilitados: ['push', 'sms', 'whatsapp', 'call'],
        ativo: true,
      ),
      ContatoEmergencia(
        id: 2,
        idosoId: 1,
        nome: 'Joao Silva',
        telefone: '+5511888888888',
        email: 'joao@email.com',
        parentesco: 'Filho',
        prioridade: 2,
        recebeAlertas: true,
        recebeRelatorios: false,
        canaisHabilitados: ['push', 'sms'],
        ativo: true,
      ),
      ContatoEmergencia(
        id: 3,
        idosoId: 1,
        nome: 'Dr. Carlos Medico',
        telefone: '+5511777777777',
        parentesco: 'Medico',
        prioridade: 3,
        recebeAlertas: true,
        recebeRelatorios: true,
        canaisHabilitados: ['sms', 'email'],
        horarioNaoPerturbeInicio: '22:00',
        horarioNaoPerturbeEnd: '07:00',
        ativo: true,
      ),
    ];
  }

  Future<void> _ligarPara(String telefone) async {
    final uri = Uri.parse('tel:$telefone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _enviarWhatsApp(String telefone) async {
    // Remove caracteres nao numericos
    final numero = telefone.replaceAll(RegExp(r'[^\d]'), '');
    final uri = Uri.parse('https://wa.me/$numero');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'Minha Familia',
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
            icon: const Icon(Icons.person_add, size: 32),
            onPressed: _mostrarDialogAdicionar,
            tooltip: 'Adicionar Contato',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contatos.isEmpty
              ? _buildEmptyState()
              : _buildContent(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 100, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text(
              'Nenhum contato cadastrado',
              style: AppTextStyles.elderlySubtitle.copyWith(
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Adicione familiares e cuidadores para receber alertas',
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
                icon: const Icon(Icons.person_add, size: 28),
                label: const Text('Adicionar Contato'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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
    return RefreshIndicator(
      onRefresh: _carregarContatos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _contatos.length,
        itemBuilder: (context, index) {
          final contato = _contatos[index];
          return _buildContatoCard(contato, index + 1);
        },
      ),
    );
  }

  Widget _buildContatoCard(ContatoEmergencia contato, int ordem) {
    final corPrioridade = contato.prioridade == 1
        ? Colors.red
        : contato.prioridade == 2
            ? Colors.orange
            : Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _mostrarDetalhes(contato),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // Numero de prioridade
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: corPrioridade,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$ordem',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                contato.nome,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (contato.emHorarioNaoPerturbe)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.do_not_disturb,
                                        size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Nao perturbe',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          contato.parentesco,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          contato.telefone,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Canais habilitados
              Row(
                children: [
                  _buildCanalChip('Push', Icons.notifications,
                      contato.canaisHabilitados.contains('push')),
                  _buildCanalChip('SMS', Icons.sms,
                      contato.canaisHabilitados.contains('sms')),
                  _buildCanalChip('WhatsApp', Icons.chat,
                      contato.canaisHabilitados.contains('whatsapp')),
                  _buildCanalChip('Email', Icons.email,
                      contato.canaisHabilitados.contains('email')),
                  _buildCanalChip('Ligacao', Icons.call,
                      contato.canaisHabilitados.contains('call')),
                ],
              ),
              const SizedBox(height: 12),
              // Botoes de acao rapida
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAcaoButton(
                    icon: Icons.call,
                    color: Colors.green,
                    onTap: () => _ligarPara(contato.telefone),
                  ),
                  _buildAcaoButton(
                    icon: Icons.chat,
                    color: const Color(0xFF25D366),
                    onTap: () => _enviarWhatsApp(contato.telefone),
                  ),
                  _buildAcaoButton(
                    icon: Icons.edit,
                    color: Colors.blue,
                    onTap: () => _mostrarDialogEditar(contato),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCanalChip(String label, IconData icon, bool ativo) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: ativo ? Colors.green[50] : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: ativo ? Colors.green[200]! : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: ativo ? Colors.green[600] : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcaoButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 28, color: color),
      ),
    );
  }

  void _mostrarDetalhes(ContatoEmergencia contato) {
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
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    contato.nome.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contato.nome,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        contato.parentesco,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildInfoRow(Icons.phone, 'Telefone', contato.telefone),
            if (contato.email != null)
              _buildInfoRow(Icons.email, 'Email', contato.email!),
            _buildInfoRow(
              Icons.notifications,
              'Recebe alertas',
              contato.recebeAlertas ? 'Sim' : 'Nao',
            ),
            _buildInfoRow(
              Icons.description,
              'Recebe relatorios',
              contato.recebeRelatorios ? 'Sim' : 'Nao',
            ),
            if (contato.horarioNaoPerturbeInicio != null)
              _buildInfoRow(
                Icons.do_not_disturb,
                'Nao perturbe',
                '${contato.horarioNaoPerturbeInicio} - ${contato.horarioNaoPerturbeEnd}',
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      final confirmar = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Remover contato?'),
                          content: Text(
                              'Deseja remover ${contato.nome} da lista de contatos de emergencia?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancelar'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.red),
                              child: const Text('Remover'),
                            ),
                          ],
                        ),
                      );
                      if (confirmar == true) {
                        setState(() {
                          _contatos.removeWhere((c) => c.id == contato.id);
                        });
                        try {
                          await _apiService
                              .removerContatoEmergencia(contato.id);
                        } catch (e) {
                          _logger.e('Erro ao remover contato: $e');
                        }
                      }
                    },
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('Remover',
                        style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _ligarPara(contato.telefone);
                    },
                    icon: const Icon(Icons.call),
                    label: const Text('Ligar Agora'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
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

  Widget _buildInfoRow(IconData icon, String label, String valor) {
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

  void _mostrarDialogEditar(ContatoEmergencia? contato) {
    final nomeController = TextEditingController(text: contato?.nome ?? '');
    final telefoneController =
        TextEditingController(text: contato?.telefone ?? '');
    final emailController = TextEditingController(text: contato?.email ?? '');
    String parentesco = contato?.parentesco ?? 'Filho(a)';
    bool recebeAlertas = contato?.recebeAlertas ?? true;
    bool recebeRelatorios = contato?.recebeRelatorios ?? false;
    List<String> canais =
        List.from(contato?.canaisHabilitados ?? ['push', 'sms', 'whatsapp']);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(contato == null ? 'Novo Contato' : 'Editar Contato'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome completo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: telefoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefone',
                    hintText: '+55 11 99999-9999',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: parentesco,
                  decoration: const InputDecoration(
                    labelText: 'Parentesco',
                    border: OutlineInputBorder(),
                  ),
                  items: ParentescoOpcoes.opcoes
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => parentesco = v!),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Recebe alertas'),
                  subtitle: const Text('Sera notificado em emergencias'),
                  value: recebeAlertas,
                  onChanged: (v) => setDialogState(() => recebeAlertas = v),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Recebe relatorios'),
                  subtitle: const Text('Resumos semanais de saude'),
                  value: recebeRelatorios,
                  onChanged: (v) => setDialogState(() => recebeRelatorios = v),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                const Text('Canais de contato:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildCanalToggle('Push', 'push', canais, setDialogState),
                    _buildCanalToggle('SMS', 'sms', canais, setDialogState),
                    _buildCanalToggle(
                        'WhatsApp', 'whatsapp', canais, setDialogState),
                    _buildCanalToggle('Email', 'email', canais, setDialogState),
                    _buildCanalToggle(
                        'Ligacao', 'call', canais, setDialogState),
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
                if (nomeController.text.isEmpty ||
                    telefoneController.text.isEmpty) {
                  return;
                }

                final novoContato = ContatoEmergencia(
                  id: contato?.id ?? DateTime.now().millisecondsSinceEpoch,
                  idosoId: StorageService.getIdosoId() ?? 0,
                  nome: nomeController.text,
                  telefone: telefoneController.text,
                  email: emailController.text.isEmpty
                      ? null
                      : emailController.text,
                  parentesco: parentesco,
                  prioridade: contato?.prioridade ?? (_contatos.length + 1),
                  recebeAlertas: recebeAlertas,
                  recebeRelatorios: recebeRelatorios,
                  canaisHabilitados: canais,
                  ativo: true,
                );

                Navigator.pop(context);

                // Atualiza lista local
                setState(() {
                  if (contato != null) {
                    final index =
                        _contatos.indexWhere((c) => c.id == contato.id);
                    if (index != -1) {
                      _contatos[index] = novoContato;
                    }
                  } else {
                    _contatos.add(novoContato);
                  }
                  _contatos
                      .sort((a, b) => a.prioridade.compareTo(b.prioridade));
                });

                // Salva no backend
                try {
                  if (contato != null) {
                    await _apiService.atualizarContatoEmergencia(novoContato);
                  } else {
                    await _apiService.criarContatoEmergencia(novoContato);
                  }
                } catch (e) {
                  _logger.e('Erro ao salvar contato: $e');
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanalToggle(
    String label,
    String value,
    List<String> canais,
    StateSetter setDialogState,
  ) {
    final ativo = canais.contains(value);
    return FilterChip(
      label: Text(label),
      selected: ativo,
      onSelected: (selected) {
        setDialogState(() {
          if (selected) {
            canais.add(value);
          } else {
            canais.remove(value);
          }
        });
      },
    );
  }
}
