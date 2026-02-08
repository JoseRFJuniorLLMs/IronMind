import 'package:flutter/material.dart';

class CallControls extends StatelessWidget {
  final bool isMuted;
  final bool isSpeakerOn;
  final VoidCallback onMuteToggle;
  final VoidCallback onSpeakerToggle;
  final VoidCallback onEndCall;

  const CallControls({
    super.key,
    required this.isMuted,
    required this.isSpeakerOn,
    required this.onMuteToggle,
    required this.onSpeakerToggle,
    required this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildControlButton(
          icon: isMuted ? Icons.mic_off : Icons.mic,
          label: isMuted ? 'Desmutar' : 'Mutar',
          onPressed: onMuteToggle,
          color: isMuted ? Colors.red : Colors.white,
        ),
        _buildControlButton(
          icon: Icons.call_end,
          label: 'Desligar',
          onPressed: onEndCall,
          color: Colors.red,
          size: 80,
        ),
        _buildControlButton(
          icon: isSpeakerOn ? Icons.volume_up : Icons.volume_off,
          label: isSpeakerOn ? 'Speaker On' : 'Speaker Off',
          onPressed: onSpeakerToggle,
          color: isSpeakerOn ? Colors.white : Colors.grey,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
    double size = 60,
  }) {
    return Column(
      children: [
        Material(
          color: color.withValues(alpha: 0.2),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: size * 0.5),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ],
    );
  }
}
