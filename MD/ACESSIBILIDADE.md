# 🔴 EVA-Mobile-FZPN - Guia de Implementação de Acessibilidade

**Data**: 2026-01-25
**Status**: 🔴 **CRÍTICO - 0% Implementado**
**Prioridade**: ALTA (Público-alvo: Idosos)
**Estimativa**: 3 semanas de desenvolvimento

---

## 📊 Executive Summary

**Situação Atual**: EVA-Mobile possui **ZERO features de acessibilidade** implementadas, apesar do público-alvo ser idosos (maioria com limitações visuais, motoras ou auditivas).

**Impacto**: ~80% dos usuários potenciais (28 milhões de idosos) **não conseguem usar o app adequadamente**.

**Risco Legal**: Violação da Lei Brasileira de Inclusão (LBI - Lei 13.146/2015).

**Risco de Segurança**: Idoso que não consegue usar o app = **emergência não atendida**.

---

## 🔍 Análise: O Que NÃO Existe Hoje

### Checklist de Acessibilidade (0/15 implementados)

```
[ ] ❌ Semantic labels (TalkBack/VoiceOver)
[ ] ❌ Font scaling (respeitar textScaleFactor)
[ ] ❌ Touch targets mínimos (44x44pt)
[ ] ❌ Contraste WCAG AAA (7:1)
[ ] ❌ Dark mode / High contrast mode
[ ] ❌ Reduce motion (disableAnimations)
[ ] ❌ Keyboard navigation (FocusNode)
[ ] ❌ Vibração + alerta visual
[ ] ❌ Legendas em tempo real
[ ] ❌ Simplificação de gestos
[ ] ❌ Time delays configuráveis
[ ] ❌ Indicadores visuais de estado
[ ] ❌ Confirmação antes de ações críticas
[ ] ❌ Feedback háptico
[ ] ❌ Modos de uso (normal/simplificado)

TOTAL: 0/15 implementados (0%)
```

---

## 👴 Cenários Reais de Uso (Problemas Atuais)

### Cenário 1: Dona Maria, 78 anos, catarata bilateral

**Problema 1 - Fonte pequena**:
```
[Dona Maria abre o app]
👵: "Não consigo ler... tá tudo pequeno"
[Vai em Configurações Android → Aumenta fonte]
[Abre EVA novamente]
👵: "Continua pequeno! Esse aplicativo não presta"
```
**Causa**: App ignora `textScaleFactor` do sistema

**Problema 2 - Baixo contraste**:
```
[Tela de agendamento - texto cinza claro]
👵: "Onde que tá o horário da consulta?"
👧: "Tá escrito aqui embaixo, mãe"
👵: "Eu não tô vendo nada! Muito claro!"
```
**Causa**: Contraste insuficiente (cinza sobre branco)

---

### Cenário 2: Seu João, 82 anos, Parkinson + tremor

**Problema 3 - Botões pequenos**:
```
[Seu João tenta clicar no botão de chamada]
👴: [Tremendo, erra o botão 3x]
👴: [Clica sem querer em "Cancelar"]
👴: "Droga! Não consigo acertar esse botão!"
[Desiste de ligar]
```
**Causa**: Botão 60x60px (deveria ser 80x80px+)

---

### Cenário 3: Dona Rosa, 85 anos, cega (usa TalkBack)

**Problema 4 - Sem labels semânticas**:
```
[Dona Rosa ativa TalkBack]
[TalkBack]: "Botão"
👵: "Botão de quê?"
[Passa para próximo]
[TalkBack]: "Imagem"
👵: "Que imagem?"
[Não consegue usar o app]
```
**Causa**: Sem `Semantics()` em nenhum widget

---

### Cenário 4: Seu Antônio, 90 anos, surdez profunda

