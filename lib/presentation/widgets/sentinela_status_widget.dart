import 'package:flutter/material.dart';

/// Status widget for IronSentinel background service
class SentinelaStatusWidget extends StatelessWidget {
  const SentinelaStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green, width: 1),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield, color: Colors.green, size: 16),
          SizedBox(width: 4),
          Text(
            'Sentinel ON',
            style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
