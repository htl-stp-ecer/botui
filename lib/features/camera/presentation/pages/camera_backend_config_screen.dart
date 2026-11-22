import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
import 'package:stpvelox/core/utils/colors/colors.dart';
import 'package:stpvelox/core/widgets/large_dropdown.dart';
import 'package:stpvelox/core/widgets/themed_field.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/camera/application/camera_backend_form.dart';
import 'package:stpvelox/features/camera/data/camera_config_api.dart';
import 'package:stpvelox/features/camera/domain/camera_models.dart';
import 'package:stpvelox/features/camera/presentation/widgets/retry_button.dart';

/// Choose the camera backend or the processor (built-in or from a project) and set its options.
/// A vertical stack: the choice on top, its options below, Save and Reset.
class CameraBackendConfigScreen extends ConsumerStatefulWidget {
  const CameraBackendConfigScreen({super.key, this.kind = CamConfigKind.backend});

  /// What is configured: the backend or the processor.
  final CamConfigKind kind;

  @override
  ConsumerState<CameraBackendConfigScreen> createState() =>
      _CameraBackendConfigScreenState();
}

class _CameraBackendConfigScreenState
    extends ConsumerState<CameraBackendConfigScreen> {
  NotifierProvider<CameraBackendForm, CameraBackendFormState> get _provider =>
      widget.kind == CamConfigKind.backend
          ? cameraBackendFormProvider
          : cameraProcessorFormProvider;

  @override
  void initState() {
    super.initState();
    // What was loaded before stays in memory: it is shown at once and
    // refreshed in the background.
    Future.microtask(() => ref.read(_provider.notifier).open());
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(_provider);
    final notifier = ref.read(_provider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: createTopBar(context, widget.kind.title),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: _body(context, form, notifier),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    CameraBackendFormState form,
    CameraBackendForm notifier,
  ) {
    if (form.loading) {
      return Center(child: CircularProgressIndicator(color: AppColors.programs));
    }
    if (form.error != null) {
      return _Failure(message: form.error!, onRetry: notifier.load);
    }
    if (form.backends.isEmpty) {
      return Center(
        child: Text(
          'No camera ${widget.kind.noun}s found.',
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    final selected = form.selected;
    final labels = [for (final b in form.backends) b.label];
    return SingleChildScrollView(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LargeDropdown(
          // Follows what the form shows, not what was picked last.
          key: ValueKey(selected?.key),
          options: labels,
          initialSelected: selected?.label,
          height: 56,
          fontSize: 17,
          backgroundColor: kFormMenuColor,
          textColor: Colors.white,
          borderColor: Colors.white24,
          onChanged: (label) {
            for (final backend in form.backends) {
              if (backend.label == label) {
                notifier.select(backend.key);
                return;
              }
            }
          },
        ),
        if (selected != null && selected.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              selected.description,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
        const SizedBox(height: 10),
        // The options take the room they need; the page scrolls when they
        // do not fit, and Save and Reset follow right below them.
        if (form.describing)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.programs),
            ),
          )
        else
          _OptionsForm(form: form, notifier: notifier, noun: widget.kind.noun),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: form.busy ? null : notifier.reset,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                ),
                child: const Text('Reset'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: form.busy ? null : notifier.save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ],
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white38, size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 16),
          RetryButton(onPressed: onRetry),
        ],
      ),
    );
  }
}

/// One field per option of the selected backend.
class _OptionsForm extends ConsumerWidget {
  const _OptionsForm({
    required this.form,
    required this.notifier,
    required this.noun,
  });

  final CameraBackendFormState form;
  final CameraBackendForm notifier;
  final String noun;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backend = form.selected;
    if (backend == null) return const SizedBox.shrink();
    if (backend.options.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'This $noun has no options.',
            style: const TextStyle(color: Colors.white54, fontSize: 15),
          ),
        ),
      );
    }
    final theme = ref.watch(colorThemeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < backend.options.length; index++) ...[
          if (index > 0) const SizedBox(height: 12),
          _optionField(backend, backend.options[index], index, theme),
        ],
      ],
    );
  }

  Widget _optionField(
    CamBackendInfo backend,
    CamOption option,
    int index,
    AppTheme theme,
  ) {
    return _OptionField(
      // A new backend gets fresh fields, not the old ones' text.
      key: ValueKey('${backend.key}/${option.name}/${form.saved?.path}'),
      option: option,
      index: index,
      theme: theme,
      value: form.values[option.name],
      error: form.fieldErrors[option.name],
      onChanged: (value) => notifier.setValue(option.name, value),
      onInvalid: (message) => notifier.setFieldError(option.name, message),
    );
  }
}

class _OptionField extends StatelessWidget {
  const _OptionField({
    super.key,
    required this.option,
    required this.index,
    required this.theme,
    required this.value,
    required this.error,
    required this.onChanged,
    required this.onInvalid,
  });