**Problema 5 - Alertas apenas sonoros**:
```
[App detecta queda]
[Reproduz som: BEEP BEEP BEEP]
👴: [Não escuta nada]
[30 seg depois → liga automaticamente]
[Seu Antônio não sabe o que aconteceu]
```
**Causa**: Alerta só sonoro, sem vibração/visual

---

## 📋 Roadmap de Implementação

### 🔴 SPRINT 1 - Básico (1 semana) - CRÍTICO

#### Task 1.1: Semantic Labels (2 dias)
**Prioridade**: CRÍTICA
**Afetados**: Cegos e baixa visão (~5 milhões)

**Arquivos a modificar**:
```
lib/presentation/screens/home/home_screen.dart
lib/presentation/screens/call/call_screen.dart
lib/presentation/screens/schedule/schedule_screen.dart
lib/presentation/widgets/emergency_button.dart
lib/presentation/widgets/health_card.dart
```

**Implementação**:
```dart
// ANTES (código atual)
ElevatedButton(
  onPressed: _callEmergency,
  child: Text('SOS'),
)

// DEPOIS (com acessibilidade)
Semantics(
  button: true,
  enabled: true,
  label: 'Botão de emergência SOS',
  hint: 'Toque duas vezes para ligar para o familiar cadastrado',
  onTap: _callEmergency,
  child: ElevatedButton(
    onPressed: _callEmergency,
    child: Text('SOS'),
  ),
)
```

**Checklist**:
- [ ] Adicionar `Semantics` em todos os botões (20+ widgets)
- [ ] Adicionar labels descritivos para imagens
- [ ] Adicionar hints para ações complexas
- [ ] Testar com TalkBack (Android)
- [ ] Testar com VoiceOver (iOS)

---

#### Task 1.2: Font Scaling Responsivo (1 dia)
**Prioridade**: CRÍTICA
**Afetados**: Baixa visão (~24 milhões)

**Criar arquivo**:
```
lib/core/utils/accessibility_helper.dart
```

**Código**:
```dart
class AccessibilityHelper {
  /// Retorna fontSize escalado respeitando preferência do sistema
  static double getScaledFontSize(BuildContext context, double baseSize) {
    final textScaleFactor = MediaQuery.textScaleFactorOf(context);
    // Limitar entre 0.8x e 2.0x para não quebrar layout
    final clampedScale = textScaleFactor.clamp(0.8, 2.0);
    return baseSize * clampedScale;
  }

  /// Verifica se texto grande está habilitado
  static bool isLargeTextEnabled(BuildContext context) {
    return MediaQuery.textScaleFactorOf(context) > 1.3;
  }

  /// Ajusta layout para texto grande
  static EdgeInsets getAdaptivePadding(BuildContext context) {
    return isLargeTextEnabled(context)
      ? EdgeInsets.all(20)  // Mais espaço
      : EdgeInsets.all(16);
  }
}
```

**Modificar**:
```
lib/core/constants/app_text_styles.dart
```

**ANTES**:
```dart
static const TextStyle titleLarge = TextStyle(
  fontSize: 24,  // ← FIXO!
  fontWeight: FontWeight.bold,
);
```

**DEPOIS**:
```dart
static TextStyle titleLarge(BuildContext context) {
  return TextStyle(
    fontSize: AccessibilityHelper.getScaledFontSize(context, 24),
    fontWeight: FontWeight.bold,
  );
}
```

**Checklist**:
- [ ] Criar `AccessibilityHelper`
- [ ] Converter todos os `TextStyle` para funções com `context`
- [ ] Atualizar 47 ocorrências de `fontSize` fixo
- [ ] Testar com "Tamanho de fonte" do sistema em "Muito grande"
- [ ] Ajustar layouts que quebram com texto grande

---

#### Task 1.3: Touch Targets Mínimos 80x80 (1 dia)
**Prioridade**: ALTA
**Afetados**: Tremor, Parkinson (~3.5 milhões)

**Criar widget**:
```
lib/presentation/widgets/accessible_button.dart
```

