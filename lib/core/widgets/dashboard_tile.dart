import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

/// Dashboard tile that navigates using go_router route paths.
/// Use [route] to specify the path and [extra] for additional data.
class DashboardTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final String route;
  final Object? extra;
  final Color color;
  final bool isMain;

  const DashboardTile({
    super.key,
    required this.label,
    required this.icon,
    required this.route,
    this.extra,
    required this.color,
    this.isMain = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: () => context.push(route, extra: extra),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                offset: Offset(0, 4),
                blurRadius: 6,
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: isMain ? 60 : 50,
                  color: Colors.white,
                ),
                SizedBox(height: isMain ? 12 : 8),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMain ? 26 : 22,
                    fontWeight: isMain ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
