import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/call_provider.dart';

class AudioVisualizer extends StatelessWidget {
  const AudioVisualizer({super.key});

  @override
  Widget build(BuildContext context) {
    // Consume volume from CallProvider
    final volume = context.select<CallProvider, double>((p) => p.currentVolume);

    return SizedBox(
      height: 60,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(15, (index) {
          // Calculate individual bar height based on volume + some localized variance
          // We use a pseudo-random seed based on index to make but heights look naturally varied
          final variance = (index % 3 + 1) * 0.3;
          final barHeight = 4 + (volume * 50 * variance).clamp(2.0, 56.0);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 4,
            height: barHeight,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3),
                    blurRadius: 4,
                  )
                ]),
          );
        }),
      ),
    );
  }
}
