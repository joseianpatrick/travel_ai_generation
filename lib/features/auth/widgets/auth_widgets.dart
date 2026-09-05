import 'package:base_project/theme/kalsada_theme.dart';
import 'package:flutter/material.dart';

/// Rounded filled text field matching the Kalsada input style: a
/// JetBrains Mono uppercase label above a soft-grey field that gains a
/// 2px accent border on focus.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.kalsada;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: kalsadaMono(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colors.sub,
          ),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: colors.fill,
            borderRadius: BorderRadius.circular(KalsadaRadius.md),
            border: Border.all(
              color: _focused ? colors.accent : Colors.transparent,
              width: 2,
            ),
          ),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            obscureText: widget.obscure,
            keyboardType: widget.keyboardType,
            autocorrect: false,
            onSubmitted: widget.onSubmitted,
            style: TextStyle(fontSize: 16, color: colors.text),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: widget.hint,
              hintStyle: TextStyle(fontSize: 16, color: colors.ter),
            ),
          ),
        ),
      ],
    );
  }
}

/// Inline error message under the form fields.
class AuthErrorText extends StatelessWidget {
  const AuthErrorText({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 13,
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}
