import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/utils/platform_helper.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Reusable SearchBar with built-in debouncing to avoid API spam.
/// Resolves cleanly to CupertinoSearchTextField on iOS, and decorated TextField on Android.
class AppSearchBar extends StatefulWidget {
  final String hintText;
  final String? staticPrefix;
  final List<String>? animatedHints;
  final String? initialText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final Duration debounceDuration;
  final bool autofocus;

  const AppSearchBar({
    super.key,
    this.hintText = 'Search...',
    this.staticPrefix,
    this.animatedHints,
    this.initialText,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.debounceDuration = const Duration(milliseconds: 500),
    this.autofocus = false,
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}

class _AppSearchBarState extends State<AppSearchBar> {
  Timer? _debounceTimer;
  Timer? _typewriterTimer;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechEnabled = false;

  bool _isTypingActive = false;
  int _currentHintIndex = 0;
  String _currentHintText = '';

  String? _typewriterTarget;
  int _typewriterCharIndex = 0;
  bool _typewriterDeleting = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _currentHintText = widget.hintText;
    _initSpeech();

    final initial = widget.initialText;
    if (initial != null && initial.trim().isNotEmpty) {
      _controller.text = initial;
    }
    _hasText = _controller.text.isNotEmpty;

    if (widget.animatedHints != null && widget.animatedHints!.isNotEmpty) {
      _startTypewriter();
    }

    _focusNode.addListener(() {
      final isInteracting = _focusNode.hasFocus || _controller.text.isNotEmpty;
      if (isInteracting) {
        _stopTypewriter();
      } else {
        _resumeTypewriterIfNeeded();
      }

      if (_focusNode.hasFocus || _controller.text.isNotEmpty) {
        if (_currentHintText != widget.hintText) {
          setState(() {
            _currentHintText = widget.hintText;
          });
        }
      }
    });

    _controller.addListener(() {
      final nextHasText = _controller.text.isNotEmpty;
      if (nextHasText != _hasText && mounted) {
        setState(() {
          _hasText = nextHasText;
        });
      } else {
        _hasText = nextHasText;
      }

      final isInteracting = _focusNode.hasFocus || nextHasText;
      if (isInteracting) {
        _stopTypewriter();
      } else {
        _resumeTypewriterIfNeeded();
      }

      if (_focusNode.hasFocus || _controller.text.isNotEmpty) {
        if (_currentHintText != widget.hintText && mounted) {
          setState(() {
            _currentHintText = widget.hintText;
          });
        }
      }
    });
  }

  Future<void> _initSpeech() async {
    _speechEnabled = await _speech.initialize(
      onError: (val) => debugPrint('onSpeechError: $val'),
      onStatus: (val) {
        if (val == 'notListening' || val == 'done') {
           if (mounted) setState(() => _isListening = false);
        }
      },
    );
    if (mounted) setState(() {});
  }

  void _startListening() async {
    if (!_speechEnabled) {
      _speechEnabled = await _speech.initialize();
      if (!_speechEnabled) return;
    }
    await _speech.listen(onResult: (result) {
      if (mounted) {
        setState(() {
          _controller.text = result.recognizedWords;
          _hasText = _controller.text.isNotEmpty;
        });
        _onSearchChanged(result.recognizedWords);
      }
    });
    if (mounted) setState(() => _isListening = true);
  }

  void _stopListening() async {
    await _speech.stop();
    if (mounted) setState(() => _isListening = false);
  }

  void _toggleListening() {
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  void _stopTypewriter() {
    _isTypingActive = false;
    _typewriterTimer?.cancel();
  }

  void _resumeTypewriterIfNeeded() {
    if (!_focusNode.hasFocus && _controller.text.isEmpty) {
      final hints = widget.animatedHints;
      if (hints != null && hints.isNotEmpty) {
        _startTypewriter();
      }
    }
  }

  void _dismissFocus() {
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    }
  }

  void _startTypewriter() {
    _isTypingActive = true;
    _typewriterTimer?.cancel();

    final hints = widget.animatedHints;
    if (hints == null || hints.isEmpty) return;

    if (_currentHintIndex >= hints.length) {
      _currentHintIndex = 0;
    }

    _typewriterTarget = hints[_currentHintIndex];
    _typewriterCharIndex = 0;
    _typewriterDeleting = false;

    _scheduleTypewriterTick(const Duration(milliseconds: 50));
  }

  void _scheduleTypewriterTick(Duration delay) {
    _typewriterTimer?.cancel();
    _typewriterTimer = Timer(delay, _onTypewriterTick);
  }

  void _onTypewriterTick() {
    if (!mounted || !_isTypingActive) return;

    // Pause the animation while the user is interacting.
    if (_focusNode.hasFocus || _controller.text.isNotEmpty) {
      if (_currentHintText != widget.hintText) {
        setState(() => _currentHintText = widget.hintText);
      }
      _scheduleTypewriterTick(const Duration(milliseconds: 200));
      return;
    }

    final hints = widget.animatedHints;
    if (hints == null || hints.isEmpty) return;

    if (_currentHintIndex >= hints.length) {
      _currentHintIndex = 0;
    }

    final target = _typewriterTarget ?? hints[_currentHintIndex];
    final prefix = widget.staticPrefix ?? '';

    if (!_typewriterDeleting) {
      // Typing forward
      if (_typewriterCharIndex <= target.length) {
        setState(() {
          _currentHintText = prefix + target.substring(0, _typewriterCharIndex);
        });
        _typewriterCharIndex++;
        _scheduleTypewriterTick(const Duration(milliseconds: 50));
        return;
      }

      // Hold at the end
      _typewriterDeleting = true;
      _typewriterCharIndex = target.length;
      _scheduleTypewriterTick(const Duration(milliseconds: 2000));
      return;
    }

    // Deleting backward
    if (_typewriterCharIndex >= 0) {
      setState(() {
        _currentHintText = prefix + target.substring(0, _typewriterCharIndex);
      });
      _typewriterCharIndex--;
      _scheduleTypewriterTick(const Duration(milliseconds: 30));
      return;
    }

    // Move to next hint
    _currentHintIndex = (_currentHintIndex + 1) % hints.length;
    _typewriterTarget = hints[_currentHintIndex];
    _typewriterCharIndex = 0;
    _typewriterDeleting = false;
    _scheduleTypewriterTick(const Duration(milliseconds: 200));
  }

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    _debounceTimer = Timer(widget.debounceDuration, () {
      if (widget.onChanged != null) {
        widget.onChanged!(query);
      }
    });

    if (query.isEmpty && widget.onClear != null) {
      widget.onClear!();
    }
  }

