import 'package:app/core/theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// MODELO (mapea a tu tabla circle_invitations)
// ---------------------------------------------------------------------------

enum InvitationStatus { pending, accepted, rejected, cancelled, expired }

class CircleInvitation {
  final String id;
  final String circleName;
  final List<String> circleMemberInitials;
  final String
  otherPersonName; // quien invitó (recibidas) o a quien invitaste (enviadas)
  final InvitationStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;

  const CircleInvitation({
    required this.id,
    required this.circleName,
    required this.circleMemberInitials,
    required this.otherPersonName,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired =>
      status == InvitationStatus.expired || DateTime.now().isAfter(expiresAt);
}

// Datos de ejemplo. Después esto viene de tu InvitationRepository.
final receivedInvitations = <CircleInvitation>[
  CircleInvitation(
    id: '1',
    circleName: 'Amigos del asado',
    circleMemberInitials: const ['LU', 'TI'],
    otherPersonName: 'Lucas',
    status: InvitationStatus.pending,
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    expiresAt: DateTime.now().add(const Duration(days: 5)),
  ),
  CircleInvitation(
    id: '2',
    circleName: 'Primos Rodriguez',
    circleMemberInitials: const ['TI'],
    otherPersonName: 'Tía Nora',
    status: InvitationStatus.pending,
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
    expiresAt: DateTime.now().add(const Duration(days: 2)),
  ),
  CircleInvitation(
    id: '3',
    circleName: 'Compañeros de oficina',
    circleMemberInitials: const ['MJ'],
    otherPersonName: 'María',
    status: InvitationStatus.expired,
    createdAt: DateTime.now().subtract(const Duration(days: 8)),
    expiresAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
];

final sentInvitations = <CircleInvitation>[
  CircleInvitation(
    id: '4',
    circleName: 'Familia Gomez',
    circleMemberInitials: const ['MA', 'PA', 'SO'],
    otherPersonName: 'Andrés',
    status: InvitationStatus.pending,
    createdAt: DateTime.now().subtract(const Duration(hours: 6)),
    expiresAt: DateTime.now().add(const Duration(days: 6)),
  ),
];

// ---------------------------------------------------------------------------
// PANTALLA
// ---------------------------------------------------------------------------

class InvitationsPage extends StatefulWidget {
  const InvitationsPage({super.key});

  @override
  State<InvitationsPage> createState() => _InvitationsPageState();
}

class _InvitationsPageState extends State<InvitationsPage> {
  bool showingReceived = true;

  @override
  void initState() {
    super.initState();

    _obtenerToken();
  }

  Future<void> _obtenerToken() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final token = await user.getIdToken();

      await Clipboard.setData(
        ClipboardData(text: token!),
      );

      print('Token copiado al portapapeles');
    }
  }

  void _accept(CircleInvitation invitation) {
    // TODO: llamar a tu InvitationRepository.accept(invitation.id)
  }

  void _reject(CircleInvitation invitation) {
    // TODO: llamar a tu InvitationRepository.reject(invitation.id)
  }

  void _cancel(CircleInvitation invitation) {
    // TODO: llamar a tu InvitationRepository.cancel(invitation.id)
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final list = showingReceived ? receivedInvitations : sentInvitations;
    final pending = list.where((i) => !i.isExpired).toList();
    final expired = list.where((i) => i.isExpired).toList();

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invitaciones',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _SegmentedToggle(
                showingReceived: showingReceived,
                onChanged: (value) => setState(() => showingReceived = value),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    if (pending.isNotEmpty) ...[
                      _SectionLabel('Pendientes'),
                      for (final invitation in pending)
                        _InvitationCard(
                          invitation: invitation,
                          isReceived: showingReceived,
                          onAccept: () => _accept(invitation),
                          onReject: () => _reject(invitation),
                          onCancel: () => _cancel(invitation),
                        ),
                    ],
                    if (expired.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _SectionLabel('Vencidas'),
                      for (final invitation in expired)
                        _InvitationCard(
                          invitation: invitation,
                          isReceived: showingReceived,
                        ),
                    ],
                    if (list.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text(
                            showingReceived
                                ? 'No tenés invitaciones pendientes'
                                : 'No enviaste invitaciones',
                            style: TextStyle(color: colors.textSecondary),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SEGMENTED CONTROL (Recibidas / Enviadas)
// ---------------------------------------------------------------------------

class _SegmentedToggle extends StatelessWidget {
  final bool showingReceived;
  final ValueChanged<bool> onChanged;

  const _SegmentedToggle({
    required this.showingReceived,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.indicator.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegmentButton(
              label: 'Recibidas',
              isActive: showingReceived,
              onTap: () => onChanged(true),
            ),
          ),
          Expanded(
            child: _SegmentButton(
              label: 'Enviadas',
              isActive: !showingReceived,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? colors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isActive ? colors.textPrimary : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LABEL DE SECCIÓN
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colors.textSecondary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TARJETA DE INVITACIÓN
// ---------------------------------------------------------------------------

class _InvitationCard extends StatelessWidget {
  final CircleInvitation invitation;
  final bool isReceived;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onCancel;

  const _InvitationCard({
    required this.invitation,
    required this.isReceived,
    this.onAccept,
    this.onReject,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isExpired = invitation.isExpired;

    final card = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.indicator.withOpacity(isExpired ? 0.25 : 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isExpired
                    ? Colors.grey.shade300
                    : const Color(0xFFA8C9D8),
                child: Text(
                  invitation.circleMemberInitials.first,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isExpired
                        ? Colors.grey.shade700
                        : const Color(0xFF2C5A6B),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invitation.circleName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(),
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isExpired) ...[
            const SizedBox(height: 12),
            if (isReceived)
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'Aceptar',
                      filled: true,
                      onTap: onAccept,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      label: 'Rechazar',
                      filled: false,
                      onTap: onReject,
                    ),
                  ),
                ],
              )
            else
              _ActionButton(
                label: 'Cancelar invitación',
                filled: false,
                onTap: onCancel,
              ),
          ],
        ],
      ),
    );

    return isExpired ? Opacity(opacity: 0.55, child: card) : card;
  }

  String _subtitle() {
    if (invitation.isExpired) {
      return 'Invitó ${invitation.otherPersonName} · venció hace ${_daysAgo(invitation.expiresAt)}';
    }
    return isReceived
        ? 'Invitó ${invitation.otherPersonName} · hace ${_daysAgo(invitation.createdAt)}'
        : 'Invitaste a ${invitation.otherPersonName} · hace ${_daysAgo(invitation.createdAt)}';
  }

  String _daysAgo(DateTime date) {
    final days = DateTime.now().difference(date).inDays;
    if (days <= 0) return 'hoy';
    if (days == 1) return '1 día';
    return '$days días';
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  const _ActionButton({required this.label, required this.filled, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: filled ? colors.selected : colors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: filled ? colors.surface : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}
