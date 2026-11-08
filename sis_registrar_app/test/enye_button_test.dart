import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sis_registrar_app/views/widgets/enye_button.dart';

TextEditingValue typedAt(String text, int cursor) =>
    TextEditingValue(text: text, selection: TextSelection.collapsed(offset: cursor));

void main() {
  test('small letter inside a word', () {
    final result = insertEnye(typedAt('Pea', 2));
    expect(result.text, 'Peña');
    expect(result.selection.baseOffset, 3);
  });

  test('capital at the start of a word', () {
    expect(insertEnye(typedAt('', 0)).text, 'Ñ');
    expect(insertEnye(typedAt('De la ', 6)).text, 'De la Ñ');
    expect(insertEnye(typedAt('Santos-', 7)).text, 'Santos-Ñ');
  });

  test('capital in an all-capitals name', () {
    expect(insertEnye(typedAt('PEA', 2)).text, 'PEÑA');
  });

  test('replaces selected text', () {
    final value = const TextEditingValue(
      text: 'Pena',
      selection: TextSelection(baseOffset: 2, extentOffset: 3),
    );
    expect(insertEnye(value).text, 'Peña');
  });

  test('adds to the end when the field was never clicked', () {
    expect(insertEnye(const TextEditingValue(text: 'Pe')).text, 'Peñ');
  });

  testWidgets('the button types into its field', (tester) async {
    final controller = TextEditingController(text: 'Pe');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TextField(
          controller: controller,
          decoration: InputDecoration(suffixIcon: EnyeButton(controller: controller)),
        ),
      ),
    ));

    await tester.tap(find.byTooltip('Type Ñ'));
    await tester.pump();

    expect(controller.text, 'Peñ');
  });
}
