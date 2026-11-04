import 'dart:typed_data';

import 'file_download_stub.dart' if (dart.library.js_interop) 'file_download_web.dart' as impl;

/// Saves [bytes] as a file in the browser's Downloads. Tests replace this.
void Function(Uint8List bytes, String fileName, String mimeType) downloadFile = impl.downloadFile;
