import 'dart:async';
import 'package:flutter/material.dart';
import '../keyboard_service.dart';
import '../models/key_event.dart';

class KeyboardHistoryPage extends StatefulWidget {
  const KeyboardHistoryPage({super.key});

  @override
  State<KeyboardHistoryPage> createState() => _KeyboardHistoryPageState();
}

class _KeyboardHistoryPageState extends State<KeyboardHistoryPage> {
  final List<GlobalKeyEvent> _events = [];
  StreamSubscription<GlobalKeyEvent>? _sub;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _sub = KeyboardService.keyEvents.listen(
      (event) {
        if (!mounted) return;
        setState(() {
          _events.insert(0, event);
          if (_events.length > 300) _events.removeLast();
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => _errorMessage = error.toString());
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Row(
          children: [
            const Icon(Icons.keyboard, size: 18, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('Kysy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            if (_events.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_events.length}',
                  style: const TextStyle(fontSize: 11, color: Colors.blue),
                ),
              ),
          ],
        ),
        actions: [
          if (_events.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: 'Clear history',
              onPressed: () => setState(() => _events.clear()),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return _ErrorView(message: _errorMessage!);
    }
    if (_events.isEmpty) {
      return const _EmptyState();
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: _events.length,
      itemBuilder: (context, index) => _KeyEventTile(event: _events[index]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.keyboard_alt_outlined, size: 56, color: Color(0xFF2A2A2A)),
          SizedBox(height: 12),
          Text(
            'Waiting for key presses…',
            style: TextStyle(color: Color(0xFF404040), fontSize: 13),
          ),
          SizedBox(height: 4),
          Text(
            'Press any key to start capturing',
            style: TextStyle(color: Color(0xFF2A2A2A), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Accessibility Permission Required',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text(
              'Go to: System Settings → Privacy & Security → Accessibility\nEnable Kysy, then restart the app.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF555555), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyEventTile extends StatelessWidget {
  final GlobalKeyEvent event;
  const _KeyEventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final isDown = event.isKeyDown;
    final name = event.displayName;
    final isMod = event.isModifier;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: isDown
            ? (isMod
                ? Colors.purple.withValues(alpha: 0.12)
                : Colors.blue.withValues(alpha: 0.10))
            : const Color(0xFF111111),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isDown
              ? (isMod ? Colors.purple.withValues(alpha: 0.35) : Colors.blue.withValues(alpha: 0.3))
              : const Color(0xFF1E1E1E),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            _KeyBadge(name: name, isDown: isDown, isMod: isMod),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDown ? 'Key Down' : 'Key Up',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDown ? Colors.white70 : const Color(0xFF444444),
                      fontWeight: isDown ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                  Text(
                    'code ${event.keyCode}${_modString(event.modifiers)}',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF3A3A3A)),
                  ),
                ],
              ),
            ),
            Text(
              _formatTime(event.timestamp),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: Color(0xFF2E2E2E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _modString(Map<String, bool> mods) {
    final active = mods.entries.where((e) => e.value).map((e) => e.key);
    if (active.isEmpty) return '';
    return '  +${active.join('+')}';
  }

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}.'
      '${(t.millisecond ~/ 10).toString().padLeft(2, '0')}';
}

class _KeyBadge extends StatelessWidget {
  final String name;
  final bool isDown;
  final bool isMod;
  const _KeyBadge({required this.name, required this.isDown, required this.isMod});

  @override
  Widget build(BuildContext context) {
    final color = isMod ? Colors.purple : Colors.blue;
    return Container(
      width: 46,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDown ? color.withValues(alpha: 0.25) : const Color(0xFF181818),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isDown ? color.withValues(alpha: 0.5) : const Color(0xFF2A2A2A),
        ),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: name.length > 3 ? 10 : (name.length > 1 ? 13 : 18),
          fontWeight: FontWeight.bold,
          color: isDown ? Colors.white : const Color(0xFF333333),
        ),
      ),
    );
  }
}
