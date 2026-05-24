import 'package:flutter/material.dart';
import '../ai/gemini_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _keyController = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    GeminiService.getApiKey().then((key) {
      if (key != null && mounted) {
        _keyController.text = key;
      }
    });
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _saving = true; _status = null; });
    try {
      await GeminiService.setApiKey(_keyController.text);
      setState(() => _status = GeminiService.isReady ? 'Saved' : 'Cleared');
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Settings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Gemini API Key',
              style: TextStyle(fontSize: 12, color: Color(0xFF888888), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: TextField(
                controller: _keyController,
                obscureText: _obscure,
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'AIza…',
                  hintStyle: const TextStyle(color: Color(0xFF404040)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 16),
                    onPressed: () => setState(() => _obscure = !_obscure),
                    color: const Color(0xFF555555),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Get a free key at aistudio.google.com → Get API key',
              style: TextStyle(fontSize: 11, color: Color(0xFF444444)),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: Colors.blue),
              child: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Key'),
            ),
            if (_status != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    _status == 'Saved' ? Icons.check_circle_outline : Icons.info_outline,
                    size: 14,
                    color: _status == 'Saved' ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _status!,
                    style: TextStyle(
                      fontSize: 12,
                      color: _status == 'Saved' ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
