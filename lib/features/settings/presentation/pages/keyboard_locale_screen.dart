import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stpvelox/application/theme/color_theme_provider.dart';
import 'package:stpvelox/core/theme/app_theme.dart';
import 'package:stpvelox/core/widgets/app_toast.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/settings/data/system_config_service.dart';

/// Lets the user pick the physical keyboard layout (XKB / libinput).
class KeyboardLocaleScreen extends ConsumerStatefulWidget {
  const KeyboardLocaleScreen(
      {super.key, this.service = const SystemConfigService()});

  final SystemConfigService service;

  @override
  ConsumerState<KeyboardLocaleScreen> createState() =>
      _KeyboardLocaleScreenState();
}

class _KeyboardLocaleScreenState extends ConsumerState<KeyboardLocaleScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final current = await widget.service.getKeyboardLayout();
    if (!mounted) return;
    setState(() {
      _selected = current;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final code = _selected;
    if (code == null) return;
    setState(() => _saving = true);
    final outcome = await widget.service.setKeyboardLayout(code);
    if (!mounted) return;
    setState(() => _saving = false);
    if (outcome.ok) {
      AppToast.success(outcome.message);
    } else {
      AppToast.error(outcome.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(colorThemeProvider);
    final layouts = SystemConfigService.keyboardLayouts;
    // One color pattern over the whole screen: the rows take positions
    // 0..n-1 and the Apply button the next one. In the colorful theme the
    // selection is blue and Apply is green; pattern themes color by position.
    final applyColor = theme.tileColor(TileColor.green, layouts.length);
    final fg = theme.textColor;

    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: createTopBar(context, 'Keyboard Locale'),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: layouts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final layout = layouts[index];
                        final selected = layout.code == _selected;
                        final rowColor =
                            theme.tileColor(TileColor.blue, index);
                        final background = selected
                            ? rowColor
                            : theme.isPattern
                                ? Color.alphaBlend(
                                    rowColor.withValues(alpha: 0.28),
                                    Colors.grey[850]!)
                                : Colors.grey[850]!;
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () =>
                              setState(() => _selected = layout.code),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 18),
                            decoration: BoxDecoration(
                              color: background,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    layout.name,
                                    style: TextStyle(
                                        color: selected ? fg : Colors.white,
                                        fontSize: 20),
                                  ),
                                ),
                                Text(
                                  layout.code,
                                  style: TextStyle(
                                      color: selected
                                          ? fg.withValues(alpha: 0.8)
                                          : Colors.grey[400],
                                      fontSize: 16),
                                ),
                                if (selected) ...[
                                  const SizedBox(width: 12),
                                  Icon(Icons.check_circle, color: fg),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SizedBox(
                      height: 64,
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: applyColor,
                          disabledBackgroundColor:
                              theme.tileColor(TileColor.grey, null),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _saving
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: fg),
                              )
                            : Icon(Icons.keyboard, color: fg),
                        label: Text(
                          _saving ? 'Applying…' : 'Apply',
                          style: TextStyle(fontSize: 20, color: fg),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
