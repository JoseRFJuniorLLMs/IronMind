# Sons de Alerta EVA

Esta pasta contém os arquivos de som para o sistema de alertas multimodais.

## Arquivos Necessarios

| Arquivo | Uso | Duracao Recomendada |
|---------|-----|---------------------|
| `alert_critical.mp3` | Emergencias, quedas | 2-3 segundos |
| `alert_warning.mp3` | Lembretes de medicamento | 1-2 segundos |
| `alert_info.mp3` | Notificacoes gerais | 0.5-1 segundo |

## Especificacoes Tecnicas

- **Formato**: MP3 ou WAV
- **Sample Rate**: 44100 Hz
- **Canais**: Mono ou Stereo
- **Volume**: Normalizado (sem clipping)

## Sons Recomendados

### alert_critical.mp3
- Tom urgente, repetitivo
- Frequencia alta (800-1200 Hz)
- Exemplo: Sirene curta ou beep triplo

### alert_warning.mp3
- Tom de atencao
- Frequencia media (400-600 Hz)
- Exemplo: Ding-dong ou beep duplo

### alert_info.mp3
- Tom suave
- Frequencia baixa (200-400 Hz)
- Exemplo: Chime ou beep simples

## Fontes Gratuitas de Sons

1. **Freesound.org** - https://freesound.org
2. **Pixabay** - https://pixabay.com/sound-effects
3. **Zapsplat** - https://www.zapsplat.com

## Nota

Se os arquivos de som nao existirem, o sistema usara tons gerados
programaticamente como fallback.