  final CamOption option;
  final int index;
  final AppTheme theme;
  final Object? value;
  final String? error;
  final ValueChanged<Object?> onChanged;
  final ValueChanged<String> onInvalid;

  String get _label {
    final unit = option.unit.isEmpty ? '' : ' (${option.unit})';
    return '${option.name}$unit${option.required ? ' *' : ''}';
  }

  InputDecoration _decoration({String? label, IconData icon = Icons.tune_rounded, bool hint = true}) {
    return themedFieldDecoration(
      theme,
      index,
      label: label ?? _label,
      icon: icon,
      hint: !hint || option.description.isEmpty ? null : option.description,
    ).copyWith(errorText: error);
  }

  @override
  Widget build(BuildContext context) {
    switch (option.type) {
      case 'bool':
        return SwitchListTile(
          value: value == true,
          onChanged: onChanged,
          title: Text(option.name, style: const TextStyle(color: Colors.white)),
          subtitle: option.description.isEmpty
              ? null
              : Text(option.description,
                  style: const TextStyle(color: Colors.white54)),
        );
      case 'choice':
        return DropdownButtonFormField<Object?>(
          initialValue: option.choices.contains(value) ? value : null,
          decoration: _decoration(),
          dropdownColor: kFormMenuColor,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          items: [
            for (final choice in option.choices)
              DropdownMenuItem<Object?>(value: choice, child: Text('$choice')),
          ],
          onChanged: onChanged,
        );
      case 'size':
        final size = value is List && (value as List).length == 2
            ? (value as List).map((e) => (e as num).toInt()).toList()
            : <int>[0, 0];
        return Row(
          children: [
            Expanded(
              child: _numberField(
                '${option.name}: width',
                size[0] == 0 ? null : size[0],
                true,
                (n) => onChanged([(n as int?) ?? 0, size[1]]),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _numberField(
                'height',
                size[1] == 0 ? null : size[1],
                true,
                (n) => onChanged([size[0], (n as int?) ?? 0]),
              ),
            ),
          ],
        );
      case 'json':
        return _jsonField();
      case 'int':
        return _numberField(_label, value as num?, true, onChanged);
      case 'float':
        return _numberField(_label, value as num?, false, onChanged);
      default:
        return TextFormField(
          initialValue: value?.toString() ?? '',
          decoration: _decoration(icon: Icons.edit_rounded),
          style: const TextStyle(color: Colors.white, fontSize: 16),
          maxLength: option.length,
          onChanged: onChanged,
        );
    }
  }

  /// A list of names that the option offers (`choices`): chips to switch on and off. Anything else: the JSON itself.
  Widget _jsonField() {
    final current = value;
    final offered = option.choices.whereType<String>().toList();
    if (offered.isNotEmpty &&
        current is List &&
        current.every((entry) => entry is String)) {
      final picked = current.cast<String>();
      // No hint: an InputDecorator lays its hint out even when it is not shown, and the description of
      // the option is long, so it made the field three times as high as its chips.
      return InputDecorator(
        decoration: _decoration(hint: false),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final name in offered)
              FilterChip(
                label: Text(name),
                selected: picked.contains(name),
                onSelected: (on) => onChanged([
                  for (final other in offered)
                    if (other == name ? on : picked.contains(other)) other,
                ]),
              ),
          ],
        ),
      );
    }
    return TextFormField(
      initialValue: current == null ? '' : jsonEncode(current),
      decoration: _decoration(icon: Icons.data_object_rounded),
      style: const TextStyle(color: Colors.white, fontSize: 16),
      minLines: 1,
      maxLines: 4,
      onChanged: (text) {
        if (text.trim().isEmpty) {
          onChanged(null);
          return;
        }
        try {
          onChanged(jsonDecode(text));
        } on FormatException {
          onInvalid('Not valid JSON');
        }
      },
    );
  }

  Widget _numberField(
    String label,
    num? current,
    bool whole,
    ValueChanged<Object?> onNumber,
  ) {
    return TextFormField(
      initialValue: current == null
          ? ''
          : (whole ? current.toInt().toString() : current.toString()),
      decoration: _decoration(label: label),
      style: const TextStyle(color: Colors.white, fontSize: 16),
      keyboardType: TextInputType.numberWithOptions(decimal: !whole, signed: false),
      inputFormatters: [
        FilteringTextInputFormatter.allow(whole ? RegExp(r'[0-9]') : RegExp(r'[0-9.]')),
      ],
      onChanged: (text) {
        if (text.isEmpty) {
          onNumber(null);
          return;
        }
        final parsed = whole ? int.tryParse(text) : double.tryParse(text);
        if (parsed == null) {
          onInvalid('Not a number');
          return;
        }
        onNumber(parsed);
      },
    );
  }
}
