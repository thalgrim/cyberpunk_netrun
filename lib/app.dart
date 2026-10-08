import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'ui/screens/gm_architectures_screen.dart';
import 'ui/screens/gm_tracking_screen.dart';
import 'ui/screens/player_console_screen.dart';
import 'ui/screens/player_netrun_screen.dart';

class NetrunApp extends StatelessWidget {
  const NetrunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cyberpunk - Netrun',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      // Respecte « réduire les animations » du système.
      themeAnimationDuration: WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations
          ? Duration.zero
          : kThemeAnimationDuration,
      home: const HomeShell(),
    );
  }
}

/// Coquille : barre de navigation, garde du mode verrouillé.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  static const _labels = {
    AppTab.architectures: 'Architectures',
    AppTab.suivi: 'Suivi',
    AppTab.netrun: 'Netrun',
    AppTab.console: 'Console',
  };

  static const _icons = {
    AppTab.architectures: (Icons.account_tree_outlined, Icons.account_tree),
    AppTab.suivi: (Icons.monitor_heart_outlined, Icons.monitor_heart),
    AppTab.netrun: (Icons.lan_outlined, Icons.lan),
    AppTab.console: (Icons.memory_outlined, Icons.memory),
  };

  String _label(AppState app, AppTab t) => app.locked && t == AppTab.console ? 'Cyberconsole' : _labels[t]!;

  Widget _screen(AppTab t) => switch (t) {
    AppTab.architectures => const GmArchitecturesScreen(),
    AppTab.suivi => const GmTrackingScreen(),
    AppTab.netrun => const PlayerNetrunScreen(),
    AppTab.console => const PlayerConsoleScreen(),
  };

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final tabs = app.tabs;
    final current = app.tab;
    final first = tabs.first;
    return PopScope(
      // Le bouton retour ne quitte jamais le mode verrouillé ; en mode MJ il ramène au premier onglet.
      canPop: !app.locked && current == first,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && current != first) app.setTab(first);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: Theme.of(context).brightness == Brightness.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Scaffold(
          appBar: AppBar(
            title: Text(app.locked ? _label(app, current) : '${_label(app, current)} · MJ'),
            centerTitle: false,
          ),
          body: SafeArea(top: false, child: _screen(current)),
          bottomNavigationBar: NavigationBar(
            selectedIndex: tabs.indexOf(current),
            onDestinationSelected: (i) => app.setTab(tabs[i]),
            destinations: [
              for (final t in tabs)
                NavigationDestination(
                  icon: Icon(_icons[t]!.$1),
                  selectedIcon: Icon(_icons[t]!.$2),
                  label: _label(app, t),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
