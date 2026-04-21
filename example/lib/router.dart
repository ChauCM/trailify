import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/playground_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/settings_screen.dart';

part 'router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Screen,Route')
class AppRouter extends RootStackRouter {
  @override
  RouteType get defaultRouteType => const RouteType.material();

  @override
  List<AutoRoute> get routes => [
        AutoRoute(path: '/', page: HomeRoute.page, initial: true),
        AutoRoute(path: '/playground', page: PlaygroundRoute.page),
        AutoRoute(path: '/settings', page: SettingsRoute.page),
        AutoRoute(path: '/product/:id', page: ProductDetailRoute.page),
      ];
}
