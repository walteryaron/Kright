import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'keyboard_service.dart';
import 'ui/keyboard_history_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  const windowOptions = WindowOptions(
    size: Size(420, 640),
    center: true,
    title: 'Kysy — Key History',
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    backgroundColor: Color(0xFF0D0D0D),
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setPreventClose(true);
    await windowManager.hide();
  });

  await _setupTray();
  KeyboardService.startListening();

  runApp(const KysyApp());
}

Future<void> _setupTray() async {
  await trayManager.setIcon('assets/tray_icon.png');
  await trayManager.setContextMenu(Menu(items: [
    MenuItem(key: 'show_history', label: 'Show Key History'),
    MenuItem.separator(),
    MenuItem(key: 'clear_history', label: 'Clear History'),
    MenuItem.separator(),
    MenuItem(key: 'quit', label: 'Quit Kysy'),
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
      home: const KeyboardHistoryPage(),
    );
  }
}
