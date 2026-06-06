import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

// Dashboard
import 'package:stpvelox/features/dashboard/presentation/screens/dashboard_screen.dart';

// Programs
import 'package:stpvelox/features/program/presentation/screens/program_selection_screen.dart';
import 'package:stpvelox/features/program/presentation/screens/program_action_screen.dart';
import 'package:stpvelox/features/program/presentation/screens/program_screen.dart';
import 'package:stpvelox/features/program/domain/entities/program.dart';

// Sensors
import 'package:stpvelox/features/sensors/presentation/screens/sensor_selection_screen.dart';
import 'package:stpvelox/features/sensors/presentation/screens/sensor_category_screen.dart';
import 'package:stpvelox/features/sensors/presentation/screens/imu_selection_screen.dart';
import 'package:stpvelox/features/sensors/domain/entities/sensor_category.dart';
import 'package:stpvelox/features/sensors/domain/entities/sensor.dart';
import 'package:stpvelox/features/sensors/presentation/screens/disk_usage_screen.dart';
import 'package:stpvelox/features/calib_board/presentation/screens/calib_board_screen.dart';
import 'package:stpvelox/features/calib_board/presentation/screens/calib_icm_screen.dart';
import 'package:stpvelox/features/calib_board/presentation/screens/calib_icm_accel_screen.dart';
import 'package:stpvelox/features/calib_board/presentation/screens/calib_icm_gyro_screen.dart';
import 'package:stpvelox/features/calib_board/presentation/screens/calib_icm_temp_screen.dart';
import 'package:stpvelox/features/calib_board/presentation/screens/calib_icm_orientation_screen.dart';
import 'package:stpvelox/features/calib_board/presentation/screens/calib_icm_calibration_screen.dart';
import 'package:stpvelox/features/calib_board/presentation/screens/calib_odometry_screen.dart';
import 'package:stpvelox/features/calib_board/presentation/screens/calib_paa_screen.dart';
import 'package:stpvelox/features/calib_board/presentation/screens/calib_paa_delta_screen.dart';
import 'package:stpvelox/features/calib_board/presentation/screens/calib_paa_squal_screen.dart';
import 'package:stpvelox/features/calib_board/presentation/screens/calib_paa_shutter_screen.dart';
import 'package:stpvelox/features/calib_board/presentation/screens/calib_paa_track_screen.dart';
import 'package:stpvelox/features/calib_board/presentation/screens/calib_paa_calibration_screen.dart';
import 'package:stpvelox/features/calib_board/presentation/screens/calib_bno_screen.dart';
import 'package:stpvelox/features/sensors/presentation/screens/system_health_graph_screen.dart';

// Settings
import 'package:stpvelox/features/settings/presentation/pages/settings_screen.dart';
import 'package:stpvelox/features/settings/presentation/pages/touch_calibration_screen.dart';
import 'package:stpvelox/features/settings/presentation/pages/screen_rotation_screen.dart';
import 'package:stpvelox/features/settings/presentation/pages/service_status_screen.dart';
import 'package:stpvelox/features/settings/presentation/pages/service_tile_page.dart';
import 'package:stpvelox/features/settings/presentation/pages/service_log_screen.dart';
import 'package:stpvelox/features/settings/presentation/pages/robot_personality_screen.dart';
import 'package:stpvelox/features/settings/presentation/pages/display_settings_screen.dart';
import 'package:stpvelox/features/settings/presentation/pages/system_settings_screen.dart';
import 'package:stpvelox/features/settings/presentation/pages/app_status_screen.dart';

// WiFi
import 'package:stpvelox/features/wifi/presentation/pages/wifi_home_screen.dart';
import 'package:stpvelox/features/wifi/presentation/pages/wifi_menu_screen.dart';
import 'package:stpvelox/features/wifi/presentation/pages/wifi_scan_list_screen.dart';
import 'package:stpvelox/features/wifi/presentation/pages/wifi_detail_screen.dart';
import 'package:stpvelox/features/wifi/presentation/pages/wifi_manual_connect_screen.dart';
import 'package:stpvelox/features/wifi/presentation/pages/wifi_enterprise_credential_screen.dart';
import 'package:stpvelox/features/wifi/presentation/pages/device_info_screen.dart';
import 'package:stpvelox/features/wifi/presentation/pages/access_point_status_screen.dart';
import 'package:stpvelox/features/wifi/presentation/pages/lan_only_status_screen.dart';
import 'package:stpvelox/features/wifi/presentation/pages/wifi_channel_scan_screen.dart';
import 'package:stpvelox/features/wifi/domain/presentation/screens/saved_networks_screen.dart';
import 'package:stpvelox/features/wifi/domain/presentation/screens/access_point_config_screen.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_network.dart';

