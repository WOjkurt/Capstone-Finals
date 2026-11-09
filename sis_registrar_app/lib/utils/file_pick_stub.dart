import 'file_pick.dart';

/// Non-web builds (tests on the Dart VM) have no file chooser.
Future<PickedFile?> pickFile({String accept = ''}) async {
  throw UnsupportedError('Choosing a file is only available in the web app.');
}
