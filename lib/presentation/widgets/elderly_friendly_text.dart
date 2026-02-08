import 'package:flutter/material.dart';

class ElderlyFriendlyText extends StatelessWidget {
  final String text;
  final double fontSize;

  const ElderlyFriendlyText({
    super.key,
    required this.text,
    this.fontSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        height: 1.5,
      ),
    );
  }
}
