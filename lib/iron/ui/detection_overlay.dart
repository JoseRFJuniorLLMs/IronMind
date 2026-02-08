import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../detection/yolo_engine.dart';
import '../segmentation/edgesam_segmenter.dart';

/// Painter para bounding boxes do YOLO no preview da câmera
class DetectionOverlayPainter extends CustomPainter {
  final List<Detection> detections;

  DetectionOverlayPainter(this.detections);

  @override
  void paint(Canvas canvas, Size size) {
    for (final det in detections) {
      final isDefect = det.isDefect;

      // Cor por estado
      final Color boxColor;
      if (isDefect) {
        boxColor = det.confidence > 0.85
            ? Colors.red
            : Colors.orange;
      } else {
        boxColor = Colors.green;
      }

      // Bounding box
      final paint = Paint()
        ..color = boxColor.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      final rect = det.bbox.toRect(size);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        paint,
      );

      // Background do label
      final labelBg = Paint()
        ..color = boxColor.withOpacity(0.85)
        ..style = PaintingStyle.fill;

      final label =
          '${det.className} ${(det.confidence * 100).toStringAsFixed(0)}%';

      final textSpan = TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final labelRect = Rect.fromLTWH(
        rect.left,
        rect.top - textPainter.height - 6,
        textPainter.width + 8,
        textPainter.height + 4,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(labelRect, const Radius.circular(4)),
        labelBg,
      );

      textPainter.paint(
        canvas,
        Offset(rect.left + 4, rect.top - textPainter.height - 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant DetectionOverlayPainter oldDelegate) {
    return oldDelegate.detections != detections;
  }
}

/// Painter para máscara de segmentação do EdgeSAM
class SegmentationOverlayPainter extends CustomPainter {
  final SegmentationMask mask;

  SegmentationOverlayPainter(this.mask);

  @override
  void paint(Canvas canvas, Size size) {
    // Máscara semitransparente vermelha
    final fillPaint = Paint()
      ..color = Colors.red.withOpacity(0.35)
      ..style = PaintingStyle.fill;

    // Contorno do defeito
    final borderPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Bounding box da máscara
    final maskRect = Rect.fromLTRB(
      mask.boundingBox.left * size.width,
      mask.boundingBox.top * size.height,
      mask.boundingBox.right * size.width,
      mask.boundingBox.bottom * size.height,
    );

    canvas.drawRect(maskRect, fillPaint);
    canvas.drawRect(maskRect, borderPaint);

    // TODO: Converter máscara binária em Path com marching squares
    // para contorno preciso pixel-a-pixel
  }

  @override
  bool shouldRepaint(covariant SegmentationOverlayPainter oldDelegate) {
    return true;
  }
}

/// HUD com informações de performance
class HUDWidget extends StatelessWidget {
  final int fps;
  final int detectionCount;
  final String modelName;
  final bool isOffline;
  final String? audioAlert;

  const HUDWidget({
    super.key,
    required this.fps,
    required this.detectionCount,
    required this.modelName,
    required this.isOffline,
    this.audioAlert,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'FPS: $fps',
            style: TextStyle(
              color: fps >= 25 ? Colors.green : Colors.orange,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'NPU: $modelName',
            style: const TextStyle(color: Colors.cyan, fontSize: 12),
          ),
          Text(
            isOffline ? 'OFFLINE' : 'ONLINE',
            style: TextStyle(
              color: isOffline ? Colors.cyan : Colors.green,
              fontSize: 12,
            ),
          ),
          if (detectionCount > 0)
            Text(
              '$detectionCount detecções',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          if (audioAlert != null)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '🔊 $audioAlert',
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}
