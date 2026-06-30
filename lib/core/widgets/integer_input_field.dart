import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class IntegerInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? errorText;
  final Widget? suffix;
  final Widget? preview;

  const IntegerInputField({
    super.key,
    required this.label,
    required this.controller,
    this.errorText,
    this.suffix,
    this.preview,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter
                .digitsOnly, // blocks everything except 0-9 live
          ],
          decoration: InputDecoration(
            labelText: label,
            errorText: errorText,
            errorMaxLines: 3,
            suffixIcon: suffix,
          ),
        ),
        if (preview != null) ...[const SizedBox(height: 8), preview!],
      ],
    );
  }
}







