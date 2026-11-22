/// What a message for the user is: an error or a warning.
enum NoticeKind { error, warning }

/// One message for the user: a title and the text below it.
class Notice {
  const Notice(this.kind, this.title, this.content);

  final NoticeKind kind;
  final String title;
  final String content;
}

/// The messages that wait for their turn: the UI shows one dialog at a time.
///
/// A message with the same kind and title as the one on screen, or one that
/// waits already, is dropped: a fault that repeats (with other numbers in the
/// text) would otherwise stack up dialogs. At most [maxWaiting] messages wait;
/// when more come, the oldest waiting one is dropped.
class NoticeQueue {
  NoticeQueue({this.maxWaiting = 3});

  final int maxWaiting;
  final List<Notice> _waiting = [];
  Notice? _showing;

  Notice? get showing => _showing;
  int get waiting => _waiting.length;

  bool _same(Notice a, Notice b) => a.kind == b.kind && a.title == b.title;

  /// Adds [notice]. Returns it if it is to be shown now (nothing is on screen),
  /// otherwise `null`: it waits, or it is dropped as a repeat.
  Notice? add(Notice notice) {
    final current = _showing;
    if (current == null) {
      _showing = notice;
      return notice;
    }
    if (_same(current, notice) || _waiting.any((w) => _same(w, notice))) {
      return null;
    }
    _waiting.add(notice);
    if (_waiting.length > maxWaiting) _waiting.removeAt(0);
    return null;
  }

  /// The one on screen is done. Returns the next one to show, or `null`.
  Notice? next() {
    _showing = _waiting.isEmpty ? null : _waiting.removeAt(0);
    return _showing;
  }

  /// Forgets everything (the UI went away).
  void clear() {
    _showing = null;
    _waiting.clear();
  }
}
