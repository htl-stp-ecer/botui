import 'package:flutter_test/flutter_test.dart';
import 'package:stpvelox/core/router/app_router.dart';

void main() {
  group('AppRoutes', () {
    // Mirrors the constants declared on AppRoutes. We can't reflect over
    // an `abstract class` of statics in Dart without dart:mirrors, so
    // this list is maintained by hand — if a route is added to
    // AppRoutes without being added here the test still passes; it only
    // catches collisions and bad formats.
    const all = [
      AppRoutes.dashboard,
      AppRoutes.sensors,
      AppRoutes.sensorCategory,
      AppRoutes.imuSelection,
      AppRoutes.sensorScreen,
      AppRoutes.systemHealthGraph,
      AppRoutes.diskUsage,
      AppRoutes.programs,
      AppRoutes.programAction,
      AppRoutes.programRun,
      AppRoutes.settings,
      AppRoutes.touchCalibration,
      AppRoutes.screenRotation,
      AppRoutes.serviceStatus,
      AppRoutes.serviceTile,
      AppRoutes.serviceLog,
      AppRoutes.personality,
      AppRoutes.displaySettings,
      AppRoutes.systemSettings,
      AppRoutes.appStatus,
      AppRoutes.wifi,
      AppRoutes.wifiManage,
      AppRoutes.wifiScan,
      AppRoutes.wifiDetail,
      AppRoutes.wifiManualConnect,
      AppRoutes.wifiEnterprise,
      AppRoutes.wifiSavedNetworks,
      AppRoutes.wifiAccessPointConfig,
      AppRoutes.wifiAccessPointStatus,
      AppRoutes.wifiChannelScan,
      AppRoutes.wifiLanStatus,
      AppRoutes.wifiDeviceInfo,
      AppRoutes.camera,
      AppRoutes.robotFace,
      AppRoutes.devMenu,
      AppRoutes.flappyWombat,
      AppRoutes.tiltMaze,
    ];

    test('all routes are absolute paths starting with /', () {
      for (final route in all) {
        expect(route, startsWith('/'),
            reason: 'route "$route" must be an absolute path');
      }
    });

    test('all routes are unique', () {
      expect(all.toSet().length, all.length,
          reason: 'duplicate route definitions found');
    });

    test('dashboard route is "/"', () {
      expect(AppRoutes.dashboard, '/');
    });
  });

  group('isDashboardRoute', () {
    test('returns true for "/"', () {
      expect(isDashboardRoute('/'), isTrue);
      expect(isDashboardRoute(AppRoutes.dashboard), isTrue);
    });

    test('returns false for non-dashboard routes', () {
      expect(isDashboardRoute(AppRoutes.sensors), isFalse);
      expect(isDashboardRoute(AppRoutes.settings), isFalse);
      expect(isDashboardRoute('/anything-else'), isFalse);
    });
  });

  test('rootNavigatorKey is a stable global instance', () {
    // Holding a long-lived navigator key is what lets out-of-tree
    // services (error_message_service, watchdog overlays) show dialogs.
    // The key is created at top-level — assert it stays referentially
    // equal across reads.
    expect(rootNavigatorKey, same(rootNavigatorKey));
    expect(rootNavigatorKey.toString(), contains('rootNavigator'));
  });
}
