import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class AppLogger {
  static final Logger _logger = Logger();

  static void log(String message) {
    if (kDebugMode) {
      _logger.i('[EVA-LOG] $message');
    }
  }

  static void error(String message, [dynamic error]) {
    _logger.e('[EVA-ERROR] $message', error: error);
  }
}
