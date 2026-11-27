import 'package:go_router/go_router.dart';

import 'presentation/login_screen.dart';
import 'presentation/sign_up_id_screen.dart';
import 'presentation/sign_up_screen.dart';
import 'presentation/splash_screen.dart';
import 'presentation/welcome_screen.dart';

/// Routes of the auth feature (owner: Mohan).
/// Aggregated by the app router, do not add paths anywhere else.
final List<RouteBase> authRoutes = [
  GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
  GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
  GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
  GoRoute(path: '/sign-up', builder: (_, __) => const SignUpScreen()),
  GoRoute(path: '/sign-up/id', builder: (_, __) => const SignUpIdScreen()),
];
