import 'package:flutter_test/flutter_test.dart';
import 'package:stpvelox/core/service/notice_queue.dart';

void main() {
  Notice error(String title, [String content = 'text']) =>
      Notice(NoticeKind.error, title, content);
  Notice warning(String title, [String content = 'text']) =>
      Notice(NoticeKind.warning, title, content);

  test('the first notice is shown at once, the next ones wait', () {
    final queue = NoticeQueue();
    final first = error('first');
    expect(queue.add(first), NoticeResult.shownNow);
    expect(queue.add(warning('second')), NoticeResult.queued);
    expect(queue.waiting, 1);
    expect(queue.showing, same(first));
  });

  test('when one is done the next one comes in the order of arrival', () {
    final queue = NoticeQueue();
    queue.add(error('a'));
    queue.add(warning('b'));
    queue.add(error('c'));
    expect(queue.next()?.title, 'b');
    expect(queue.next()?.title, 'c');
    expect(queue.next(), isNull);
    expect(queue.showing, isNull);
    // With nothing on screen the next notice is shown at once again.
    expect(queue.add(error('d')), NoticeResult.shownNow);
  });

  test('the same kind and title replaces the text of the notice on screen', () {
    final queue = NoticeQueue();
    queue.add(error('Camera problem', 'could not open camera (attempt 6)'));
    final last = error('Camera problem', 'could not open camera after 10 attempts');
    expect(queue.add(last), NoticeResult.updatedShowing);
    expect(queue.showing, same(last));
    expect(queue.waiting, 0);
  });

  test('the same kind and title replaces the text of a waiting notice', () {
    final queue = NoticeQueue();
    queue.add(error('showing'));
    queue.add(warning('Slow control loop', 'took 64 ms'));
    final latest = warning('Slow control loop', 'took 70 ms');
    expect(queue.add(latest), NoticeResult.updatedWaiting);
    expect(queue.waiting, 1);
    expect(queue.next(), same(latest));
  });

  test('the same title as a warning and as an error are two notices', () {
    final queue = NoticeQueue();
    queue.add(warning('Slow control loop'));
    expect(queue.add(error('Slow control loop')), NoticeResult.queued);
    expect(queue.waiting, 1);
  });

  test('only a few notices wait, the oldest one goes first', () {
    final queue = NoticeQueue(maxWaiting: 2);
    queue.add(error('showing'));
    queue.add(error('w1'));
    queue.add(error('w2'));
    queue.add(error('w3'));
    expect(queue.waiting, 2);
    expect(queue.next()?.title, 'w2');
    expect(queue.next()?.title, 'w3');
  });

  test('clear forgets everything', () {
    final queue = NoticeQueue();
    queue.add(error('a'));
    queue.add(error('b'));
    queue.clear();
    expect(queue.showing, isNull);
    expect(queue.waiting, 0);
  });
}
