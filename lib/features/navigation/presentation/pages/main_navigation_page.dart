import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app/core/theme/app_colors.dart';

class MainNavigationPage extends StatelessWidget {
  final Widget child;
  final int pendingInvites;

  const MainNavigationPage({
    super.key,
    required this.child,
    this.pendingInvites = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final String location = GoRouterState.of(context).uri.path;

    int selectedIndex = 0;

    if (location.startsWith('/location')) {
      selectedIndex = 1;
    } else if (location.startsWith('/family')) {
      selectedIndex = 2;
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.border, width: 0.5)),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          indicatorColor: colors.indicator,
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) {
            switch (index) {
              case 0:
                context.go('/home');
                break;
              case 1:
                context.go('/location');
                break;
              case 2:
                context.go('/family');
                break;
            }
          },
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.map_outlined, color: colors.unselected),
              selectedIcon: Icon(Icons.map, color: colors.selected),
              label: 'Mapa',
            ),
            NavigationDestination(
              icon: Badge(
                backgroundColor: colors.badge,
                isLabelVisible: pendingInvites > 0,
                label: Text('$pendingInvites'),
                child: Icon(Icons.mail_outline, color: colors.unselected),
              ),
              selectedIcon: Badge(
                backgroundColor: colors.badge,
                isLabelVisible: pendingInvites > 0,
                label: Text('$pendingInvites'),
                child: Icon(Icons.mail, color: colors.selected),
              ),
              label: 'Invitaciones',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline, color: colors.unselected),
              selectedIcon: Icon(Icons.person, color: colors.selected),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}