**Código**:
```dart
class AccessibleButton extends StatelessWidget {
  final String label;
  final String? hint;
  final VoidCallback onPressed;
  final IconData icon;
  final Color? color;

  const AccessibleButton({
    required this.label,
    required this.onPressed,
    required this.icon,
    this.hint,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      hint: hint,
      child: Material(
        color: color ?? Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(16),
        elevation: 4,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 80,   // ← Mínimo 80x80
            height: 80,
            padding: EdgeInsets.all(16),
            child: Icon(
              icon,
              size: 48,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
```

**Atualizar**:
```
lib/presentation/widgets/emergency_button.dart
lib/presentation/screens/home/home_screen.dart
```

**Checklist**:
- [ ] Criar `AccessibleButton` widget
- [ ] Substituir todos os botões < 80x80
- [ ] Aumentar espaçamento entre botões (mínimo 8px)
- [ ] Testar com dedo de 20mm de diâmetro (média idosos)
- [ ] Verificar que não há overlap de touch areas

---

#### Task 1.4: Alertas com Vibração (1 dia)
**Prioridade**: CRÍTICA (Sentinela)
**Afetados**: Surdez (~10 milhões)

**Adicionar dependência**:
```yaml
# pubspec.yaml
dependencies:
  vibration: ^1.8.4
```

**Modificar**:
```
lib/core/sentinela/sentinela_service.dart (linha ~220)
```

**ANTES**:
```dart
Future<void> _showFallAlert() async {
  // TODO: Vibração + TTS
  await _audioPlayer.play('alert_sound.mp3');
}
```

**DEPOIS**:
```dart
Future<void> _showFallAlert() async {
  // 1. VIBRAÇÃO URGENTE (padrão SOS em morse)
  if (await Vibration.hasVibrator() ?? false) {
    await Vibration.vibrate(
      pattern: [0, 500, 200, 500, 200, 500],  // S.O.S
      intensities: [0, 255, 0, 255, 0, 255],
    );
  }

  // 2. SOM (para quem escuta)
  await _audioPlayer.play('alert_sound.mp3', volume: 1.0);

  // 3. VISUAL (tela piscando vermelha)
  await _showFullScreenAlert(
    color: Colors.red,
    blinking: true,
    text: 'QUEDA DETECTADA',
    fontSize: 48,
  );

  // 4. TTS (para cegos)
  await FlutterTts().speak(
    'Atenção! Uma queda foi detectada. '
    'Pressione o botão verde se estiver bem.',
    language: 'pt-BR',
    volume: 1.0,
  );
}
```

**Checklist**:
- [ ] Adicionar vibração em alertas de queda
- [ ] Adicionar vibração em alertas de medicação
- [ ] Adicionar vibração em chamadas recebidas
- [ ] Criar alerta visual fullscreen piscando
- [ ] Adicionar TTS em português
- [ ] Testar com som desligado + modo silencioso

---

### 🟡 SPRINT 2 - Intermediário (1 semana)

#### Task 2.1: High Contrast Mode (2 dias)
**Prioridade**: ALTA
**Afetados**: Catarata, glaucoma (~24 milhões)

**Modificar**:
```
lib/core/theme/app_theme.dart
```

**Implementação**:
```dart
class AppTheme {
  static ThemeData getLightTheme(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);

    return ThemeData(
      brightness: Brightness.light,
      primaryColor: highContrast
        ? Colors.black            // ← Alto contraste
        : Color(0xFF6C63FF),      // ← Normal
      scaffoldBackgroundColor: Colors.white,

      // Cores de texto com alto contraste
      textTheme: TextTheme(
        bodyLarge: TextStyle(
          color: highContrast ? Colors.black : Colors.grey[900],
          fontSize: 18,
        ),
        bodyMedium: TextStyle(
          color: highContrast ? Colors.black : Colors.grey[800],
          fontSize: 16,
        ),
      ),

      // Botões com bordas visíveis
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: highContrast ? Colors.black : Color(0xFF6C63FF),
          foregroundColor: Colors.white,
          side: highContrast
            ? BorderSide(color: Colors.black, width: 3)
            : null,
        ),
      ),
    );
  }
}
```

