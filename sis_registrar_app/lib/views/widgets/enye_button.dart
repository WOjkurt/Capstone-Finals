import 'package:flutter/material.dart';

/// Puts Ñ or ñ at the cursor: capital at the start of a word or in an all-capitals name.
TextEditingValue insertEnye(TextEditingValue value) {
  final picked = value.selection.isValid ? value.selection : TextSelection.collapsed(offset: value.text.length);
  final before = value.text.substring(0, picked.start);
  final capital = RegExp(r'(^|[^A-Za-zÑñ]|[A-ZÑ]{2})$').hasMatch(before);
  return TextEditingValue(
    text: '$before${capital ? 'Ñ' : 'ñ'}${value.text.substring(picked.end)}',
    selection: TextSelection.collapsed(offset: picked.start + 1),
  );
}

/// A button inside a name field, for keyboards without the letter Ñ.
class EnyeButton extends StatelessWidget {
  final TextEditingController controller;

  const EnyeButton({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Type Ñ',
        icon: const Text('Ñ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        onPressed: () => controller.value = insertEnye(controller.value),
      );
}
