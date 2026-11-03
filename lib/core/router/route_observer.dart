import 'package:flutter/widgets.dart';

/// Lets a screen know when the page above it was closed (`RouteAware.didPopNext`).
/// Registered on the GoRouter in `app_router.dart`.
final RouteObserver<ModalRoute<void>> appRouteObserver = RouteObserver<ModalRoute<void>>();
