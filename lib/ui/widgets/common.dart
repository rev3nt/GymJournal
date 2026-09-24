import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.accentOn,
          disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radius)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: -0.16,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.fg,
          side: const BorderSide(color: AppColors.border),
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radius)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: -0.16,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: monoStyle(
          fontSize: 11,
          letterSpacing: 0.8,
          color: AppColors.muted,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class PageTitle extends StatelessWidget {
  const PageTitle(this.text, {super.key, this.fontSize = 28});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.03 * fontSize,
        color: AppColors.fg,
        height: 1.15,
      ),
    );
  }
}

OverlayEntry? _toastEntry;

void showAppToast(BuildContext context, String message) {
  _toastEntry?.remove();
  _toastEntry = null;

  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) {
      final bottom = MediaQuery.paddingOf(ctx).bottom + 96;
      return Positioned(
        left: 16,
        right: 16,
        bottom: bottom,
        child: IgnorePointer(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppColors.radius),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  _toastEntry = entry;
  overlay.insert(entry);
  Future<void>.delayed(const Duration(milliseconds: 1600), () {
    if (_toastEntry == entry) {
      entry.remove();
      _toastEntry = null;
    }
  });
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String cancelLabel = 'Отмена',
  String confirmLabel = 'OK',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final confirmBg = destructive ? AppColors.danger : AppColors.accent;
      final confirmFg = destructive ? Colors.white : AppColors.accentOn;
      return AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message, style: const TextStyle(height: 1.35)),
            const SizedBox(height: 22),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: confirmBg,
                  foregroundColor: confirmFg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radius),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                child: Text(confirmLabel),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.fg,
                  side: const BorderSide(color: AppColors.border),
                  backgroundColor: AppColors.bg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radius),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 17,
                  ),
                ),
                child: Text(cancelLabel),
              ),
            ),
          ],
        ),
      );
    },
  );
  return result ?? false;
}

class NumericField extends StatelessWidget {
  const NumericField({
    super.key,
    required this.label,
    required this.onChanged,
    this.value,
    this.decimal = false,
    this.tint,
    this.controller,
    this.focusNode,
  });

  final String label;
  final String? value;
  final ValueChanged<String> onChanged;
  final bool decimal;
  final Color? tint;
  final TextEditingController? controller;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    assert(controller != null || value != null, 'Provide controller or value');
    final color = tint ?? AppColors.fg;
    final border = tint ?? AppColors.border;
    final fill = tint != null ? tint!.withValues(alpha: 0.14) : AppColors.bg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: monoStyle(
            fontSize: 11,
            letterSpacing: 0.4,
            color: tint ?? AppColors.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 52,
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            initialValue: controller == null ? value : null,
            // Stable key — never include the typed value (that dismisses the keyboard).
            key: controller == null ? ValueKey(label) : null,
            keyboardType: TextInputType.numberWithOptions(decimal: decimal),
            textAlign: TextAlign.center,
            cursorColor: color,
            inputFormatters: [
              if (decimal)
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              else
                FilteringTextInputFormatter.digitsOnly,
            ],
            style: monoStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: -0.4,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: fill,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppColors.radius),
                borderSide: BorderSide(color: border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppColors.radius),
                borderSide: BorderSide(color: border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppColors.radius),
                borderSide: BorderSide(color: color, width: 1.5),
              ),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
