$pubspecPath = "pubspec.yaml"
$content = Get-Content $pubspecPath -Raw

if ($content -match "version: (\d+\.\d+\.\d+)\+(\d+)") {
    $version = $matches[1]
    $buildNumber = [int]$matches[2] + 1
    $newVersion = "version: $version+$buildNumber"
    
    $content = $content -replace "version: \d+\.\d+\.\d+\+\d+", $newVersion
    Set-Content $pubspecPath $content
    
    Write-Host "🚀 Versão incrementada para: $version+$buildNumber"
} else {
    Write-Host "⚠️ Não foi possível ler/incrementar versão. Continuando com a atual."
}

Write-Host "🔨 Compilando APK..."
cmd /c "flutter build apk --release"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Build com Sucesso!"
    Move-Item -Path "build\app\outputs\flutter-apk\app-release.apk" -Destination "app-release.apk" -Force
    Write-Host "📂 APK disponível em: $PWD\app-release.apk"
    Get-Item "app-release.apk" | Select-Object LastWriteTime, Length
} else {
    Write-Host "❌ Falha na compilação do APK"
    exit 1
}
