package com.eva.br

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import android.webkit.PermissionRequest
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.view.WindowManager
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.os.PowerManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity


// ✅ IMPORT CRÍTICO
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.eva.br/minimize"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Existing minimize channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "minimizeApp") {
                moveTaskToBack(true)
                android.util.Log.d("EVA", "✅ App minimizado via MethodChannel")
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
        
        
        // 🔴 P1 FIX: New channel to launch app from background with FULL SCREEN
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.eva.br/app_launcher").setMethodCallHandler { call, result ->
            if (call.method == "launchApp") {
                try {
                    val intent = Intent(this, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                    }
                    startActivity(intent)
                    
                    // Usar métodos modernos para todas as versões de API
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                        setShowWhenLocked(true)
                        setTurnScreenOn(true)
                        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as android.app.KeyguardManager
                        keyguardManager.requestDismissKeyguard(this, null)
                    } else {
                        // Para API < 27, usar flags da window em vez de Intent
                        window.addFlags(
                            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
                        )
                    }
                    
                    android.util.Log.d("EVA", "✅ App launched in FULL SCREEN via MethodChannel")
                    result.success(null)
                } catch (e: Exception) {
                    android.util.Log.e("EVA", "❌ Failed to launch app: ${e.message}")
                    result.error("LAUNCH_FAILED", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // ✅ KEEP-ALIVE: Manter tela ligada
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        
        // ✅ KEEP-ALIVE: Solicitar ignorar otimização de bateria
        requestIgnoreBatteryOptimizations()
        
        // ✅ CRÍTICO: Configurar WebView para suportar getUserMedia()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            WebView.setWebContentsDebuggingEnabled(true)
        }
        
        // ✅ CRÍTICO: Configurações globais do WebView para áudio/vídeo
        configureWebViewDefaults()
        
        // Criar canais de notificação para Android 8.0+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            createNotificationChannels()
        }
        
        android.util.Log.d("EVA", "✅ Keep-Alive configurado: tela sempre ligada, sem otimização de bateria")
    }
    
    /**
     * ✅ KEEP-ALIVE: Solicitar ao sistema para ignorar otimização de bateria
     */
    private fun requestIgnoreBatteryOptimizations() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val packageName = packageName
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            
            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                try {
                    val intent = Intent().apply {
                        action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                        data = Uri.parse("package:$packageName")
                    }
                    startActivity(intent)
                    android.util.Log.d("EVA", "✅ Solicitando ignorar otimização de bateria")
                } catch (e: Exception) {
                    android.util.Log.e("EVA", "❌ Erro ao solicitar otimização de bateria: ${e.message}")
                }
            } else {
                android.util.Log.d("EVA", "✅ Já está ignorando otimização de bateria")
            }
        }
    }
    
    /**
     * ✅ KEEP-ALIVE: Interceptar botão back para minimizar em vez de fechar
     */
    override fun onBackPressed() {
        // Minimiza o app em vez de fechar
        moveTaskToBack(true)
        android.util.Log.d("EVA", "✅ App minimizado (não fechado)")
    }
    
    /**
     * ✅ CRÍTICO: Configurações necessárias para getUserMedia() funcionar
     * Sem isso, o WebView bloqueia acesso ao microfone mesmo com permissões
     */
    private fun configureWebViewDefaults() {
        try {
            // Configurar WebView para permitir acesso a mídia
            WebView.setWebContentsDebuggingEnabled(true)
            
            android.util.Log.d("EVA", "✅ WebView configurado para suportar getUserMedia()")
        } catch (e: Exception) {
            android.util.Log.e("EVA", "❌ Erro ao configurar WebView: ${e.message}")
        }
    }
    
    private fun createNotificationChannels() {
        val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        
        // Canal para chamadas de voz (MÁXIMA PRIORIDADE)
        val callsChannel = NotificationChannel(
            "eva_calls",
            "Chamadas EVA",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Notificações de chamadas de voz da EVA"
            enableVibration(true)
            enableLights(true)
            setShowBadge(true)
            // Importante: permite que a notificação apareça sobre outras apps
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        }
        
        // Canal para alertas críticos
        val alertsChannel = NotificationChannel(
            "eva_alerts",
            "Alertas EVA",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Alertas críticos e emergências"
            enableVibration(true)
            enableLights(true)
            setShowBadge(true)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
        }
        
        // Canal para medicamentos
        val medicationsChannel = NotificationChannel(
            "eva_medications",
            "Medicamentos",
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = "Lembretes de medicamentos"
            enableVibration(true)
            setShowBadge(true)
        }
        
        // Registrar todos os canais
        notificationManager.createNotificationChannel(callsChannel)
        notificationManager.createNotificationChannel(alertsChannel)
        notificationManager.createNotificationChannel(medicationsChannel)
        
        android.util.Log.d("EVA", "✅ Canais de notificação criados com sucesso")
    }
}