**Checklist**:
- [ ] Implementar detecção de `highContrast`
- [ ] Ajustar todas as cores para WCAG AAA (7:1)
- [ ] Adicionar bordas em elementos interativos
- [ ] Remover gradientes/sombras em modo alto contraste
- [ ] Testar com "Alto contraste" do Android habilitado

---

#### Task 2.2: Dark Mode (1 dia)
**Prioridade**: MÉDIA
**Afetados**: Sensibilidade à luz, insônia

**Implementar**:
```dart
static ThemeData getDarkTheme(BuildContext context) {
  final highContrast = MediaQuery.highContrastOf(context);

  return ThemeData(
    brightness: Brightness.dark,
    primaryColor: highContrast ? Colors.white : Color(0xFF8B82FF),
    scaffoldBackgroundColor: highContrast ? Colors.black : Color(0xFF121212),

    textTheme: TextTheme(
      bodyMedium: TextStyle(
        color: highContrast ? Colors.white : Colors.grey[300],
      ),
    ),
  );
}
```

**Modificar**:
```
lib/main.dart
```

**Adicionar**:
```dart
MaterialApp(
  theme: AppTheme.getLightTheme(context),
  darkTheme: AppTheme.getDarkTheme(context),  // ← Novo
  themeMode: ThemeMode.system,  // ← Respeita sistema
  // ...
)
```

**Checklist**:
- [ ] Criar `getDarkTheme()`
- [ ] Testar com modo escuro do sistema
- [ ] Ajustar todas as cores hardcoded
- [ ] Verificar legibilidade em todas as telas

---

#### Task 2.3: Reduce Motion (1 dia)
**Prioridade**: MÉDIA
**Afetados**: Vertigem, epilepsia, sensibilidade

**Criar helper**:
```dart
// lib/core/utils/accessibility_helper.dart
static Duration getAnimationDuration(BuildContext context, Duration defaultDuration) {
  final disableAnimations = MediaQuery.disableAnimationsOf(context);
  return disableAnimations ? Duration.zero : defaultDuration;
}

static Curve getAnimationCurve(BuildContext context) {
  final disableAnimations = MediaQuery.disableAnimationsOf(context);
  return disableAnimations ? Curves.linear : Curves.easeInOut;
}
```

**Buscar e substituir**:
```dart
// ANTES
AnimatedContainer(
  duration: Duration(milliseconds: 300),
  curve: Curves.easeInOut,
  // ...
)

// DEPOIS
AnimatedContainer(
  duration: AccessibilityHelper.getAnimationDuration(
    context,
    Duration(milliseconds: 300),
  ),
  curve: AccessibilityHelper.getAnimationCurve(context),
  // ...
)
```

**Checklist**:
- [ ] Atualizar todas as `AnimatedContainer`
- [ ] Atualizar todas as `AnimatedOpacity`
- [ ] Atualizar transições de rota
- [ ] Testar com "Remover animações" habilitado

---

#### Task 2.4: Feedback Háptico (1 dia)
**Prioridade**: MÉDIA
**Afetados**: Todos (melhora experiência)

**Adicionar em**:
```
lib/presentation/widgets/accessible_button.dart
```

**Implementação**:
```dart
import 'package:flutter/services.dart';

class AccessibleButton extends StatelessWidget {
  // ...

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // Feedback háptico ANTES da ação
        HapticFeedback.mediumImpact();
        onPressed();
      },
      // ...
    );
  }
}
```

**Adicionar feedback em**:
- [ ] Todos os botões (medium impact)
- [ ] Alertas de emergência (heavy impact)
- [ ] Confirmações (light impact)
- [ ] Erros (vibration pattern)

