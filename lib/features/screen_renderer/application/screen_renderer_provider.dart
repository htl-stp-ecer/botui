import 'dart:async';
import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:stpvelox/core/transport/domain/providers.dart';
import 'package:stpvelox/core/logging/has_logging.dart';
import 'package:raccoon_transport/messages/types/screen_render_t.g.dart';
import 'package:raccoon_transport/raccoon_transport.dart';

part 'screen_renderer_provider.g.dart';

@Riverpod(keepAlive: true)
class ScreenRenderProvider extends _$ScreenRenderProvider with HasLogger {
  int _messageCounter = 0;

  @override
  Map<String, dynamic>? build() {
    log.info('[ScreenRenderProvider] build() called, initializing...');
    ref.onDispose(_dispose);
    _startSubscription();
    return null;
  }

  StreamSubscription? _subscription;

  void clear() {
    log.info('[ScreenRenderProvider] clear() called, setting state to null');
    state = null;
  }

  void _startSubscription() {
    final transport = ref.read(transportServiceProvider);
    log.info('[ScreenRenderProvider] Starting transport subscription on ${Channels.screenRender}');

    _subscription = transport
        .subscribeAs<ScreenRenderT>(
      Channels.screenRender,
      ScreenRenderT.decode,
    )
        .listen((decoded) async {
      _messageCounter++;
      final msgId = _messageCounter;
      final rawEntries = decoded.value.entries;
      final screenName = decoded.value.screen_name;
      final timestamp = DateTime.now().toIso8601String();

      log.info('[LCM RX #$msgId @ $timestamp] screen_render <- name=$screenName');
      log.fine('[LCM RX #$msgId] raw entries (${rawEntries.length} chars): ${rawEntries.substring(0, rawEntries.length > 200 ? 200 : rawEntries.length)}...');

      try {
        Map<String, dynamic> parsed = jsonDecode(rawEntries) as Map<String, dynamic>;
        log.fine('[LCM RX #$msgId] JSON parsed successfully, keys: ${parsed.keys.toList()}');

        if (screenName == 'dynamic_ui') {
          log.info('[LCM RX #$msgId] Processing dynamic_ui message, current state: ${state != null ? "open" : "closed"}');

          if (parsed['screen'] == 'close') {
            log.info('[LCM RX #$msgId] Closing dynamic UI screen');
            clear();
          } else {
            final title = parsed['title'] ?? '<no title>';
            final bodyType = parsed['body']?['widget'] ?? '<no body widget>';
            log.info('[LCM RX #$msgId] Updating dynamic UI data: title="$title", body widget="$bodyType"');
            state = parsed;
            log.info('[LCM RX #$msgId] State updated with new screen data');
          }
        } else {
          log.warning('[LCM RX #$msgId] Unknown screen_name: $screenName, ignoring');
        }
      } catch (e, stackTrace) {
        log.severe('[LCM RX #$msgId] Error processing screen_render message: $e');
        log.severe('[LCM RX #$msgId] Stack trace: $stackTrace');
      }
    }, onError: (error, stackTrace) {
      log.severe('[ScreenRenderProvider] transport subscription error: $error');
      log.severe('[ScreenRenderProvider] Stack trace: $stackTrace');
    });

    log.info('[ScreenRenderProvider] transport subscription started');
  }

  void _dispose() {
    log.info('[ScreenRenderProvider] _dispose() called, cancelling subscription');
    _subscription?.cancel();
    _subscription = null;
    log.info('[ScreenRenderProvider] Subscription cancelled');
  }
}