  @override
  void dispose() {
    _isTypingActive = false;
    _debounceTimer?.cancel();
    _typewriterTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (PlatformHelper.isIOS) {
      return TapRegion(
        onTapOutside: (_) => _dismissFocus(),
        child: Row(
          children: [
            Expanded(
              child: CupertinoSearchTextField(
                controller: _controller,
                focusNode: _focusNode,
                placeholder: _currentHintText.isEmpty
                    ? (widget.animatedHints?.first ?? widget.hintText)
                    : _currentHintText,
                autofocus: widget.autofocus,
                onChanged: _onSearchChanged,
                onSubmitted: widget.onSubmitted ?? widget.onChanged,
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.only(left: 12),
              minSize: 0,
              onPressed: _toggleListening,
              child: Icon(
                _isListening ? CupertinoIcons.mic_fill : CupertinoIcons.mic,
                size: 24,
                color: _isListening ? theme.colorScheme.primary : CupertinoColors.systemGrey,
              ),
            ),
          ],
        ),
      );
    } else {
      return TapRegion(
        onTapOutside: (_) => _dismissFocus(),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          onChanged: _onSearchChanged,
          onSubmitted: widget.onSubmitted,
          decoration: InputDecoration(
            hintText: _currentHintText.isEmpty
                ? '\u200B'
                : _currentHintText, // Zero-width space to keep height steady
            prefixIcon: const Icon(Icons.search),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_hasText)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      _onSearchChanged('');
                    },
                  ),
                IconButton(
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? theme.colorScheme.primary : null,
                  ),
                  onPressed: _toggleListening,
                ),
                const SizedBox(width: 4),
              ],
            ),
            filled: true,
            fillColor: theme.colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 0,
              horizontal: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      );
    }
  }
}
