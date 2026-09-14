import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app/features/invitations/data/repositories/invitation_repository.dart';

class InvitationsBadgeNotifier extends ChangeNotifier {
  final _invitationRepository = InvitationRepository();

  int _count = 0;
  int get count => _count;

  Timer? _pollTimer;
  StreamSubscription<User?>? _authSubscription;

  InvitationsBadgeNotifier() {
    debugPrint('InvitationsBadgeNotifier creado');
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      debugPrint('Auth state changed: ${user?.uid}');
      if (user != null) {
        refresh();
        _startPolling();
      } else {
        _stopPolling();
        _count = 0;
        notifyListeners();
      }
    });
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> refresh() async {
    if (FirebaseAuth.instance.currentUser == null) return;

    try {
      final invitations = await _invitationRepository.getMyPendingInvitations();
      debugPrint(
        'Invitaciones pendientes encontradas: ${invitations.length}',
      );
      _count = invitations.length;
      notifyListeners();
    } catch (e) {
      debugPrint('Error refrescando badge de invitaciones: $e');
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }
}

final InvitationsBadgeNotifier invitationsBadgeNotifier =
    InvitationsBadgeNotifier();
