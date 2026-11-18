import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/core/logging/logging.dart';
import 'package:stpvelox/core/service/raccoon_execution_client.dart';
import 'package:stpvelox/core/widgets/app_toast.dart';
import 'package:stpvelox/features/camera/data/camera_config_api.dart';
import 'package:stpvelox/features/camera/domain/camera_models.dart';

final _log = getLogger('CameraBackendForm');

/// The "Configure backend" screen: which backend, and the values of its options.
class CameraBackendFormState {
  const CameraBackendFormState({
    this.loading = true,
    this.error,
    this.backends = const [],
    this.selected,
    this.values = const {},
    this.fieldErrors = const {},
    this.busy = false,
    this.describing = false,
    this.saved,
  });

  /// The list is being fetched.
  final bool loading;

  /// Why the list could not be fetched.
  final String? error;
  final List<CamBackendInfo> backends;

  /// The chosen backend, with its options.
  final CamBackendInfo? selected;

  /// Option name to its current value: a number, a string, a bool, or `[w, h]`.
  final Map<String, Object?> values;
  final Map<String, String> fieldErrors;

  /// A backend is being described, or the configuration is being saved.
  final bool busy;

  /// The options and values of [selected] are being fetched: no form yet.
  final bool describing;

  /// What is saved on the robot.
  final CamBackendChoice? saved;

  CameraBackendFormState copyWith({
    bool? loading,
    String? error,
    bool clearError = false,
    List<CamBackendInfo>? backends,
    CamBackendInfo? selected,
    Map<String, Object?>? values,
    Map<String, String>? fieldErrors,
    bool? busy,
    bool? describing,
    CamBackendChoice? saved,
    bool clearSaved = false,
  }) =>
      CameraBackendFormState(
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        backends: backends ?? this.backends,
        selected: selected ?? this.selected,
        values: values ?? this.values,
        fieldErrors: fieldErrors ?? this.fieldErrors,
        busy: busy ?? this.busy,
        describing: describing ?? this.describing,
        saved: clearSaved ? null : (saved ?? this.saved),
      );
}

class CameraBackendForm extends Notifier<CameraBackendFormState> {
  CameraConfigApi? _api;
  bool _disposed = false;

  /// How often the choice on the robot was changed (saved or reset) since the
  /// app started. The camera screen compares it to know the camera restarts.
  int changes = 0;

  @override
  CameraBackendFormState build() {
    ref.onDispose(() => _disposed = true);
    return const CameraBackendFormState();
  }

  /// Called whenever the screen is shown. The first time it loads, with a
  /// spinner. Later the list from the last time is shown at once, with the
  /// saved values and without unsaved edits, and refreshed in the background.
  Future<void> open() async {
    final cached = state.backends;
    if (cached.isEmpty || state.error != null) return load();
    final first = _pick(cached, state.saved);
    if (first != null) await _describe(first);
    return load(silent: true);
  }

  /// The backend to show first: the saved one if it is in the list.
  CamBackendInfo? _pick(List<CamBackendInfo> backends, CamBackendChoice? saved) {
    if (saved != null) {
      for (final backend in backends) {
        final sameClass = backend.path == saved.path;
        final sameProject = backend.isBuiltIn || backend.projectDir == saved.projectDir;
        if (sameClass && sameProject) return backend;
      }
    }
    return backends.isEmpty ? null : backends.first;
  }

  void _emit(CameraBackendFormState next) {
    if (!_disposed) state = next;
  }

  Future<CameraConfigApi> _client() async =>
      _api ??= await CameraConfigApi.create();

  /// Fetches the list and the saved choice. [silent]: keep showing what is
  /// there, no spinner, and a failure does not replace it with an error.
  Future<void> load({bool silent = false}) async {
    if (!silent) _emit(state.copyWith(loading: true, clearError: true));
    try {
      final api = await _client();
      final backends = await api.listBackends();
      final saved = await api.savedChoice();
      final first = _pick(backends, saved);
      _emit(state.copyWith(
        loading: false,
        backends: backends,
        saved: saved,
        clearSaved: saved == null,
      ));
      // Silent and nothing changed for the backend on show: leave the form alone.
      final shown = state.selected;
      if (silent && shown != null && first != null && shown.key == first.key) return;
      if (first != null) await _describe(first);
    } on RaccoonApiException catch (error) {
      if (!silent) _emit(state.copyWith(loading: false, error: error.message));
    } catch (error, stack) {
      _log.severe('Could not load the camera backends: $error', error, stack);
      if (!silent) {
        _emit(state.copyWith(
            loading: false, error: 'The robot server is not reachable.'));
      }
    }
  }

