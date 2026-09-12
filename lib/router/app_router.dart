import 'dart:async';

import 'package:app/features/auth/presentation/pages/location_page.dart';
import 'package:app/features/auth/presentation/pages/login.dart';
import 'package:app/features/auth/presentation/pages/perfil_page.dart';
import 'package:app/features/mapa/presentation/pages/mapa_page.dart';
import 'package:app/features/navigation/presentation/pages/main_navigation_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AuthRefreshNotifier extends ChangeNotifier {
  AuthRefreshNotifier() {
    _subscription = FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<User?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final AuthRefreshNotifier authRefreshNotifier = AuthRefreshNotifier();

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',

  refreshListenable: authRefreshNotifier,

  redirect: (context, state) {
    final bool isLoggedIn = FirebaseAuth.instance.currentUser != null;

    final bool isLoginPage = state.matchedLocation == '/login';

    // No autenticado → Login
    if (!isLoggedIn && !isLoginPage) {
      return '/login';
    }

    // Autenticado → Home
    if (isLoggedIn && isLoginPage) {
      return '/home';
    }

    return null;
  },

  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) {
        return const LoginPage();
      },
    ),

    ShellRoute(
      builder: (context, state, child) {
        return MainNavigationPage(child: child);
      },
      routes: [
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (context, state) {
            return const MapaPage();
          },
        ),

        GoRoute(
          path: '/location',
          name: 'location',
          builder: (context, state) {
            return const LocationPage();
          },
        ),

        GoRoute(
          path: '/family',
          name: 'family',
          builder: (context, state) {
            return const PerfilPage();
          },
        ),
      ],
    ),
  ],
);
