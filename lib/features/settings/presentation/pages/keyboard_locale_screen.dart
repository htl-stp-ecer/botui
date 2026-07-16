import 'package:flutter/material.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/settings/data/system_config_service.dart';

/// Lets the user pick the physical keyboard layout (XKB / libinput).
class KeyboardLocaleScreen extends StatefulWidget {
  const KeyboardLocaleScreen(
      {super.key, this.service = const SystemConfigService()});

  final SystemConfigService service;

  @override
  State<KeyboardLocaleScreen> createState() => _KeyboardLocaleScreenState();
}

class _KeyboardLocaleScreenState extends State<KeyboardLocaleScreen> {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(outcome.message, style: const TextStyle(fontSize: 16)),
        backgroundColor: outcome.ok ? Colors.green[700] : Colors.red[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      itemCount: SystemConfigService.keyboardLayouts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final layout =
                            SystemConfigService.keyboardLayouts[index];
                        final selected = layout.code == _selected;
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () =>
                              setState(() => _selected = layout.code),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 18),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.blue[700]
                                  : Colors.grey[850],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? Colors.blue.shade300
                                    : Colors.grey.shade700,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    layout.name,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 20),
                                  ),
                                ),
                                Text(
                                  layout.code,
                                  style: TextStyle(
                                      color: Colors.grey[400], fontSize: 16),
                                ),
                                if (selected) ...[
                                  const SizedBox(width: 12),
                                  const Icon(Icons.check_circle,
                                      color: Colors.white),
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
                          backgroundColor: Colors.blue[700],
                          disabledBackgroundColor: Colors.grey[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _saving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.keyboard, color: Colors.white),
                        label: Text(
                          _saving ? 'Applying…' : 'Apply',
                          style: const TextStyle(
                              fontSize: 20, color: Colors.white),
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
