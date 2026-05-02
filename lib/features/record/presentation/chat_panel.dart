import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/providers/providers.dart';
import '../data/anthropic_service.dart';

class ChatPanel extends ConsumerStatefulWidget {
  const ChatPanel({super.key});

  @override
  ConsumerState<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends ConsumerState<ChatPanel> {
  late final AnthropicService _service;

  final _messages = <_Message>[];
  final _history  = <Map<String, String>>[];
  final _inputCtrl   = TextEditingController();
  final _keyCtrl     = TextEditingController();
  final _scrollCtrl  = ScrollController();

  bool _loading    = false;
  bool _hasKey     = false;
  bool _checkingKey = true;
  bool _keyVisible = false;

  @override
  void initState() {
    super.initState();
    _service = ref.read(anthropicServiceProvider);
    _loadKey();
  }

  Future<void> _loadKey() async {
    final key = await _service.getApiKey();
    if (!mounted) return;
    setState(() {
      _hasKey = key != null && key.isNotEmpty;
      _checkingKey = false;
      if (_hasKey) {
        _messages.add(const _Message(
          role: _Role.assistant,
          text: "Hello! I'm your AI assistant. Ask me anything about your meetings.",
        ));
      }
    });
  }

  Future<void> _saveKey() async {
    final key = _keyCtrl.text.trim();
    if (key.isEmpty) return;
    await _service.saveApiKey(key);
    _keyCtrl.clear();
    setState(() {
      _hasKey = true;
      _messages.add(const _Message(
        role: _Role.assistant,
        text: "Hello! I'm your AI assistant. Ask me anything about your meetings.",
      ));
    });
  }

  Future<void> _clearKey() async {
    await _service.deleteApiKey();
    setState(() {
      _hasKey = false;
      _messages.clear();
      _history.clear();
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _loading) return;

    setState(() {
      _messages.add(_Message(role: _Role.user, text: text));
      _loading = true;
    });
    _inputCtrl.clear();
    _scrollToBottom();

    _history.add({'role': 'user', 'content': text});
    final reply = await _service.send(List.from(_history));

    if (reply == '__INVALID_KEY__') {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasKey = false;
        _messages.clear();
        _history.clear();
      });
      return;
    }

    _history.add({'role': 'assistant', 'content': reply});
    if (!mounted) return;
    setState(() {
      _messages.add(_Message(role: _Role.assistant, text: reply));
      _loading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _keyCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_checkingKey) {
      return const Center(
        child: SizedBox(
          width: 24, height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _hasKey ? _buildChat() : _buildKeyInput()),
        if (_hasKey) _buildInput(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.surfaceElevated)),
      ),
      child: Row(
        children: [
          const Icon(Icons.smart_toy_rounded, color: AppColors.accent, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'AI Assistant',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_hasKey)
            Tooltip(
              message: 'Change API key',
              child: IconButton(
                icon: const Icon(Icons.key_rounded,
                    color: AppColors.textSecondary, size: 18),
                onPressed: _clearKey,
                splashRadius: 18,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKeyInput() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.key_rounded, color: AppColors.accent, size: 36),
          const SizedBox(height: 16),
          const Text(
            'Enter your Anthropic API key',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your key is stored locally on this device and never sent anywhere except api.anthropic.com.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _keyCtrl,
            obscureText: !_keyVisible,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            onSubmitted: (_) => _saveKey(),
            decoration: InputDecoration(
              hintText: 'sk-ant-...',
              hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              filled: true,
              fillColor: AppColors.surfaceElevated,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _keyVisible ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
                onPressed: () => setState(() => _keyVisible = !_keyVisible),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _saveKey,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            child: const Text(
              'Save & Connect',
              style: TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => _launchUrl('https://console.anthropic.com/account/keys'),
            child: const Text(
              'Get an API key →',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChat() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_loading ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _messages.length) return const _TypingIndicator();
        return _MessageBubble(message: _messages[i]);
      },
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.surfaceElevated)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtrl,
              onSubmitted: (_) => _send(),
              enabled: !_loading,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Ask AI...',
                hintStyle: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14),
                filled: true,
                fillColor: AppColors.surfaceElevated,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _loading ? null : _send,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _loading
                    ? AppColors.surfaceElevated
                    : AppColors.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.accent),
                    )
                  : const Icon(Icons.send_rounded,
                      color: AppColors.textPrimary, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

enum _Role { user, assistant }

class _Message {
  final _Role role;
  final String text;
  const _Message({required this.role, required this.text});
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Row(
                children: List.generate(3, (i) {
                  final delay = i / 3;
                  final t = ((_ctrl.value - delay) % 1.0).abs();
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Opacity(
                      opacity: t < 0.5 ? t * 2 : 2 - t * 2,
                      child: Container(
                        width: 6, height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.textSecondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _Message message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == _Role.user;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppColors.accent : AppColors.surfaceElevated,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Text(
                message.text,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
