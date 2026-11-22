/// What a message for the user is: an error or a warning.
enum NoticeKind { error, warning }

/// One message for the user: a title and the text below it.
class Notice {
  const Notice(this.kind, this.title, this.content);

  final NoticeKind kind;
  final String title;
  final String content;
}

/// What [NoticeQueue.add] did with a notice.
enum NoticeResult {
  /// Nothing was on screen: show it now.
  shownNow,

  /// The notice on screen has the same kind and title: its text is replaced.
  updatedShowing,

  /// A waiting notice has the same kind and title: its text is replaced.
  updatedWaiting,

  /// It waits for its turn.
  queued,
}

/// The messages that wait for their turn: the UI shows one dialog at a time.
///
/// A message with the same kind and title as the one on screen, or as one that
/// waits already, replaces its text instead of opening another dialog: a fault
/// that repeats (with other numbers in the text, or an error that ends in its
/// final message) would otherwise stack up dialogs, and the latest text is the
/// one that counts. At most [maxWaiting] messages wait; when more come, the
/// oldest waiting one is dropped.
class NoticeQueue {
  NoticeQueue({this.maxWaiting = 3});

  final int maxWaiting;
  final List<Notice> _waiting = [];
  Notice? _showing;

  Notice? get showing => _showing;
  int get waiting => _waiting.length;

  bool _same(Notice a, Notice b) => a.kind == b.kind && a.title == b.title;

  /// Adds [notice] and says what has to happen on screen.
  NoticeResult add(Notice notice) {
    final current = _showing;
    if (current == null) {
      _showing = notice;
      return NoticeResult.shownNow;
    }
    if (_same(current, notice)) {
      _showing = notice;
      return NoticeResult.updatedShowing;
    }
    final index = _waiting.indexWhere((w) => _same(w, notice));
    if (index >= 0) {
      _waiting[index] = notice;
      return NoticeResult.updatedWaiting;
    }
    _waiting.add(notice);
    if (_waiting.length > maxWaiting) _waiting.removeAt(0);
    return NoticeResult.queued;
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
