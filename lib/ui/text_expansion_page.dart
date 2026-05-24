import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ai/gemini_service.dart';
import 'settings_page.dart';

class TextExpansionPage extends StatefulWidget {
  const TextExpansionPage({super.key});

  @override
  State<TextExpansionPage> createState() => _TextExpansionPageState();
}

class _TextExpansionPageState extends State<TextExpansionPage> {
  final _inputController = TextEditingController();
  final _inputFocus = FocusNode();

  String _output = '';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _expand() async {
    final input = _inputController.text.trim();
    if (input.isEmpty) return;
    if (!GeminiService.isReady) {
      setState(() => _error = 'Add your Gemini API key in Settings first.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _output = '';
    });

    try {
      final result = await GeminiService.expand(input);
      setState(() => _output = result);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _copyOutput() async {
    if (_output.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _output));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, size: 16, color: Colors.blue),
            SizedBox(width: 8),
            Text('Text Expansion', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 18),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _InputCard(
              controller: _inputController,
              focusNode: _inputFocus,
              loading: _loading,
              onSubmit: _expand,
            ),
            const SizedBox(height: 12),
            if (_error != null) _ErrorBanner(message: _error!),
            if (_loading) const _LoadingIndicator(),
            if (_output.isNotEmpty && !_loading)
              Expanded(child: _OutputCard(text: _output, onCopy: _copyOutput)),
            if (_output.isEmpty && !_loading && _error == null)
              const Expanded(child: _HintView()),
          ],
        ),
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool loading;
  final VoidCallback onSubmit;

  const _InputCard({
    required this.controller,
    required this.focusNode,
    required this.loading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: true,
            maxLines: 3,
            minLines: 1,
            style: const TextStyle(fontSize: 14, color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Type a short phrase…  e.g. "ty for meeting", "apology late delivery"',
              hintStyle: TextStyle(color: Color(0xFF404040), fontSize: 13),
              border: InputBorder.none,
              isDense: true,
            ),
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: controller.clear,
                child: const Text('Clear', style: TextStyle(color: Color(0xFF555555), fontSize: 12)),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: loading ? null : onSubmit,
                icon: const Icon(Icons.auto_awesome, size: 14),
                label: const Text('Expand', style: TextStyle(fontSize: 13)),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OutputCard extends StatelessWidget {
  final String text;
  final VoidCallback onCopy;

  const _OutputCard({required this.text, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1F0F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                const SizedBox(width: 6),
                const Text('Expanded', style: TextStyle(fontSize: 11, color: Colors.green)),
                const Spacer(),
                TextButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy, size: 13),
                  label: const Text('Copy', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: Colors.green),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: SelectableText(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFCCCCCC),
                  height: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
            ),
            SizedBox(height: 12),
            Text('Expanding…', style: TextStyle(color: Color(0xFF555555), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 14, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: 12, color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _HintView extends StatelessWidget {
  const _HintView();

  @override
  Widget build(BuildContext context) {
    const examples = [
      ('ty for meeting', 'Thank you for taking the time to meet…'),
      ('apology late reply', 'I apologize for the delayed response…'),
      ('meeting request mon 3pm', 'I would like to schedule a meeting…'),
      ('intro email new client', 'I\'m reaching out to introduce myself…'),
    ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Examples', style: TextStyle(color: Color(0xFF333333), fontSize: 11)),
        const SizedBox(height: 12),
        ...examples.map((e) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2A),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF2A2A3A)),
                ),
                child: Text(e.$1, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF6699CC))),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, size: 10, color: Color(0xFF333333)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(e.$2, style: const TextStyle(fontSize: 11, color: Color(0xFF444444))),
              ),
            ],
          ),
        )),
      ],
    );
  }
}
