import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';

import '../../../data/services/api_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/models/agendamento.dart';
import '../../../core/constants/text_styles.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  final Logger _logger = Logger();
  final ApiService _apiService = ApiService();

  // ✅ FIX: Controlador de tabs para mostrar histórico
  late TabController _tabController;

  DateTime _selectedDate = DateTime.now();
  DateTime _displayedMonth = DateTime.now(); // ✅ FIX: Mês exibido no header
  TimeOfDay _selectedTime = TimeOfDay.now();

  // ✅ FIX: Seleção de tipo e prioridade
  String _selectedTipo = 'chamada_voz';
  String _selectedPrioridade = 'normal';

  // ✅ FIX: Listas separadas para agendados e histórico
  List<Agendamento> _agendados = [];
  List<Agendamento> _historico = [];

  bool _isLoading = false;
  String? _errorMessage;
  int _retryCount = 0; // ✅ FIX: Contador de retry

  // ✅ Opções de tipo de chamada
  final List<Map<String, dynamic>> _tipoOptions = [
    {'value': 'chamada_voz', 'label': 'Chamada de Voz', 'icon': Icons.phone},
    {'value': 'chamada_video', 'label': 'Chamada de Vídeo', 'icon': Icons.videocam},
  ];

  // ✅ Opções de prioridade
  final List<Map<String, dynamic>> _prioridadeOptions = [
    {'value': 'normal', 'label': 'Normal', 'color': Colors.green},
    {'value': 'alta', 'label': 'Alta', 'color': Colors.orange},
    {'value': 'urgente', 'label': 'Urgente', 'color': Colors.red},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAgendamentos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAgendamentos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final idosoId = StorageService.getOperatorId();

      if (idosoId == null) {
        throw Exception('ID do idoso não encontrado');
      }

      final data = await _apiService.listAgendamentos(idosoId);

      final allAppointments =
          data.map((json) => Agendamento.fromJson(json)).toList();

      setState(() {
        // ✅ FIX: Separar agendados de histórico (todos os outros status)
        _agendados = allAppointments
            .where((a) => a.status == 'agendado')
            .toList()
          ..sort((a, b) => a.dataHoraAgendada.compareTo(b.dataHoraAgendada));

        _historico = allAppointments
            .where((a) => a.status != 'agendado')
            .toList()
          ..sort((a, b) => b.dataHoraAgendada.compareTo(a.dataHoraAgendada)); // Mais recentes primeiro

        _retryCount = 0; // Reset retry count on success
      });
    } catch (e) {
      _logger.e('❌ Erro ao carregar agendamentos: $e');
      setState(() {
        _errorMessage = 'Erro ao carregar agendamentos';
        _retryCount++;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF9F70D8), // Roxo
              Color(0xFFFFB6C1), // Rosa claro
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Calendar Card
              _buildCalendarCard(),

              // ✅ FIX: Time + Tipo + Prioridade selectors
              _buildOptionsRow(),

              const SizedBox(height: 12),

              // Schedule Button
              _buildScheduleButton(),

              const SizedBox(height: 16),

              // ✅ FIX: Appointments List com Tabs (Agendados + Histórico)
              Expanded(child: _buildAppointmentsTabs()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Voltar',
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
              onPressed: () => context.pop(),
            ),
          ),
          Text(
            'Agenda',
            style: AppTextStyles.elderlySubtitle.copyWith(color: Colors.white),
          ),
          const Spacer(),
          Semantics(
            button: true,
            label: 'Atualizar lista',
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white, size: 32),
              onPressed: _isLoading ? null : _loadAgendamentos,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard() {
    // Garantir que a data inicial seja valida (hoje ou futuro)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final validInitialDate = _selectedDate.isBefore(today) ? today : _selectedDate;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // Header do mes com navegacao
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Botao mes anterior (desabilitado se for mes atual)
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 32),
                    onPressed: _canGoToPreviousMonth()
                        ? () {
                            setState(() {
                              _displayedMonth = DateTime(
                                _displayedMonth.year,
                                _displayedMonth.month - 1,
                              );
                              // NAO resetar _selectedDate ao navegar
                            });
                          }
                        : null,
                  ),
                  // Titulo do mes
                  Semantics(
                    label: 'Mes selecionado',
                    child: Text(
                      DateFormat('MMMM yyyy', 'pt_BR').format(_displayedMonth),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Botao proximo mes
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 32),
                    onPressed: () {
                      setState(() {
                        _displayedMonth = DateTime(
                          _displayedMonth.year,
                          _displayedMonth.month + 1,
                        );
                        // NAO resetar _selectedDate ao navegar
                      });
                    },
                  ),
                ],
              ),

              // Calendario
              SizedBox(
                height: 280,
                child: CalendarDatePicker(
                  initialDate: validInitialDate,
                  currentDate: today, // currentDate = data de HOJE (circulo azul)
                  firstDate: today,
                  lastDate: today.add(const Duration(days: 365)),
                  onDateChanged: (date) {
                    setState(() {
                      _selectedDate = date;
                      // Atualizar o mes exibido se o usuario selecionou um mes diferente
                      if (date.month != _displayedMonth.month ||
                          date.year != _displayedMonth.year) {
                        _displayedMonth = DateTime(date.year, date.month);
                      }
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Verifica se pode voltar ao mes anterior (nao pode ser antes do mes atual)
  bool _canGoToPreviousMonth() {
    final now = DateTime.now();
    return _displayedMonth.year > now.year ||
        (_displayedMonth.year == now.year && _displayedMonth.month > now.month);
  }

  // ✅ FIX: Nova row com Time, Tipo e Prioridade
  Widget _buildOptionsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          // Time Picker
          Expanded(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: _pickTime,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      const Icon(Icons.access_time, color: Color(0xFF9F70D8)),
                      const SizedBox(height: 4),
                      Text(
                        _selectedTime.format(context),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('Horário', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // ✅ FIX: Tipo de Chamada
          Expanded(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: _showTipoSelector,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Icon(
                        _selectedTipo == 'chamada_video'
                            ? Icons.videocam
                            : Icons.phone,
                        color: const Color(0xFF9F70D8),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedTipo == 'chamada_video' ? 'Vídeo' : 'Voz',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('Tipo', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // ✅ FIX: Prioridade
          Expanded(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                onTap: _showPrioridadeSelector,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.flag,
                        color: _getPrioridadeColor(_selectedPrioridade),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedPrioridade.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getPrioridadeColor(_selectedPrioridade),
                        ),
                      ),
                      const Text('Prioridade', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }

  void _showTipoSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tipo de Chamada',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._tipoOptions.map((option) => ListTile(
                  leading: Icon(option['icon'], color: const Color(0xFF9F70D8)),
                  title: Text(option['label']),
                  trailing: _selectedTipo == option['value']
                      ? const Icon(Icons.check, color: Color(0xFF9F70D8))
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedTipo = option['value'];
                    });
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showPrioridadeSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Prioridade',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._prioridadeOptions.map((option) => ListTile(
                  leading: Icon(Icons.flag, color: option['color']),
                  title: Text(option['label']),
                  trailing: _selectedPrioridade == option['value']
                      ? Icon(Icons.check, color: option['color'])
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedPrioridade = option['value'];
                    });
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }

  Color _getPrioridadeColor(String prioridade) {
    switch (prioridade) {
      case 'urgente':
        return Colors.red;
      case 'alta':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  Widget _buildScheduleButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Semantics(
        button: true,
        label: 'Agendar chamada de ${_selectedTipo == 'chamada_video' ? 'video' : 'voz'}',
        hint: 'Toque para criar o agendamento',
        child: SizedBox(
          width: double.infinity,
          height: 64, // Touch target minimo para idosos
          child: ElevatedButton(
            onPressed: _isLoading ? null : _scheduleCall,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF9F70D8),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 4,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _selectedTipo == 'chamada_video'
                            ? Icons.videocam
                            : Icons.phone,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'AGENDAR',
                        style: AppTextStyles.elderlyButton.copyWith(
                          color: const Color(0xFF9F70D8),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ✅ FIX: Tabs para Agendados e Histórico
  Widget _buildAppointmentsTabs() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          // Tab Bar
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF9F70D8),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF9F70D8),
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.schedule, size: 18),
                    const SizedBox(width: 4),
                    Text('Agendados (${_agendados.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.history, size: 18),
                    const SizedBox(width: 4),
                    Text('Histórico (${_historico.length})'),
                  ],
                ),
              ),
            ],
          ),

          // ✅ FIX: Error message com Retry
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _loadAgendamentos,
                    icon: const Icon(Icons.refresh),
                    label: Text('Tentar Novamente ($_retryCount)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

          // Loading indicator
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Agendados
                  _buildAppointmentList(_agendados, isHistory: false),
                  // Tab 2: Histórico
                  _buildAppointmentList(_historico, isHistory: true),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppointmentList(List<Agendamento> appointments,
      {required bool isHistory}) {
    if (appointments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isHistory ? Icons.history : Icons.calendar_today,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 20),
              Text(
                isHistory
                    ? 'Nenhum historico de chamadas'
                    : 'Nenhuma chamada agendada',
                style: AppTextStyles.elderlyBody.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              if (!isHistory) ...[
                const SizedBox(height: 12),
                Text(
                  'Use o calendario acima para agendar',
                  style: AppTextStyles.elderlyCaption,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAgendamentos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: appointments.length,
        itemBuilder: (context, index) {
          final appointment = appointments[index];
          return _buildAppointmentCard(appointment, isHistory: isHistory);
        },
      ),
    );
  }

  Widget _buildAppointmentCard(Agendamento appointment,
      {required bool isHistory}) {
    final isOverdue = appointment.isOverdue;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(appointment.status)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    appointment.tipo == 'chamada_video'
                        ? Icons.videocam
                        : Icons.phone,
                    color: _getStatusColor(appointment.status),
                  ),
                ),
                const SizedBox(width: 12),

                // Date & Time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('dd/MM/yyyy')
                            .format(appointment.dataHoraAgendada),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        DateFormat('HH:mm')
                            .format(appointment.dataHoraAgendada),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),

                // ✅ FIX: Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(appointment.status)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusLabel(appointment.status),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(appointment.status),
                    ),
                  ),
                ),
              ],
            ),

            // ✅ FIX: Prioridade indicator
            if (appointment.prioridade != 'normal')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.flag,
                      size: 16,
                      color: _getPrioridadeColor(appointment.prioridade),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Prioridade ${appointment.prioridade}',
                      style: TextStyle(
                        fontSize: 12,
                        color: _getPrioridadeColor(appointment.prioridade),
                      ),
                    ),
                  ],
                ),
              ),

            // Overdue warning
            if (isOverdue && !isHistory)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  '⚠️ Atrasado',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),

            const SizedBox(height: 8),

            // ✅ FIX: Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isHistory) ...[
                  // ✅ FIX: Edit button
                  TextButton.icon(
                    onPressed: () => _showEditDialog(appointment),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Editar'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                    ),
                  ),

                  // ✅ FIX: Complete button
                  TextButton.icon(
                    onPressed: () => _confirmComplete(appointment),
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Concluir'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green,
                    ),
                  ),

                  // Cancel button
                  TextButton.icon(
                    onPressed: () => _confirmDelete(appointment),
                    icon: const Icon(Icons.cancel, size: 18),
                    label: const Text('Cancelar'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'agendado':
        return const Color(0xFF9F70D8);
      case 'concluido':
        return Colors.green;
      case 'cancelado':
        return Colors.red;
      case 'em_andamento':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'agendado':
        return 'Agendado';
      case 'concluido':
        return 'Concluído';
      case 'cancelado':
        return 'Cancelado';
      case 'em_andamento':
        return 'Em Andamento';
      default:
        return status;
    }
  }

  // ✅ FIX: Dialog de edição
  Future<void> _showEditDialog(Agendamento appointment) async {
    DateTime editDate = appointment.dataHoraAgendada;
    TimeOfDay editTime = TimeOfDay(
      hour: appointment.dataHoraAgendada.hour,
      minute: appointment.dataHoraAgendada.minute,
    );
    String editTipo = appointment.tipo;
    String editPrioridade = appointment.prioridade;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar Agendamento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Date
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(DateFormat('dd/MM/yyyy').format(editDate)),
                  subtitle: const Text('Data'),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: editDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setDialogState(() => editDate = date);
                    }
                  },
                ),

                // Time
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text(editTime.format(context)),
                  subtitle: const Text('Horário'),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: editTime,
                    );
                    if (time != null) {
                      setDialogState(() => editTime = time);
                    }
                  },
                ),

                // Tipo
                ListTile(
                  leading: Icon(
                    editTipo == 'chamada_video' ? Icons.videocam : Icons.phone,
                  ),
                  title: Text(
                    editTipo == 'chamada_video' ? 'Vídeo' : 'Voz',
                  ),
                  subtitle: const Text('Tipo de Chamada'),
                  onTap: () {
                    setDialogState(() {
                      editTipo = editTipo == 'chamada_video'
                          ? 'chamada_voz'
                          : 'chamada_video';
                    });
                  },
                ),

                // Prioridade
                ListTile(
                  leading: Icon(
                    Icons.flag,
                    color: _getPrioridadeColor(editPrioridade),
                  ),
                  title: Text(editPrioridade.toUpperCase()),
                  subtitle: const Text('Prioridade'),
                  onTap: () {
                    final options = ['normal', 'alta', 'urgente'];
                    final currentIndex = options.indexOf(editPrioridade);
                    final nextIndex = (currentIndex + 1) % options.length;
                    setDialogState(() {
                      editPrioridade = options[nextIndex];
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9F70D8),
              ),
              child: const Text('SALVAR'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final newDateTime = DateTime(
        editDate.year,
        editDate.month,
        editDate.day,
        editTime.hour,
        editTime.minute,
      );

      await _updateAppointment(
        appointment,
        newDateTime,
        editTipo,
        editPrioridade,
      );
    }
  }

  // ✅ FIX: Update appointment (PUT)
  Future<void> _updateAppointment(
    Agendamento appointment,
    DateTime newDateTime,
    String newTipo,
    String newPrioridade,
  ) async {
    setState(() => _isLoading = true);

    try {
      final success = await _apiService.updateAgendamento(
        agendamentoId: appointment.id,
        dataHoraAgendada: newDateTime,
        tipo: newTipo,
        prioridade: newPrioridade,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agendamento atualizado com sucesso!'),
            backgroundColor: Color(0xFF9F70D8),
          ),
        );
        await _loadAgendamentos();
      } else {
        throw Exception('Falha ao atualizar');
      }
    } catch (e) {
      _logger.e('❌ Erro ao atualizar: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao atualizar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ FIX: Confirm complete dialog
  Future<void> _confirmComplete(Agendamento appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Concluir Agendamento'),
        content:
            const Text('Deseja marcar este agendamento como concluído?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('NÃO'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('SIM, CONCLUIR'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _completeAppointment(appointment);
    }
  }

  // ✅ FIX: Complete appointment (PATCH status)
  Future<void> _completeAppointment(Agendamento appointment) async {
    setState(() => _isLoading = true);

    try {
      final success = await _apiService.updateAgendamentoStatus(
        agendamentoId: appointment.id,
        status: 'concluido',
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agendamento marcado como concluído!'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadAgendamentos();
      } else {
        throw Exception('Falha ao concluir');
      }
    } catch (e) {
      _logger.e('❌ Erro ao concluir: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao concluir: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDelete(Agendamento appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Agendamento'),
        content: const Text('Deseja realmente cancelar este agendamento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('NÃO'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('SIM', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteAppointment(appointment); // FIX: Adicionado await
    }
  }

  Future<void> _scheduleCall() async {
    final now = DateTime.now();
    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // Validacao: Data/hora deve ser no futuro
    if (dateTime.isBefore(now)) {
      // Verificar se e hoje e o horario ja passou
      final isToday = _selectedDate.year == now.year &&
          _selectedDate.month == now.month &&
          _selectedDate.day == now.day;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isToday
                ? 'O horario ${_selectedTime.format(context)} ja passou. Escolha um horario futuro.'
                : 'Selecione uma data e hora futura',
            style: const TextStyle(fontSize: 16),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Validacao: Minimo 5 minutos no futuro (dar tempo para processar)
    if (dateTime.isBefore(now.add(const Duration(minutes: 5)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Agende com pelo menos 5 minutos de antecedencia',
            style: TextStyle(fontSize: 16),
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Validacao: Maximo 1 ano no futuro
    if (dateTime.isAfter(now.add(const Duration(days: 365)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Data muito distante (maximo 1 ano)',
            style: TextStyle(fontSize: 16),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final idosoId = StorageService.getOperatorId();

      if (idosoId == null) {
        throw Exception('ID do idoso não encontrado. Faça login novamente.');
      }

      _logger.i('📅 Agendando chamada para: $dateTime');
      _logger.i('📞 Tipo: $_selectedTipo | Prioridade: $_selectedPrioridade');
      _logger.i('👤 Idoso ID: $idosoId');

      // ✅ Mostra dialog de progresso
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Criando agendamento...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      final result = await _apiService.createAgendamento(
        idosoId: idosoId,
        dataHoraAgendada: dateTime,
        tipo: _selectedTipo,
        prioridade: _selectedPrioridade,
      );

      // Fecha dialog de progresso
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (result != null) {
        _logger.i('✅ Agendamento criado com sucesso!');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Chamada ${_selectedTipo == 'chamada_video' ? 'de vídeo' : 'de voz'} agendada com sucesso!',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        // Recarregar lista
        await _loadAgendamentos();
      } else {
        throw Exception('Falha ao criar agendamento: resposta vazia do servidor');
      }
    } catch (e) {
      _logger.e('❌ Erro ao agendar: $e');

      // Fecha dialog de progresso se ainda estiver aberto
      if (mounted) {
        try {
          Navigator.of(context).pop();
        } catch (_) {}
      }

      // ✅ Extrai mensagem de erro amigável
      String errorMessage = e.toString();
      if (errorMessage.startsWith('Exception: ')) {
        errorMessage = errorMessage.substring('Exception: '.length);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.error, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Erro ao criar agendamento',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(errorMessage, style: const TextStyle(fontSize: 12)),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'TENTAR NOVAMENTE',
              textColor: Colors.white,
              onPressed: _scheduleCall,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteAppointment(Agendamento appointment) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _apiService.cancelAgendamento(appointment.id);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agendamento cancelado'),
            backgroundColor: Colors.orange,
          ),
        );

        // Recarregar lista
        await _loadAgendamentos();
      } else {
        throw Exception('Falha ao cancelar agendamento');
      }
    } catch (e) {
      _logger.e('❌ Erro ao cancelar: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao cancelar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
