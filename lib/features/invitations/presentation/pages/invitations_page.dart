import 'package:app/core/theme/app_colors.dart';
import 'package:app/features/invitations/data/models/circle_invitation.dart';
import 'package:app/features/invitations/data/repositories/invitation_repository.dart';
import 'package:flutter/material.dart';
import 'package:app/features/invitations/data/invitations_badge_notifier.dart';

class InvitationsPage extends StatefulWidget {
  const InvitationsPage({super.key});

  @override
  State<InvitationsPage> createState() => _InvitationsPageState();
}

class _InvitationsPageState extends State<InvitationsPage> {
  final _invitationRepository = InvitationRepository();
  List<CircleInvitation> _invitations = [];
  bool _isLoading = true;
  final Set<String> _processingIds =
      {}; // para deshabilitar botones mientras responde

  @override
  void initState() {
    super.initState();
    _loadInvitations();
  }

  Future<void> _loadInvitations() async {
    setState(() => _isLoading = true);
    try {
      final invitations = await _invitationRepository.getMyPendingInvitations();
      if (mounted) {
        setState(() {
          _invitations = invitations;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando invitaciones: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _respond(CircleInvitation invitation, bool accept) async {
    setState(() => _processingIds.add(invitation.id));

    try {
      if (accept) {
        await _invitationRepository.acceptInvitation(invitation.id);
      } else {
        await _invitationRepository.rejectInvitation(invitation.id);
      }

      if (mounted) {
        setState(() {
          _invitations.removeWhere((i) => i.id == invitation.id);
          _processingIds.remove(invitation.id);
        });

        invitationsBadgeNotifier.refresh();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept
                  ? 'Te uniste a ${invitation.circleName}'
                  : 'Invitación rechazada',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error respondiendo invitación: $e');
      if (mounted) setState(() => _processingIds.remove(invitation.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: Text(
          'Invitaciones',
          style: TextStyle(color: colors.textPrimary),
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colors.selected))
          : RefreshIndicator(
              onRefresh: _loadInvitations,
              color: colors.selected,
              child: _invitations.isEmpty
                  ? ListView(
                      // ListView (no Center) para que el pull-to-refresh
                      // funcione incluso sin invitaciones
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.7,
                          child: Center(
                            child: Text(
                              'No tienes invitaciones pendientes',
                              style: TextStyle(color: colors.textSecondary),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _invitations.length,
                      itemBuilder: (context, index) {
                        final invitation = _invitations[index];
                        final isProcessing = _processingIds.contains(
                          invitation.id,
                        );

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.indicator,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                invitation.circleName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Invitado por ${invitation.invitedByFullName}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (isProcessing)
                                Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colors.selected,
                                    ),
                                  ),
                                )
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            _respond(invitation, false),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(
                                            0xFFB06A55,
                                          ),
                                          side: const BorderSide(
                                            color: Color(0xFFD8B8A9),
                                          ),
                                          backgroundColor: const Color(
                                            0xFFFCF5F1,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: const Text('Rechazar'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () => _respond(invitation, true),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colors.selected,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Center(
                                            child: Text(
                                              'Aceptar',
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
