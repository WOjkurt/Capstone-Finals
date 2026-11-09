import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'file_pick.dart';

Future<PickedFile?> pickFile({String accept = ''}) {
  final done = Completer<PickedFile?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept
    ..style.display = 'none';
  web.document.body?.append(input);

  void finish(PickedFile? file) {
    if (!done.isCompleted) done.complete(file);
    input.remove();
  }

  input.addEventListener('change', (web.Event _) {
    final file = input.files?.item(0);
    if (file == null) return finish(null);
    file.arrayBuffer().toDart.then((buffer) => finish(PickedFile(file.name, buffer.toDart.asUint8List())),
        onError: (_) => finish(null));
  }.toJS);
  input.addEventListener('cancel', ((web.Event _) => finish(null)).toJS);
  input.click();
  return done.future;
}
