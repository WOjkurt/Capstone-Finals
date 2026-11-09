import 'dart:typed_data';

import 'file_pick_stub.dart' if (dart.library.js_interop) 'file_pick_web.dart' as impl;

/// A file the user chose from their computer.
class PickedFile {
  final String name;
  final Uint8List bytes;
  const PickedFile(this.name, this.bytes);
}

/// Opens the browser's file chooser ([accept] like ".csv"). Null when cancelled. Tests replace this.
Future<PickedFile?> Function({String accept}) pickFile = impl.pickFile;
