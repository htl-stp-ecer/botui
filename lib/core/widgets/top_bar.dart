import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stpvelox/core/widgets/battery_status.dart';

AppBar createTopBar(BuildContext context, String title,
    {List<Widget>? actions,
    Widget? trailing,
    Widget? center,
    VoidCallback? onBack}) {
  actions ??= [];
  actions.add(const BatteryStatus());
  final handleBack = onBack ?? () => context.pop();
  return AppBar(
    backgroundColor: Colors.grey[900],
    automaticallyImplyLeading: false,
    // Optional widget centered on the whole screen width, behind the title
    // and the battery icon (empty parts of those let taps through).
    flexibleSpace:
        center == null ? null : SafeArea(child: Center(child: center)),
    actions: actions,
    title: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: handleBack,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: handleBack,
                iconSize: 40,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    ),
    toolbarHeight: 80,
  );
}
