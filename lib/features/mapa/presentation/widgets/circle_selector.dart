import 'package:flutter/material.dart';
import 'package:app/core/theme/app_colors.dart';

// ---------------------------------------------------------------------------
// MODELO
// ---------------------------------------------------------------------------
class Circle {
  final String id;
  final String name;
  final int memberCount;
  final List<String> memberInitials;
  final String role;

  const Circle({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.memberInitials,
    required this.role,
  });

  bool get isOwner => role == 'owner';
}

// ---------------------------------------------------------------------------
// AVATARES APILADOS (usado por el chip y por cada fila de la lista)
// ---------------------------------------------------------------------------
class StackedAvatars extends StatelessWidget {
  final List<String> initials;
  final double size;

  const StackedAvatars({super.key, required this.initials, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final overlap = size * 0.7;
    return SizedBox(
      width: size + (initials.length - 1) * overlap,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < initials.length; i++)
            Positioned(
              left: i * overlap,
              child: CircleAvatar(
                radius: size / 2,
                backgroundColor: const Color(
                  0xFFE9C9A0,
                ),
                child: Text(
                  initials[i],
                  style: TextStyle(
                    fontSize: size * 0.36,
                    color: const Color(0xFF6B4A26),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CHIP DEL HEADER (lo que se ve en MapaPage, tocarlo abre el selector)
// ---------------------------------------------------------------------------
class CircleChip extends StatelessWidget {
  final Circle circle;
  final VoidCallback onTap;

  const CircleChip({super.key, required this.circle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(7, 7, 12, 7),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StackedAvatars(initials: circle.memberInitials, size: 24),
            const SizedBox(width: 8),
            Text(
              circle.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: colors.unselected,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ITEM DE LA LISTA DE CÍRCULOS (dentro del selector desplegado)
// ---------------------------------------------------------------------------
class CircleListItem extends StatelessWidget {
  final Circle circle;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const CircleListItem({
    super.key,
    required this.circle,
    required this.isActive,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive ? colors.indicator : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            StackedAvatars(initials: circle.memberInitials, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    circle.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                  ),
                  Text(
                    '${circle.memberCount} miembros',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isActive) Icon(Icons.check, size: 18, color: colors.selected),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CONTENIDO DEL SELECTOR DESPLEGADO (lista + crear + unirse con código)
// ---------------------------------------------------------------------------
class CircleSelectorSheet extends StatelessWidget {
  final List<Circle> circles;
  final String activeCircleId;
  final ValueChanged<String> onCircleSelected;
  final VoidCallback onCreateCircle;
  final VoidCallback onJoinWithCode;
  final void Function(Circle circle)? onLongPressCircle;

  const CircleSelectorSheet({
    super.key,
    required this.circles,
    required this.activeCircleId,
    required this.onCircleSelected,
    required this.onCreateCircle,
    required this.onJoinWithCode,
    this.onLongPressCircle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text(
              'TUS CÍRCULOS',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          ),
          for (final c in circles)
            CircleListItem(
              circle: c,
              isActive: c.id == activeCircleId,
              onTap: () => onCircleSelected(c.id),
              onLongPress: onLongPressCircle != null
                  ? () => onLongPressCircle!(c)
                  : null,
            ),
          Divider(height: 1, color: colors.border),
          ListTile(
            leading: Icon(Icons.add, color: colors.unselected),
            title: const Text('Crear círculo'),
            onTap: onCreateCircle,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FUNCIÓN QUE ABRE EL SELECTOR (llamar desde donde tengas el CircleChip)
// ---------------------------------------------------------------------------
void showCircleSelector(
  BuildContext context, {
  required List<Circle> circles,
  required String activeCircleId,
  required ValueChanged<String> onCircleSelected,
  required VoidCallback onCreateCircle,
  void Function(Circle circle)? onLongPressCircle,
}) {
  final colors = context.appColors;

  showGeneralDialog(
    context: context,
    barrierLabel: 'Circle selector',
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.25),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 76, left: 16, right: 16),
          child: Material(
            borderRadius: BorderRadius.circular(18),
            color: colors.surface,
            elevation: 8,
            child: CircleSelectorSheet(
              circles: circles,
              activeCircleId: activeCircleId,
              onCircleSelected: (id) {
                onCircleSelected(id);
                Navigator.of(context).pop();
              },
              onCreateCircle: () {
                Navigator.of(context).pop(); // cierra el selector
                onCreateCircle();
              },
              onJoinWithCode: () => Navigator.of(context).pop(),
              onLongPressCircle: onLongPressCircle != null
                  ? (circle) {
                      Navigator.of(context).pop(); // cierra el selector primero
                      onLongPressCircle(
                        circle,
                      ); // luego dispara la acción (mostrar diálogo)
                    }
                  : null,
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.05),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      );
    },
  );
}
