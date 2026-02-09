# Correção de Permissões de Saúde - EVA Mobile

## 📋 Problemas Identificados

1. ❌ **permissions_screen.dart** não solicitava permissões do Health Connect/HealthKit
2. ❌ **permissions.dart** não tinha método para solicitar permissões de saúde
3. ❌ **iOS** faltava arquivo de entitlements para HealthKit
4. ❌ As permissões de saúde não eram exibidas na tela de permissões

## ✅ Correções Realizadas

### 1. **lib/core/utils/permissions.dart**
- ✅ Adicionado método `requestHealthPermissions()` para solicitar permissões via HealthService
- ✅ Adicionado método `requestAllPermissions()` que solicita todas as permissões incluindo saúde
- ✅ Corrigido import do HealthService

### 2. **lib/presentation/screens/permissions_screen.dart**
- ✅ Adicionado import do `HealthService`
- ✅ Alterado `Map<Permission, bool>` para `Map<String, bool>` para suportar permissões customizadas
- ✅ Adicionada constante `_healthPermissionKey` para identificar permissões de saúde
- ✅ Criado método `_requestHealthPermission()` que solicita via HealthService
- ✅ Atualizado `_requestAllPermissions()` para incluir permissões de saúde
- ✅ Atualizado `_checkPermissions()` para verificar permissões de saúde
- ✅ Criado método `_getAllPermissionKeys()` para listar todas as permissões
- ✅ Adicionado ícone de saúde na UI (Icons.health_and_safety)
- ✅ Alterados métodos `_getPermissionName()` e `_getPermissionIcon()` para trabalhar com Strings

### 3. **ios/Runner/Runner.entitlements** (NOVO)
- ✅ Criado arquivo de entitlements para iOS
- ✅ Habilitado HealthKit (`com.apple.developer.healthkit`)
- ✅ Configurado acesso ao HealthKit

### 4. **Arquivos já configurados** ✅
- ✅ **AndroidManifest.xml**: Já tinha todas as permissões de saúde declaradas
- ✅ **ios/Info.plist**: Já tinha as descrições de uso do HealthKit
- ✅ **android/res/values/strings.xml**: Já tinha a descrição de permissões
- ✅ **health_service.dart**: Já tinha implementação completa

## 📱 Permissões de Saúde Configuradas

### Android (Health Connect)
- ✅ `ACTIVITY_RECOGNITION` - Reconhecimento de atividade física
- ✅ `BODY_SENSORS` - Sensores corporais
- ✅ `health.READ_HEART_RATE` - Frequência cardíaca
- ✅ `health.READ_STEPS` - Passos
- ✅ `health.READ_SLEEP` - Sono
- ✅ `health.READ_DISTANCE` - Distância
- ✅ `health.READ_EXERCISE` - Exercícios
- ✅ `health.READ_TOTAL_CALORIES_BURNED` - Calorias queimadas

### iOS (HealthKit)
- ✅ `NSHealthShareUsageDescription` - Leitura de dados
- ✅ `NSHealthUpdateUsageDescription` - Atualização de dados
- ✅ HealthKit Entitlements habilitado

## 🔧 Tipos de Dados Coletados

O app coleta os seguintes dados de saúde:
1. **Passos** (STEPS) - Contador diário de passos
2. **Frequência Cardíaca** (HEART_RATE) - BPM em tempo real
3. **Sono** (SLEEP_SESSION) - Sessões e duração do sono

## 🧪 Como Testar

### Android (API 34+)
1. Certifique-se de ter o **Health Connect** instalado
2. Execute o app: `flutter run`
3. Na tela de permissões, clique em "Todas"
4. O app solicitará:
   - Permissões básicas (microfone, câmera, etc.)
   - Permissões de saúde via Health Connect
5. Conceda todas as permissões
6. Verifique no Health Connect se o app tem acesso

### iOS
1. Execute o app no dispositivo físico (HealthKit não funciona no simulador)
2. Na tela de permissões, clique em "Todas"
3. O sistema solicitará acesso ao HealthKit
4. Conceda as permissões
5. Verifique em Ajustes > Privacidade > Saúde se o app tem acesso

## 📊 Fluxo de Sincronização

1. **Solicitação de Permissões** → `permissions_screen.dart`
2. **Verificação de Acesso** → `health_service.dart` → `requestPermissions()`
3. **Coleta de Dados** → `fetchSteps()`, `fetchHeartRate()`, `fetchSleep()`
4. **Sincronização** → `syncNow()` envia para API via `ApiService`
5. **Retry Queue** → Dados salvos localmente se API falhar

## ⚠️ Observações Importantes

### Android
- Health Connect é necessário para Android 14+ (API 34+)
- Para Android < 14, o Google Fit é usado automaticamente
- Permissões de saúde são solicitadas em diálogo separado

### iOS
- HealthKit só funciona em dispositivos físicos
- O arquivo `.entitlements` precisa ser configurado no Xcode
- Permissões aparecem em diálogo nativo do iOS

### Xcode (IMPORTANTE para iOS)
Após criar o arquivo `Runner.entitlements`, você precisa:
1. Abrir o projeto no Xcode: `open ios/Runner.xcworkspace`
2. Selecionar o target "Runner"
3. Ir em "Signing & Capabilities"
4. Clicar em "+ Capability" e adicionar "HealthKit"
5. Build novamente

## 🚀 Próximos Passos

1. ✅ Testar em dispositivo Android com Health Connect
2. ✅ Testar em dispositivo iOS físico
3. ✅ Verificar sincronização de dados com a API
4. ✅ Testar retry queue quando API estiver offline
5. ⚠️ Configurar HealthKit no Xcode (necessário)

## 📝 Arquivos Modificados

1. `lib/core/utils/permissions.dart`
2. `lib/presentation/screens/permissions_screen.dart`
3. `ios/Runner/Runner.entitlements` (novo)

## ✨ Resultado

Agora o app solicita **todas as permissões necessárias** incluindo:
- ✅ 10 permissões básicas (microfone, câmera, notificações, etc.)
- ✅ 1 permissão de saúde (Health Connect/HealthKit) com 3 tipos de dados (passos, BPM, sono)
- ✅ Total: 11 permissões na tela de permissões
- ✅ Ícone de saúde visível na UI

## 🐛 Troubleshooting

### Problema: Health Connect não abre
**Solução**: Instale o Health Connect da Play Store

### Problema: HealthKit negado no iOS
**Solução**: Vá em Ajustes > Privacidade > Saúde > EVA Mobile e habilite

### Problema: Permissões não aparecem
**Solução**: Desinstale e reinstale o app

### Problema: Entitlements não aplicado no iOS
**Solução**: Adicione HealthKit capability manualmente no Xcode
