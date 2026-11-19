import 'package:flutter/widgets.dart';

import '../tokens/aero_tokens.dart';

/// Gras, code et liens d'une ligne de Markdown.
final RegExp _inline = RegExp(
  r'\*\*(.+?)\*\*|`([^`]+)`|\[([^\]]+)\]\(([^)]+)\)',
);

/// Ligne de séparation d'un tableau : `|---|:---:|`.
final RegExp _tableRule = RegExp(
  r'^\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)*\|?$',
);

/// Affiche le Markdown des notes de version : titres, listes, tableaux,
/// paragraphes, gras, code et liens (leur texte seul : une TV n'a pas de
/// navigateur).
class MarkdownText extends StatelessWidget {
  const MarkdownText(this.source, {super.key});

  final String source;

  @override
  Widget build(BuildContext context) {
    final blocks = <Widget>[];
    final paragraph = <String>[];
    final table = <List<String>>[];

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      blocks.add(_Block(child: _rich(paragraph.join(' '), AeroText.body)));
      paragraph.clear();
    }

    void flushTable() {
      if (table.isEmpty) return;
      blocks.add(_Block(child: _Table(rows: [...table])));
      table.clear();
    }

    for (final raw in source.replaceAll('\r\n', '\n').split('\n')) {
      final line = raw.trimRight();
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('|')) {
        flushParagraph();
        if (!_tableRule.hasMatch(trimmed)) table.add(_cells(trimmed));
        continue;
      }
      flushTable();
      if (trimmed.isEmpty) {
        flushParagraph();
      } else if (trimmed.startsWith('#')) {
        flushParagraph();
        final level = trimmed.indexOf(RegExp('[^#]'));
        final text = trimmed.substring(level < 0 ? 0 : level).trim();
        blocks.add(
          _Block(
            top: 10,
            child: _rich(
              text,
              level <= 1
                  ? AeroText.title
                  : AeroText.heading.copyWith(color: AeroColors.aqua),
            ),
          ),
        );
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        flushParagraph();
        blocks.add(
          _Block(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '•  ',
                  style: AeroText.body.copyWith(color: AeroColors.aqua),
                ),
                Expanded(child: _rich(trimmed.substring(2), AeroText.body)),
              ],
            ),
          ),
        );
      } else {
        paragraph.add(trimmed);
      }
    }
    flushParagraph();
    flushTable();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: blocks,
    );
  }

  static List<String> _cells(String row) {
    var inner = row.trim();
    if (inner.startsWith('|')) inner = inner.substring(1);
    if (inner.endsWith('|')) inner = inner.substring(0, inner.length - 1);
    return [for (final cell in inner.split('|')) cell.trim()];
  }

  static Widget _rich(String text, TextStyle style) =>
      Text.rich(TextSpan(style: style, children: _spans(text, style)));

  static List<InlineSpan> _spans(String text, TextStyle style) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final match in _inline.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      if (match.group(1) case final bold?) {
        spans.add(
          TextSpan(
            text: bold,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        );
      } else if (match.group(2) case final code?) {
        spans.add(
          TextSpan(
            text: code,
            style: TextStyle(
              color: AeroColors.aqua,
              fontSize: (style.fontSize ?? 16) * 0.92,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: match.group(3),
            style: const TextStyle(color: AeroColors.aqua),
          ),
        );
      }
      last = match.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.child, this.top = 0});

  final Widget child;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: top, bottom: 8),
    child: child,
  );
}

/// Tableau : la première ligne en en-tête.
class _Table extends StatelessWidget {
  const _Table({required this.rows});

  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final columns = rows.fold(
      0,
      (count, row) => row.length > count ? row.length : count,
    );
    return Table(
      border: const TableBorder(
        horizontalInside: BorderSide(color: Color(0x33BFE6FA)),
      ),
      children: [
        for (final (index, row) in rows.indexed)
          TableRow(
            children: [
              for (var column = 0; column < columns; column++)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: MarkdownText._rich(
                    column < row.length ? row[column] : '',
                    index == 0
                        ? AeroText.body.copyWith(fontWeight: FontWeight.w600)
                        : AeroText.body,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
