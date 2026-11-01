// The building blocks every screen is made of.
import 'package:flutter/material.dart';

import 'theme.dart';

/// A card with a numbered step and a title. Optional tools fold away until opened.
class SectionCard extends StatefulWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.step,
    this.optional = false,
    this.initiallyOpen = true,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 20),
  });

  final String title;
  final Widget child;
  final int? step;

  /// Shows an "Optional" tag and folds the card when its title is pressed
  final bool optional;
  final bool initiallyOpen;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  State<SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<SectionCard> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final title = Row(
      children: [
        if (widget.step != null) ...[StepBadge(widget.step!), const SizedBox(width: 12)],
        Expanded(
          child: Text(
            widget.title.toUpperCase(),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: c.ink),
          ),
        ),
        if (widget.optional) ...[const Tag('Optional'), const SizedBox(width: 6)],
        if (widget.optional)
          Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: c.muted, semanticLabel: null),
      ],
    );
    // the extra on the right goes under the title when the card is narrow (sooner with larger
    // text), and never takes more than half the width beside it
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final head = widget.trailing == null
        ? title
        : LayoutBuilder(
            builder: (context, box) => box.maxWidth < 560 * scale
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, const SizedBox(height: 10), widget.trailing!],
                  )
                : Row(
                    children: [
                      Expanded(child: title),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Align(alignment: Alignment.centerRight, child: widget.trailing),
                      ),
                    ],
                  ),
          );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.optional)
            Semantics(
              button: true,
              expanded: _open,
              child: InkWell(
                onTap: () => setState(() => _open = !_open),
                child: Padding(
                  padding: widget.padding.copyWith(bottom: _open ? 14 : widget.padding.top),
                  child: head,
                ),
              ),
            )
          else
            Padding(padding: widget.padding.copyWith(bottom: 14), child: head),
          AnimatedSize(
            duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(padding: widget.padding.copyWith(top: 0), child: widget.child)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// The gold circle with a step number.
class StepBadge extends StatelessWidget {
  const StepBadge(this.number, {super.key});
  final int number;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
      child: Text(
        '$number',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: c.onAccent),
      ),
    );
  }
}

/// A small rounded label: "Up to date", "Update available".
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color, this.textColor, this.icon});
  final String text;
  final Color? color;
  final Color? textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = textColor ?? c.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? c.cardSoft,
        borderRadius: BorderRadius.circular(99),
        border: color == null ? Border.all(color: c.line) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              text.toUpperCase(),
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

enum NoticeKind { info, success, warning, problem }

/// A line of guidance, a result sentence or a problem with the input.
class Notice extends StatelessWidget {
  const Notice(this.text, {super.key, this.kind = NoticeKind.info});
  final String text;
  final NoticeKind kind;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (Color tint, IconData icon) = switch (kind) {
      NoticeKind.info => (c.accent, Icons.info_outline_rounded),
      NoticeKind.success => (c.rise, Icons.check_circle_outline_rounded),
      NoticeKind.warning => (c.accent, Icons.warning_amber_rounded),
      NoticeKind.problem => (c.fall, Icons.error_outline_rounded),
    };
    return Semantics(
      liveRegion: kind == NoticeKind.problem,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: dark ? 0.12 : 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tint.withValues(alpha: 0.45)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: kind == NoticeKind.info || kind == NoticeKind.warning ? c.ink : tint),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: c.ink, fontWeight: FontWeight.w500, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
