import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:stpvelox/core/service/raccoon_execution_client.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';

final _log = Logger('LogRunScreen');

const _fontSize = 12.0;
const _lineHeight = 16.0;
const _fontFamily = 'DejaVu Sans Mono';

/// The levels that can be switched on and off, in the order of the chips.
/// Lines of any other level (e.g. CRITICAL) are always shown.
const _filterLevels = ['TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR'];
const _defaultLevels = {'INFO', 'WARN', 'ERROR'};

Color _levelColor(String level) {
  switch (level) {
    case 'TRACE':
      return Colors.grey;
    case 'DEBUG':
      return Colors.cyan.shade300;
    case 'INFO':
      return Colors.green;
    case 'WARN':
      return Colors.amber;
    default: // ERROR, CRITICAL
      return Colors.redAccent;
  }
}

String _normalize(String level) {
  final l = level.toUpperCase();
  return l == 'WARNING' ? 'WARN' : l;
}

/// The lines of one run, formatted like `raccoon logs show`, filterable by
/// level. Lines are never wrapped; the view scrolls horizontally instead.
class LogRunScreen extends StatefulWidget {
  final String projectId;

  /// Index within the project, newest = 1.
  final int runIndex;
  final String title;

  const LogRunScreen({
    super.key,
    required this.projectId,
    required this.runIndex,
    required this.title,
  });

  @override
  State<LogRunScreen> createState() => _LogRunScreenState();
}

class _LogRunScreenState extends State<LogRunScreen> {
  final Set<String> _enabled = {..._defaultLevels};
  final _vertical = ScrollController();
  final _horizontal = ScrollController();

  List<LogLine> _lines = const [];
  bool _hasFunc = false;
  List<_Row> _rows = const [];
  double _charWidth = 7.2;
  int _maxChars = 0;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _charWidth = _measureCharWidth();
    _load();
  }

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  double _measureCharWidth() {
    final painter = TextPainter(
      text: const TextSpan(
        text: 'MMMMMMMMMM',
        style: TextStyle(fontFamily: _fontFamily, fontSize: _fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width / 10;
  }

  Future<void> _load() async {
    try {
      final client = await RaccoonExecutionClient.create();
      final lines = await client.getLogRun(widget.projectId, widget.runIndex);
      _lines = lines;
      _hasFunc = lines.any((l) => l.func.isNotEmpty);
      _rebuildRows();
    } catch (e, st) {
      _log.severe('[load] failed', e, st);
      _error = e;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _visible(LogLine l) {
    final level = _normalize(l.level);
    return !_filterLevels.contains(level) || _enabled.contains(level);
  }

  void _rebuildRows() {
    final rows = <_Row>[];
    var maxChars = 0;
    for (final line in _lines.where(_visible)) {
      for (final row in _rowsFor(line, _hasFunc)) {
        rows.add(row);
        if (row.chars > maxChars) maxChars = row.chars;
      }
    }
    _rows = rows;
    _maxChars = maxChars;
  }

  void _toggle(String level) {
    setState(() {
      if (!_enabled.remove(level)) _enabled.add(level);
      _rebuildRows();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: createTopBar(context, widget.title),
      body: SafeArea(
        child: Column(
          children: [
            _filterBar(),
            Expanded(child: _content()),
          ],
        ),
      ),
    );
  }

  Widget _filterBar() {
    return Container(
      width: double.infinity,
      color: Colors.grey[900],
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          for (final level in _filterLevels)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(level),
                selected: _enabled.contains(level),
                onSelected: (_) => _toggle(level),
                showCheckmark: false,
                avatar: CircleAvatar(
                  radius: 6,
                  backgroundColor: _levelColor(level),
                ),
                labelStyle: TextStyle(
                  color: _enabled.contains(level)
                      ? Colors.white
                      : Colors.white54,
                ),
                backgroundColor: Colors.black,
                selectedColor: Colors.white24,
              ),
            ),
          const Spacer(),
          Text(
            '${_rows.length} lines',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load log:\n$_error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent, fontSize: 16),
          ),
        ),
      );
    }
    if (_rows.isEmpty) {
      return Center(
        child: Text(
          _lines.isEmpty ? 'No log lines in this run' : 'No lines for these levels',
          style: const TextStyle(color: Colors.white54, fontSize: 16),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const padding = 8.0;
        final contentWidth = _maxChars * _charWidth + 2 * padding;
        final width =
            contentWidth > constraints.maxWidth ? contentWidth : constraints.maxWidth;
        return Scrollbar(
          controller: _horizontal,
          child: SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              height: constraints.maxHeight,
              child: ListView.builder(
                controller: _vertical,
                itemCount: _rows.length,
                itemExtent: _lineHeight,
                padding: const EdgeInsets.all(padding),
                itemBuilder: (context, i) => Text.rich(
                  TextSpan(children: _rows[i].spans),
                  softWrap: false,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Row {
  final List<InlineSpan> spans;
  final int chars;

  const _Row(this.spans, this.chars);
}

String _pad(String s, int width) =>
    s.length >= width ? s.substring(0, width) : s.padRight(width);

const _base = TextStyle(
  fontFamily: _fontFamily,
  fontSize: _fontSize,
  height: _lineHeight / _fontSize,
  color: Colors.white,
);

/// `elapsed LEVEL file:line func message`, the columns of `raccoon logs show`.
/// A message with several lines becomes several rows; the continuation rows are
/// indented to the message column.
List<_Row> _rowsFor(LogLine l, bool withFunc) {
  final level = _normalize(l.level);
  final location = l.source.isEmpty
      ? ''
      : (l.line > 0 ? '${l.source}:${l.line}' : l.source);

  final elapsed = '${l.elapsed.toStringAsFixed(3).padLeft(9)}s ';
  final levelText = '${_pad(level, 8)} ';
  final locationText = '${_pad(location, 30)} ';
  final funcText = withFunc ? '${_pad(l.func, 24)} ' : '';
  final prefixChars =
      elapsed.length + levelText.length + locationText.length + funcText.length;

  final messageLines =
      l.message.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');

  final rows = <_Row>[];
  for (var i = 0; i < messageLines.length; i++) {
    final text = messageLines[i];
    if (i == 0) {
      rows.add(_Row([
        TextSpan(text: elapsed, style: _base.copyWith(color: Colors.grey)),
        TextSpan(
          text: levelText,
          style: _base.copyWith(
            color: _levelColor(level),
            fontWeight: level == 'ERROR' ? FontWeight.bold : null,
          ),
        ),
        TextSpan(
            text: locationText,
            style: _base.copyWith(color: Colors.cyan.shade300.withAlpha(150))),
        if (withFunc)
          TextSpan(
              text: funcText,
              style: _base.copyWith(
                  color: Colors.grey, fontStyle: FontStyle.italic)),
        TextSpan(text: text, style: _base),
      ], prefixChars + text.length));
    } else {
      rows.add(_Row([
        TextSpan(text: ' ' * prefixChars + text, style: _base),
      ], prefixChars + text.length));
    }
  }
  return rows;
}