// Dynamic UI

// Camera
import 'package:stpvelox/features/camera/presentation/pages/camera_viewer_screen.dart'
    show CameraViewerScreen;

// Other
import 'package:stpvelox/presentation/screens/robot_face_screen.dart';
import 'package:stpvelox/features/flappy_wombat/presentation/screen/flappy_wombat_game.dart';
import 'package:stpvelox/features/dev_menu/presentation/screens/dev_menu_screen.dart';
import 'package:stpvelox/features/tilt_maze/presentation/screens/tilt_maze_screen.dart';

part 'app_router.g.dart';

/// Route paths as constants
abstract class AppRoutes {
  // Dashboard
  static const dashboard = '/';

  // Sensors
  static const sensors = '/sensors';
  static const sensorCategory = '/sensors/category';
  static const imuSelection = '/sensors/imu';
  static const sensorScreen = '/sensors/screen';
  static const systemHealthGraph = '/sensors/system/graph';
  static const diskUsage = '/sensors/system/disk';

  // Calibration board (external USB-C connected board with PAA/BNO/ICM)
  static const calibBoard = '/sensors/calib_board';

  // ICM submenu
  static const calibIcm             = '/sensors/calib_board/icm';
  static const calibIcmAccel        = '/sensors/calib_board/icm/accel';
  static const calibIcmGyro         = '/sensors/calib_board/icm/gyro';
  static const calibIcmTemp         = '/sensors/calib_board/icm/temp';
  static const calibIcmOrientation  = '/sensors/calib_board/icm/orientation';
  static const calibIcmCalibration  = '/sensors/calib_board/icm/calibration';

  // Odometry (fusion of PAA + IMU)
  static const calibOdometry = '/sensors/calib_board/odometry';

  // PAA submenu
  static const calibPaa             = '/sensors/calib_board/paa';
  static const calibPaaDelta        = '/sensors/calib_board/paa/delta';
  static const calibPaaSqual        = '/sensors/calib_board/paa/squal';
  static const calibPaaShutter      = '/sensors/calib_board/paa/shutter';
  static const calibPaaTrack        = '/sensors/calib_board/paa/track';
  static const calibPaaCalibration  = '/sensors/calib_board/paa/calibration';

  // BNO
  static const calibBno = '/sensors/calib_board/bno';

  // Programs
  static const programs = '/programs';
  static const programAction = '/programs/action';
  static const programRun = '/programs/run';

  // Settings
  static const settings = '/settings';
  static const touchCalibration = '/settings/touch-calibration';
  static const screenRotation = '/settings/screen-rotation';
  static const serviceStatus = '/settings/services';
  static const serviceTile = '/settings/services/tile';
  static const serviceLog = '/settings/services/log';
  static const personality = '/settings/personality';
  static const displaySettings = '/settings/display';
  static const systemSettings = '/settings/system';
  static const appStatus = '/settings/app-status';

  // WiFi
  static const wifi = '/wifi';
  static const wifiManage = '/wifi/manage';
  static const wifiScan = '/wifi/scan';
  static const wifiDetail = '/wifi/detail';
  static const wifiManualConnect = '/wifi/manual-connect';
  static const wifiEnterprise = '/wifi/enterprise';
  static const wifiSavedNetworks = '/wifi/saved';
  static const wifiAccessPointConfig = '/wifi/ap-config';
  static const wifiAccessPointStatus = '/wifi/ap-status';
  static const wifiChannelScan = '/wifi/channel-scan';
  static const wifiLanStatus = '/wifi/lan-status';
  static const wifiDeviceInfo = '/wifi/device-info';

  // Camera
  static const camera = '/camera';

  // Screensaver
  static const robotFace = '/robot-face';

  // Dev menu & easter eggs
  static const devMenu = '/dev-menu';
  static const flappyWombat = '/flappy-wombat';
  static const tiltMaze = '/tilt-maze';
}

/// Check if the current route is the dashboard
bool isDashboardRoute(String location) {
  return location == AppRoutes.dashboard || location == '/';
}

// Global navigator key so services that fire from outside the widget tree
// (LCM-driven error dialogs, watchdog overlays, …) have a long-lived
// BuildContext they can reach without holding the original
// `BuildContext` they were started with. Holding the latter blew up with
// "Null check operator used on a null value" the moment the registering
// widget rebuilt — Navigator.of(context) then returned null because the
// context no longer had a Navigator ancestor. The GlobalKey is owned by
// GoRouter for the full lifetime of the app so .currentContext stays
// valid.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'rootNavigator');

