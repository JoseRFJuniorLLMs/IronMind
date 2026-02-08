class AppAssets {
  static const String imagesPath = 'assets/images';
  static const String soundsPath = 'assets/sounds';
  static const String videosPath = 'assets/videos';

  static const String logo = '$imagesPath/eva_logo.png';
  static const String icon = '$imagesPath/icone.png';
  static const String logoTransparent = '$imagesPath/eva_transparent.png';

  static const String callIncoming = '$soundsPath/call_incoming.mp3';
  static const String callEnded = '$soundsPath/call_ended.mp3';
  static const String notification = '$soundsPath/notifica.mp3';
  static const String ringtone = '$soundsPath/ringtone.mp3';

  // Videos for call background
  static const List<String> callVideos = [
    '$videosPath/EVA.mp4',
    '$videosPath/EVA2.mp4',
    '$videosPath/EVA4.mp4',
  ];
}
