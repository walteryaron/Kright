import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'ai/gemini_service.dart';
import 'keyboard_service.dart';
import 'ui/keyboard_history_page.dart';
import 'ui/text_expansion_page.dart';
import 'ui/settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(460, 680),
    center: true,
    title: 'Kysy',
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    backgroundColor: Color(0xFF0D0D0D),
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setPreventClose(true);
    await windowManager.hide();
  });

  await GeminiService.init();
  await _setupTray();
  KeyboardService.startListening();

  runApp(const KysyApp());
}

Future<void> _setupTray() async {
  await trayManager.setIcon('assets/tray_icon.png');
  await trayManager.setContextMenu(Menu(items: [
    MenuItem(key: 'expand',       label: 'Text Expansion'),
    MenuItem(key: 'history',      label: 'Key History'),
    MenuItem.separator(),
    MenuItem(key: 'settings',     label: 'Settings'),
    MenuItem.separator(),
    MenuItem(key: 'quit',         label: 'Quit Kysy'),
  ]));
}

class KysyApp extends StatelessWidget {
  const KysyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kysy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: const KysyHome(),
    );
  }
}

class KysyHome extends StatefulWidget {
  const KysyHome({super.key});

  @override
  State<KysyHome> createState() => _KysyHomeState();
}

class _KysyHomeState extends State<KysyHome>
    with TrayListener, WindowListener {
  int _tab = 0;

  static const _pages = [
    TextExpansionPage(),
    KeyboardHistoryPage(),
  ];

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.isVisible().then((visible) {
      if (visible) {
        windowManager.hide();
      } else {
        windowManager.show();
        windowManager.focus();
      }
    });
  }

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem item) {
    switch (item.key) {
      case 'expand':
        setState(() => _tab = 0);
        windowManager.show();
        windowManager.focus();
      case 'history':
        setState(() => _tab = 1);
        windowManager.show();
        windowManager.focus();
      case 'settings':
        windowManager.show();
        windowManager.focus();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          );
        });
      case 'quit':
        windowManager.destroy();
    }
  }

  @override
  void onWindowClose() => windowManager.hide();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Column(
        children: [
          _TabBar(current: _tab, onTap: (i) => setState(() => _tab = i)),
          Expanded(child: _pages[_tab]),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _TabBar({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111111),
      child: Row(
        children: [
          _Tab(label: 'Expand', icon: Icons.auto_awesome, selected: current == 0, onTap: () => onTap(0)),
          _Tab(label: 'Key Log', icon: Icons.keyboard, selected: current == 1, onTap: () => onTap(1)),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? Colors.blue : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: selected ? Colors.blue : const Color(0xFF555555)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? Colors.blue : const Color(0xFF555555),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
