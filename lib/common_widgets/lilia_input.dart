import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/lilia_tokens.dart';

class LiliaInput extends StatefulWidget {
  const LiliaInput({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.errorText,
    this.enabled = true,
    this.autofocus = false,
    this.maxLines = 1,
  });

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final VoidCallback? onSuffixTap;
  final String? errorText;
  final bool enabled;
  final bool autofocus;
  final int maxLines;

  @override
  State<LiliaInput> createState() => _LiliaInputState();
}

class _LiliaInputState extends State<LiliaInput> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = isDark ? LiliaSemantics.dark : LiliaSemantics.light;
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w600, color: t.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Focus(
          onFocusChange: (v) => setState(() => _focused = v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: t.bgElevated,
              borderRadius: LiliaRadius.mdAll,
              border: Border.all(
                color: hasError
                    ? t.danger
                    : _focused
                        ? t.borderFocus
                        : t.border,
                width: 1.5,
              ),
              boxShadow: _focused && !hasError
                  ? [BoxShadow(color: t.borderFocus.withValues(alpha: 0.12), blurRadius: 0, spreadRadius: 3)]
                  : null,
            ),
            child: Row(
              children: [
                if (widget.prefixIcon != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 14),
                    child: IconTheme(
                      data: IconThemeData(
                        color: _focused ? t.borderFocus : t.textMuted,
                        size: 18,
                      ),
                      child: widget.prefixIcon!,
                    ),
                  ),
                Expanded(
                  child: TextFormField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.textInputAction,
                    obscureText: widget.obscureText,
                    onChanged: widget.onChanged,
                    onFieldSubmitted: widget.onSubmitted,
                    validator: widget.validator,
                    enabled: widget.enabled,
                    autofocus: widget.autofocus,
                    maxLines: widget.maxLines,
                    style: GoogleFonts.inter(
                      fontSize: 15, color: t.textPrimary, fontWeight: FontWeight.w400,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      hintStyle: GoogleFonts.inter(fontSize: 15, color: t.textMuted),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: widget.prefixIcon != null ? 10 : 16,
                        vertical: 13,
                      ),
                    ),
                  ),
                ),
                if (widget.suffixIcon != null)
                  GestureDetector(
                    onTap: widget.onSuffixTap,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: IconTheme(
                        data: IconThemeData(color: t.textMuted, size: 18),
                        child: widget.suffixIcon!,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Text(
            widget.errorText!,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: t.danger),
          ),
        ],
      ],
    );
  }
}
