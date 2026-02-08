import 'package:flutter/foundation.dart';

class NotificationProvider with ChangeNotifier {
  String? _fcmToken;
  Map<String, dynamic>? _lastNotification;

  String? get fcmToken => _fcmToken;
  Map<String, dynamic>? get lastNotification => _lastNotification;

  void setFcmToken(String token) {
    _fcmToken = token;
    notifyListeners();
  }

  void onNotificationReceived(Map<String, dynamic> notification) {
    _lastNotification = notification;
    notifyListeners();
  }
}