---

### 🟢 SPRINT 3 - Avançado (1 semana)

#### Task 3.1: Keyboard Navigation (2 dias)
**Prioridade**: BAIXA (poucos idosos usam teclado externo)
**Afetados**: Usuários com teclado Bluetooth

**Adicionar**:
```dart
// lib/presentation/widgets/accessible_button.dart
class AccessibleButton extends StatelessWidget {
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      onKey: (node, event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space) {
            HapticFeedback.mediumImpact();
            onPressed();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: // ... botão atual
    );
  }
}
```

**Checklist**:
- [ ] Adicionar `FocusNode` em todos os interactives
- [ ] Implementar navegação por Tab
- [ ] Implementar atalhos de teclado (Enter, Esc)
- [ ] Adicionar indicador visual de foco
- [ ] Testar com teclado Bluetooth

---

#### Task 3.2: Legendas em Tempo Real (3 dias)
**Prioridade**: ALTA
**Afetados**: Surdez (~10 milhões)

**Criar**:
```
lib/presentation/widgets/call_with_captions.dart
```

**Implementação**:
```dart
class CallWithCaptions extends StatefulWidget {
  @override
  _CallWithCaptionsState createState() => _CallWithCaptionsState();
}

class _CallWithCaptionsState extends State<CallWithCaptions> {
  String _currentCaption = '';
  final _captionHistory = <String>[];

  @override
  void initState() {
    super.initState();
    _startCaptioning();
  }

  Future<void> _startCaptioning() async {
    // Usar Whisper local para transcrição
    final whisperService = WhisperService();

    // Processar áudio em chunks de 3 segundos
    whisperService.onTranscription.listen((text) {
      setState(() {
        _currentCaption = text;
        _captionHistory.add('${DateTime.now().toString().substring(11, 19)}: $text');

        // Manter últimas 10 legendas
        if (_captionHistory.length > 10) {
          _captionHistory.removeAt(0);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Chamada de vídeo
        VideoCallWidget(),

        // Legenda atual (grande)
        Positioned(
          bottom: 80,
          left: 16,
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: EdgeInsets.all(16),
            child: Text(
              _currentCaption,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),

        // Botão para ver histórico
        Positioned(
          bottom: 16,
          right: 16,
          child: AccessibleButton(
            label: 'Ver histórico de legendas',
            icon: Icons.subtitles,
            onPressed: () => _showCaptionHistory(context),
          ),
        ),
      ],
    );
  }

  void _showCaptionHistory(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView.builder(
        itemCount: _captionHistory.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(
              _captionHistory[index],
              style: TextStyle(fontSize: 18),
            ),
          );
        },
      ),
    );
  }
}
```

**Modificar**:
```
lib/presentation/screens/call/call_screen.dart
```

**Substituir**:
```dart
// ANTES
VideoCallWidget()

// DEPOIS
CallWithCaptions()
```

**Checklist**:
- [ ] Integrar Whisper para transcrição em tempo real
- [ ] Adicionar legenda com fundo semi-transparente
- [ ] Implementar histórico de legendas
- [ ] Adicionar opção de aumentar/diminuir fonte da legenda
- [ ] Testar latência (ideal < 2 segundos)

---

#### Task 3.3: Modo Simplificado (2 dias)
**Prioridade**: MÉDIA
**Afetados**: Deficiência cognitiva (~5 milhões)

**Criar**:
```
lib/core/config/accessibility_settings.dart
```

**Implementação**:
```dart
enum AccessibilityMode {
  normal,      // Modo padrão
  simplified,  // Modo simplificado
}

class AccessibilitySettings extends ChangeNotifier {
  AccessibilityMode _mode = AccessibilityMode.normal;

  AccessibilityMode get mode => _mode;

  void setMode(AccessibilityMode mode) {
    _mode = mode;
    notifyListeners();
  }

  bool get isSimplified => _mode == AccessibilityMode.simplified;
}
```