@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    debugLogDiagnostics: true,
    navigatorKey: rootNavigatorKey,
    routes: [
      // Dashboard
      GoRoute(
        path: AppRoutes.dashboard,
        name: 'dashboard',
        builder: (context, state) => DashboardScreen(),
      ),

      // Sensors
      GoRoute(
        path: AppRoutes.sensors,
        name: 'sensors',
        builder: (context, state) => const SensorSelectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.imuSelection,
        name: 'imuSelection',
        builder: (context, state) {
          final imuGroups = state.extra as Map<SensorCategory, List<Sensor>>;
          return ImuSelectionScreen(imuGroups: imuGroups);
        },
      ),
      GoRoute(
        path: AppRoutes.sensorCategory,
        name: 'sensorCategory',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return SensorCategoryScreen(
            category: extra['category'] as SensorCategory,
            sensor: extra['sensors'] as List<Sensor>,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.sensorScreen,
        name: 'sensorScreen',
        builder: (context, state) {
          final screen = state.extra as Widget;
          return screen;
        },
      ),
      GoRoute(
        path: AppRoutes.systemHealthGraph,
        name: 'systemHealthGraph',
        builder: (context, state) {
          final metric = state.extra as SystemHealthMetric;
          return SystemHealthGraphScreen(metric: metric);
        },
      ),
      GoRoute(
        path: AppRoutes.diskUsage,
        name: 'diskUsage',
        builder: (context, state) => const DiskUsageScreen(),
      ),

      // Calibration board
      GoRoute(
        path: AppRoutes.calibBoard,
        name: 'calibBoard',
        builder: (context, state) => const CalibBoardScreen(),
      ),

      // ICM submenu + leaves
      GoRoute(
        path: AppRoutes.calibIcm,
        name: 'calibIcm',
        builder: (context, state) => const CalibIcmScreen(),
      ),
      GoRoute(
        path: AppRoutes.calibIcmAccel,
        name: 'calibIcmAccel',
        builder: (context, state) => const CalibIcmAccelScreen(),
      ),
      GoRoute(
        path: AppRoutes.calibIcmGyro,
        name: 'calibIcmGyro',
        builder: (context, state) => const CalibIcmGyroScreen(),
      ),
      GoRoute(
        path: AppRoutes.calibIcmTemp,
        name: 'calibIcmTemp',
        builder: (context, state) => const CalibIcmTempScreen(),
      ),
      GoRoute(
        path: AppRoutes.calibIcmOrientation,
        name: 'calibIcmOrientation',
        builder: (context, state) => const CalibIcmOrientationScreen(),
      ),
      GoRoute(
        path: AppRoutes.calibIcmCalibration,
        name: 'calibIcmCalibration',
        builder: (context, state) => const CalibIcmCalibrationScreen(),
      ),
      GoRoute(
        path: AppRoutes.calibOdometry,
        name: 'calibOdometry',
        builder: (context, state) => const CalibOdometryScreen(),
      ),

      // PAA submenu + leaves
      GoRoute(
        path: AppRoutes.calibPaa,
        name: 'calibPaa',
        builder: (context, state) => const CalibPaaScreen(),
      ),
      GoRoute(
        path: AppRoutes.calibPaaDelta,
        name: 'calibPaaDelta',
        builder: (context, state) => const CalibPaaDeltaScreen(),
      ),
      GoRoute(
        path: AppRoutes.calibPaaSqual,
        name: 'calibPaaSqual',
        builder: (context, state) => const CalibPaaSqualScreen(),
      ),
      GoRoute(
        path: AppRoutes.calibPaaShutter,
        name: 'calibPaaShutter',
        builder: (context, state) => const CalibPaaShutterScreen(),
      ),
      GoRoute(
        path: AppRoutes.calibPaaTrack,
        name: 'calibPaaTrack',
        builder: (context, state) => const CalibPaaTrackScreen(),
      ),
      GoRoute(
        path: AppRoutes.calibPaaCalibration,
        name: 'calibPaaCalibration',
        builder: (context, state) => const CalibPaaCalibrationScreen(),
      ),

      // BNO
      GoRoute(
        path: AppRoutes.calibBno,
        name: 'calibBno',
        builder: (context, state) => const CalibBnoScreen(),
      ),

      // Programs
      GoRoute(
        path: AppRoutes.programs,
        name: 'programs',
        builder: (context, state) => ProgramSelectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.programAction,
        name: 'programAction',
        builder: (context, state) {
          final program = state.extra as Program;
          return ProgramActionScreen(program: program);
        },
      ),
      GoRoute(
        path: AppRoutes.programRun,
        name: 'programRun',
        builder: (context, state) {
          final program = state.extra as Program;
          return ProgramScreen(program: program);
        },
      ),

      // Settings
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.touchCalibration,
        name: 'touchCalibration',
        builder: (context, state) => const TouchCalibrationScreen(),
      ),
      GoRoute(
        path: AppRoutes.screenRotation,
        name: 'screenRotation',
        builder: (context, state) => const ScreenRotationScreen(),
      ),
      GoRoute(
        path: AppRoutes.serviceStatus,
        name: 'serviceStatus',
        builder: (context, state) => const ServiceStatusScreen(),
      ),
      GoRoute(
        path: AppRoutes.serviceTile,
        name: 'serviceTile',
        builder: (context, state) {
          final service = state.extra as Map<String, String>;
          return ServiceTilePage(service: service);
        },
      ),
      GoRoute(
        path: AppRoutes.serviceLog,
        name: 'serviceLog',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return ServiceLogScreen(
            serviceName: extra['serviceName'] as String,
            displayName: extra['displayName'] as String,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.personality,
        name: 'personality',
        builder: (context, state) => const RobotPersonalityScreen(),
      ),
      GoRoute(
        path: AppRoutes.displaySettings,
        name: 'displaySettings',
        builder: (context, state) => const DisplaySettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.systemSettings,
        name: 'systemSettings',
        builder: (context, state) => const SystemSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.appStatus,
        name: 'appStatus',
        builder: (context, state) => const AppStatusScreen(),
      ),

      // WiFi
      GoRoute(
        path: AppRoutes.wifi,
        name: 'wifi',
        builder: (context, state) => const WifiMenuScreen(),
      ),
      GoRoute(
        path: AppRoutes.wifiManage,
        name: 'wifiManage',
        builder: (context, state) => const WifiHomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.wifiScan,
        name: 'wifiScan',
        builder: (context, state) => const WifiScanListScreen(),
      ),
      GoRoute(
        path: AppRoutes.wifiDetail,
        name: 'wifiDetail',
        builder: (context, state) {
          final network = state.extra as WifiNetwork;
          return WifiDetailScreen(network: network);
        },
      ),
      GoRoute(
        path: AppRoutes.wifiManualConnect,
        name: 'wifiManualConnect',
        builder: (context, state) => const WifiManualConnectScreen(),
      ),
      GoRoute(
        path: AppRoutes.wifiEnterprise,
        name: 'wifiEnterprise',
        builder: (context, state) {
          final ssid = state.extra as String;
          return WifiEnterpriseCredentialScreen(ssid: ssid);
        },
      ),
      GoRoute(
        path: AppRoutes.wifiSavedNetworks,
        name: 'wifiSavedNetworks',
        builder: (context, state) => const SavedNetworksScreen(),
      ),
      GoRoute(
        path: AppRoutes.wifiAccessPointConfig,
        name: 'wifiAccessPointConfig',
        builder: (context, state) => const AccessPointConfigScreen(),
      ),
      GoRoute(
        path: AppRoutes.wifiAccessPointStatus,
        name: 'wifiAccessPointStatus',
        builder: (context, state) => const AccessPointStatusScreen(),
      ),
      GoRoute(
        path: AppRoutes.wifiChannelScan,
        name: 'wifiChannelScan',
        builder: (context, state) => const WifiChannelScanScreen(),
      ),
      GoRoute(
        path: AppRoutes.wifiLanStatus,
        name: 'wifiLanStatus',
        builder: (context, state) => const LanOnlyStatusScreen(),
      ),
      GoRoute(
        path: AppRoutes.wifiDeviceInfo,
        name: 'wifiDeviceInfo',
        builder: (context, state) => const DeviceInfoScreen(),
      ),

      // Camera
      GoRoute(
        path: AppRoutes.camera,
        name: 'camera',
        builder: (context, state) => const CameraViewerScreen(),
      ),

      // Screensaver
      GoRoute(
        path: AppRoutes.robotFace,
        name: 'robotFace',
        builder: (context, state) => const RobotFaceScreen(),
      ),

      // Dev menu & easter eggs
      GoRoute(
        path: AppRoutes.devMenu,
        name: 'devMenu',
        builder: (context, state) => const DevMenuScreen(),
      ),
      GoRoute(
        path: AppRoutes.flappyWombat,
        name: 'flappyWombat',
        builder: (context, state) => const FlappyWombatGame(),
      ),
      GoRoute(
        path: AppRoutes.tiltMaze,
        name: 'tiltMaze',
        builder: (context, state) => const TiltMazeScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Route not found: ${state.uri}'),
      ),
    ),
  );
}
