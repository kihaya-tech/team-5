// Android/iOS用スタブ。kIsWeb=false の環境では呼ばれない。
Future<String> enumerateCamerasWebImpl() {
  throw UnsupportedError('Web only');
}

Future<String> generateAIVideoWebImpl({
  required String title,
  required String emoji,
  required String bgStart,
  required String bgEnd,
}) {
  throw UnsupportedError('Web only');
}
