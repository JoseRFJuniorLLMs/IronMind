import 'package:flutter/material.dart';

class ScheduleCard extends StatelessWidget {
  final String title;
  final String time;

  const ScheduleCard({super.key, required this.title, required this.time});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(time),
        trailing: const Icon(Icons.event),
      ),
    );
  }
}