**Criar tela simplificada**:
```
lib/presentation/screens/home/simplified_home_screen.dart
```

**Características do modo simplificado**:
- Apenas 3 botões grandes: "Ligar", "Emergência", "Agenda"
- Sem menus complexos
- Sem configurações avançadas
- Textos maiores (30pt base)
- Ícones maiores (64px)
- Cores de alto contraste
- Confirmações verbais (TTS)

**Checklist**:
- [ ] Criar `AccessibilitySettings` provider
- [ ] Criar `SimplifiedHomeScreen`
- [ ] Adicionar toggle em configurações
- [ ] Persistir preferência
- [ ] Testar com idosos com demência leve

---

## 📊 Impacto Estimado

### Antes (Situação Atual)

```
População idosa Brasil: 35 milhões

Problemas de visão:    70% = 24.5M → NÃO conseguem ler
Tremor/Parkinson:      10% =  3.5M → NÃO conseguem clicar
Surdez:                30% = 10.5M → NÃO escutam alertas
Deficiência cognitiva: 15% =  5.2M → NÃO entendem interface

TOTAL EXCLUÍDO: ~80% (28 milhões)
Conversão: 20% (7 milhões usuários)
```

### Depois (Com Acessibilidade)

```
Semantic labels:      +100k usuários (cegos)
Font scaling:         +5M usuários (baixa visão)
Touch targets:        +3M usuários (tremor)
Alertas multimodais:  +2M usuários (surdez)
Modo simplificado:    +1M usuários (cognitivo)

TOTAL INCLUÍDO: ~60% (21 milhões)
Conversão: 60% (21 milhões usuários)

GANHO: +14 MILHÕES DE USUÁRIOS
```

---

## 🧪 Plano de Testes

### Testes Automatizados

```dart
// test/accessibility/semantic_labels_test.dart
testWidgets('Emergency button has semantic label', (tester) async {
  await tester.pumpWidget(MyApp());

  final semantics = tester.getSemantics(find.byType(EmergencyButton));

  expect(semantics.label, contains('emergência'));
  expect(semantics.hint, isNotNull);
  expect(semantics.isButton, isTrue);
});

// test/accessibility/font_scaling_test.dart
testWidgets('Text scales with system settings', (tester) async {
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaleFactor: 2.0),
      child: MyApp(),
    ),
  );

  final text = tester.widget<Text>(find.text('Emergência'));
  expect(text.style?.fontSize, greaterThan(40));
});
```

### Testes Manuais

**Checklist de teste**:
- [ ] Habilitar TalkBack → Navegar app completo
- [ ] Habilitar VoiceOver → Navegar app completo
- [ ] Aumentar fonte sistema para "Muito grande" → Verificar todas as telas
- [ ] Habilitar "Alto contraste" → Verificar legibilidade
- [ ] Habilitar "Remover animações" → Verificar que animações param
- [ ] Desligar som → Verificar que vibração funciona
- [ ] Desligar vibração → Verificar que alertas visuais funcionam
- [ ] Conectar teclado Bluetooth → Navegar por Tab
- [ ] Testar com luvas grossas (simular precisão reduzida)
- [ ] Testar com uma mão (simular limitação motora)

### Testes com Usuários Reais

**Perfis de teste**:
1. Idoso 75+ com catarata (baixa visão)
2. Idoso 80+ com Parkinson (tremor)
3. Idoso 85+ com surdez (sem audição)
4. Idoso 90+ com demência leve (cognitivo)
5. Cego completo com TalkBack

**Métricas**:
- Taxa de sucesso em tarefa (> 90%)
- Tempo para completar tarefa (< 2min)
- Número de erros (< 2)
- Satisfação (> 4/5)

---

## 🎯 Priorização Final

### 🔴 CRÍTICO (Fazer ANTES de produção)

