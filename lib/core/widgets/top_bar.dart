import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stpvelox/core/widgets/battery_status.dart';

AppBar createTopBar(BuildContext context, String title,
    {List<Widget>? actions, Widget? trailing, VoidCallback? onBack}) {
  actions ??= [];
  actions.add(const BatteryStatus());
  final handleBack = onBack ?? () => context.pop();
  return AppBar(
    backgroundColor: Colors.grey[900],
    automaticallyImplyLeading: false,
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
