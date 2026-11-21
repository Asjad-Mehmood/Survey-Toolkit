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
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
            widget.title,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.ink),
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
                  padding: widget.padding.copyWith(bottom: _open ? 10 : widget.padding.top),
                  child: head,
                ),
              ),
            )
          else
            Padding(padding: widget.padding.copyWith(bottom: 10), child: head),
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

/// A small circle with a step number.
class StepBadge extends StatelessWidget {
  const StepBadge(this.number, {super.key});
  final int number;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.cardSoft,
        shape: BoxShape.circle,
        border: Border.all(color: c.line),
      ),
      child: Text(
        '$number',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: c.ink),
      ),
    );
  }
}

/// A small status label: a coloured dot and the words, "Up to date", "Update available".
/// [color] is the dot (none: a plain grey label).
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color, this.textColor, this.icon});
  final String text;
  final Color? color;

  /// Unused: kept so older calls still build
  final Color? textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dot = color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: dot == null ? c.cardSoft : dot.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: dot == null ? c.muted : c.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// The bar at the top of a page: its title, a line under it, and the page's buttons on the right.
class PageHeader extends StatelessWidget implements PreferredSizeWidget {
  const PageHeader({super.key, required this.title, this.icon, this.subtitle, this.actions = const []});
  final String title;
  final IconData? icon;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(Sizes.header);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.card,
      child: Container(
        height: Sizes.header,
        padding: const EdgeInsets.only(left: 16, right: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.line)),
        ),
        child: Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 18, color: c.ink), const SizedBox(width: 10)],
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.ink),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(width: 10),
                    Flexible(
                      flex: 2,
                      child: Text(
                        subtitle!,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: c.muted, fontFeatures: tabular),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // the page's buttons; when even they don't fit, they scroll rather than spill over
            if (actions.isNotEmpty)
              LayoutBuilder(
                builder: (context, box) => ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.6),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Row(mainAxisSize: MainAxisSize.min, children: actions),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A white panel with a thin line round it, and a title above its rows (Settings)
class Panel extends StatelessWidget {
  const Panel({super.key, required this.title, required this.children, this.description, this.trailing});
  final String title;
  final String? description;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.ink),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (description != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                  child: Text(description!, style: TextStyle(color: c.muted, fontSize: 12.5, height: 1.45)),
                ),
              for (var i = 0; i < children.length; i++) ...[if (i > 0) Divider(height: 1, color: c.line), children[i]],
            ],
          ),
        ),
      ],
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
      NoticeKind.info => (c.muted, Icons.info_outline_rounded),
      NoticeKind.success => (c.rise, Icons.check_circle_outline_rounded),
      NoticeKind.warning => (c.accent, Icons.warning_amber_rounded),
      NoticeKind.problem => (c.fall, Icons.error_outline_rounded),
    };
    return Semantics(
      liveRegion: kind == NoticeKind.problem,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: kind == NoticeKind.info ? c.cardSoft : tint.withValues(alpha: dark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(Sizes.radius),
          border: Border.all(color: kind == NoticeKind.info ? c.line : tint.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: kind == NoticeKind.info ? c.muted : tint),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: TextStyle(color: c.ink, fontSize: 12.5, height: 1.45)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Each tool's own colours: its icon is a small rounded square in them, like a modern app launcher
(Color, Color) toolColours(String id) => switch (id) {
  'excel-to-kml' => (const Color(0xFF16A34A), const Color(0xFF4ADE80)),
  'roadpro' => (const Color(0xFFEA580C), const Color(0xFFFB923C)),
  'traverse' => (const Color(0xFF4F46E5), const Color(0xFF818CF8)),
  'folder-manager' => (const Color(0xFFD97706), const Color(0xFFFBBF24)),
  'slope' => (const Color(0xFF0891B2), const Color(0xFF22D3EE)),
  'auto-draft' => (const Color(0xFF7C3AED), const Color(0xFFA78BFA)),
  _ => (const Color(0xFF475569), const Color(0xFF94A3B8)),
};

/// A tool's icon: white on its own colours, with a soft shadow
class AppIcon extends StatelessWidget {
  const AppIcon({super.key, required this.id, required this.icon, this.size = 40});
  final String id;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (a, b) = toolColours(id);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [a, b]),
        borderRadius: BorderRadius.circular(size * 0.26),
        boxShadow: size >= 28
            ? [BoxShadow(color: a.withValues(alpha: 0.28), blurRadius: size * 0.3, offset: Offset(0, size * 0.08))]
            : null,
      ),
      child: Icon(icon, size: size * 0.5, color: Colors.white),
    );
  }
}

/// The soft shadow of a raised card
List<BoxShadow> softShadow(BuildContext context) => Theme.of(context).brightness == Brightness.light
    ? [
        BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.04), blurRadius: 2, offset: const Offset(0, 1)),
        BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6)),
      ]
    : [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))];
