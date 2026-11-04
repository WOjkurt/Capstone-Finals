import 'dart:typed_data';

/// Non-web builds (tests on the Dart VM) have no browser to download into.
void downloadFile(Uint8List bytes, String fileName, String mimeType) {
  throw UnsupportedError('File download is only available in the web app.');
}
