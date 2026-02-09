class CallLog {
  final int? id;
  final String sessionId;
  final int operatorId;
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final bool wasSuccessful;
  final String? errorMessage;

  CallLog({
    this.id,
    required this.sessionId,
    required this.operatorId,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.wasSuccessful,
    this.errorMessage,
  });

  factory CallLog.fromJson(Map<String, dynamic> json) {
    return CallLog(
      id: json['id'],
      sessionId: json['session_id'],
      operatorId: json['operator_id'],
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
      duration: Duration(seconds: json['duration_seconds']),
      wasSuccessful: json['was_successful'],
      errorMessage: json['error_message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'operator_id': operatorId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'duration_seconds': duration.inSeconds,
      'was_successful': wasSuccessful,
      'error_message': errorMessage,
    };
  }
}