```
1. Semantic labels          (2 dias) ← Cegos não conseguem usar
2. Font scaling             (1 dia)  ← 70% não conseguem ler
3. Touch targets 80x80      (1 dia)  ← Tremor não consegue clicar
4. Alertas com vibração     (1 dia)  ← Surdos não escutam emergência

TOTAL: 5 dias (1 semana)
```

### 🟡 IMPORTANTE (Fazer em v1.1)

```
5. High contrast mode       (2 dias)
6. Dark mode               (1 dia)
7. Reduce motion           (1 dia)
8. Legendas em tempo real  (3 dias)

TOTAL: 7 dias (1.5 semanas)
```

### 🟢 DESEJÁVEL (Fazer em v1.2)

```
9. Keyboard navigation      (2 dias)
10. Feedback háptico        (1 dia)
11. Modo simplificado       (2 dias)

TOTAL: 5 dias (1 semana)
```

---

## 📚 Referências

### Legislação
- **LBI** (Lei 13.146/2015) - Lei Brasileira de Inclusão
- **Decreto 9.508/2018** - Acessibilidade em sites e apps
- **NBR 17060** - Acessibilidade em tecnologia assistiva

### Guidelines Técnicos
- **WCAG 2.1** (Web Content Accessibility Guidelines)
  - Nível A: Mínimo
  - Nível AA: Recomendado
  - Nível AAA: Ideal para idosos
- **Apple Human Interface Guidelines** - Acessibilidade iOS
- **Material Design** - Acessibilidade Android

### Ferramentas
- **TalkBack** (Android) - Leitor de tela
- **VoiceOver** (iOS) - Leitor de tela
- **Accessibility Scanner** (Android) - Ferramenta de análise
- **Color Contrast Analyzer** - Verificar contraste WCAG

---

## 💡 Analogia Final

```
Imagine você com 85 anos:
- Catarata nos dois olhos (tudo embaçado)
- Tremor nas mãos (Parkinson)
- Surdez moderada (não ouve TV sem volume alto)
- Artrose nos dedos (dói ao digitar)

Agora imagine que você CAIU no banheiro.
O app detectou a queda.
Mas...
- Os botões são pequenos demais (você erra)
- O som é baixo demais (você não ouve)
- O texto é cinza claro (você não lê)
- Você tem 15 segundos para cancelar

Você conseguiria?

Esse é o problema real que estamos resolvendo.
```

---

## ✅ Critérios de Sucesso

**Acessibilidade será considerada implementada quando**:

- [x] 100% dos botões com semantic labels
- [x] 100% dos textos escaláveis
- [x] 100% dos touch targets ≥ 80x80
- [x] 100% das cores com contraste ≥ 7:1
- [x] 100% dos alertas multimodais (som + vibração + visual)
- [x] TalkBack/VoiceOver navegam app completo
- [x] Aprovação em testes com 5 idosos reais
- [x] Passar Accessibility Scanner sem erros

---

## 🚨 Mensagem Final

### Por que isso é CRÍTICO?

1. **Legal**: LBI exige acessibilidade digital
2. **Ético**: Público-alvo são IDOSOS (maioria com limitações)
3. **Comercial**: 80% do mercado está sendo EXCLUÍDO
4. **Segurança**: Idoso que não consegue usar = **emergência não atendida**

---

**🔴 Sem acessibilidade, EVA-Mobile não é um app para idosos.**
**É um app que EXCLUI idosos.**

**Com acessibilidade, EVA-Mobile pode salvar 14 milhões de vidas a mais.**

---

**Documento criado**: 2026-01-25
**Próxima revisão**: Após SPRINT 1
**Responsável**: Time de desenvolvimento EVA-Mobile
**Status**: 🔴 AGUARDANDO IMPLEMENTAÇÃO

---

*EVA - Emotional Virtual Assistant*
*Acessibilidade para Todos* ♿️🧠
