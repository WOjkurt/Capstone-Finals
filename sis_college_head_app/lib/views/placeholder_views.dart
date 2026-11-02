import 'package:flutter/material.dart';
import 'widgets/page_header.dart';

class StudentsPlaceholderView extends StatelessWidget {
  const StudentsPlaceholderView({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ComingSoon(
      title: 'Students',
      message: 'Student search and study-load building will appear here.',
    );
  }
}

class FacultyPlaceholderView extends StatelessWidget {
  const FacultyPlaceholderView({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ComingSoon(
      title: 'Faculty',
      message: 'Faculty overview across all programs will appear here.',
    );
  }
}

class _ComingSoon extends StatelessWidget {
  final String title;
  final String message;

  const _ComingSoon({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(title: title, subtitle: message),
        const Expanded(child: Center(child: Text('Coming soon.'))),
      ],
    );
  }
}
