import 'package:flutter/material.dart';

/// A success or error line below a form's main button.
class StatusMessage extends StatelessWidget {
  const StatusMessage.success(this.text, {super.key}) : isError = false;
  const StatusMessage.error(this.text, {super.key}) : isError = true;

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error : Icons.check_circle,
            color: isError ? colors.error : colors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(child: SelectableText(text)),
        ],
      ),
    );
  }
}
