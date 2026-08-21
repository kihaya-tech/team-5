// Web専用: camera_helper.js の enumerateCamerasWeb() を呼ぶ実装。
// dart:js_interop はこのファイルにのみ閉じ込める。

import 'dart:js_interop';

@JS('enumerateCamerasWeb')
external JSPromise<JSString> _enumerateCamerasWebJS();

@JS('generateAIVideoWeb')
external JSPromise<JSString> _generateAIVideoWebJS(
  JSString title,
  JSString emoji,
  JSString bgStart,
  JSString bgEnd,
);

Future<String> enumerateCamerasWebImpl() async {
  final result = await _enumerateCamerasWebJS().toDart;
  return result.toDart;
}

Future<String> generateAIVideoWebImpl({
  required String title,
  required String emoji,
  required String bgStart,
  required String bgEnd,
}) async {
  final result = await _generateAIVideoWebJS(
    title.toJS,
    emoji.toJS,
    bgStart.toJS,
    bgEnd.toJS,
  ).toDart;
  return result.toDart;
}