  /// The dropdown picked [key] (see [CamBackendInfo.key]).
  Future<void> select(String key) async {
    for (final backend in state.backends) {
      if (backend.key == key) {
        await _describe(backend);
        return;
      }
    }
  }

  Future<void> _describe(CamBackendInfo backend) async {
    // A built-in backend came with its options in the list: asking the robot
    // again would start another process there, over a second on a Pi 3.
    final known = backend.isBuiltIn && backend.options.isNotEmpty;
    if (!known) {
      // Do not show options before the values (defaults, saved choice) are in.
      _emit(state.copyWith(
        busy: true,
        describing: true,
        selected: backend.withOptions(const []),
        values: const {},
        fieldErrors: {},
      ));
    }
    try {
      final described = known ? backend : await (await _client()).describe(backend);
      final values = <String, Object?>{
        for (final option in described.options)
          option.name: _normalise(option, option.defaultValue),
      };
      final saved = state.saved;
      if (saved != null && saved.path == described.path) {
        for (final option in described.options) {
          if (saved.cfg.containsKey(option.name)) {
            values[option.name] = _normalise(option, saved.cfg[option.name]);
          }
        }
      }
      _emit(state.copyWith(
        busy: false,
        describing: false,
        selected: described,
        values: values,
        fieldErrors: {},
      ));
    } on RaccoonApiException catch (error) {
      _emit(state.copyWith(busy: false, describing: false));
      AppToast.error(error.message);
    } catch (error, stack) {
      _log.severe('Could not describe ${backend.path}: $error', error, stack);
      _emit(state.copyWith(busy: false, describing: false));
      AppToast.error('The robot server is not reachable.');
    }
  }

  /// A size comes as `[w, h]`; everything else as it is.
  static Object? _normalise(CamOption option, Object? value) {
    if (option.type == 'size' && value is List) {
      return value.map((e) => (e as num).toInt()).toList();
    }
    return value;
  }

  void setValue(String name, Object? value) {
    final errors = Map<String, String>.from(state.fieldErrors)..remove(name);
    _emit(state.copyWith(
      values: {...state.values, name: value},
      fieldErrors: errors,
    ));
  }

  void setFieldError(String name, String message) {
    _emit(state.copyWith(fieldErrors: {...state.fieldErrors, name: message}));
  }

  /// What is sent: the options that have a value.
  Map<String, dynamic> _config() {
    final backend = state.selected;
    final cfg = <String, dynamic>{};
    if (backend == null) return cfg;
    for (final option in backend.options) {
      final value = state.values[option.name];
      if (value == null || (value is String && value.isEmpty)) continue;
      cfg[option.name] = value;
    }
    return cfg;
  }

  Future<void> save() async {
    final backend = state.selected;
    if (backend == null || state.busy) return;
    if (state.fieldErrors.isNotEmpty) {
      AppToast.error('Fix the marked fields first.');
      return;
    }
    for (final option in backend.options) {
      final value = state.values[option.name];
      if (option.required && (value == null || (value is String && value.isEmpty))) {
        setFieldError(option.name, 'Required');
        AppToast.error('${option.name} is required.');
        return;
      }
    }
    _emit(state.copyWith(busy: true));
    try {
      final saved = await (await _client()).save(backend, _config());
      changes++;
      _emit(state.copyWith(busy: false, saved: saved));
      AppToast.success('Camera backend saved');
    } on RaccoonApiException catch (error) {
      _emit(state.copyWith(busy: false));
      AppToast.error(error.message);
    } catch (error, stack) {
      _log.severe('Could not save the camera backend: $error', error, stack);
      _emit(state.copyWith(busy: false));
      AppToast.error('The robot server is not reachable.');
    }
  }

  /// Forgets the saved choice: the camera service goes back to its own default.
  Future<void> reset() async {
    if (state.busy) return;
    _emit(state.copyWith(busy: true));
    try {
      await (await _client()).clear();
      changes++;
      _emit(state.copyWith(busy: false, clearSaved: true));
      final backend = state.selected;
      if (backend != null) await _describe(backend);
      AppToast.success('Camera backend reset');
    } on RaccoonApiException catch (error) {
      _emit(state.copyWith(busy: false));
      AppToast.error(error.message);
    } catch (error, stack) {
      _log.severe('Could not reset the camera backend: $error', error, stack);
      _emit(state.copyWith(busy: false));
      AppToast.error('The robot server is not reachable.');
    }
  }
}

/// Not auto-disposed: the list and the options stay in memory until the app
/// restarts (so, per boot), and the screen shows them at once when it is opened
/// again. [CameraBackendForm.open] refreshes them in the background.
final cameraBackendFormProvider =
    NotifierProvider<CameraBackendForm, CameraBackendFormState>(
  CameraBackendForm.new,
);
