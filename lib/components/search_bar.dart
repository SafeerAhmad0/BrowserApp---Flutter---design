import 'package:flutter/material.dart';
import '../services/voice_search_service.dart';

class SearchBar extends StatefulWidget {
  final Function(String) onSearch;
  final VoidCallback? onVoiceSearch;
  final String? hintText;
  
  const SearchBar({
    super.key,
    required this.onSearch,
    this.onVoiceSearch,
    this.hintText,
  });

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isListening = false;
  
  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleVoiceSearch() async {
    if (_isListening) {
      await VoiceSearchService.stopListening();
      setState(() {
        _isListening = false;
      });
      return;
    }

    // Check if voice search is available
    if (!VoiceSearchService.isAvailable) {
      await VoiceSearchService.initialize();
    }

    setState(() {
      _isListening = true;
    });

    try {
      // Show listening feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Listening... Speak now'),
              ],
            ),
            duration: const Duration(seconds: 10),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      final result = await VoiceSearchService.startListening();
      
      setState(() {
        _isListening = false;
      });

      // Hide the listening snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      if (result != null && result.trim().isNotEmpty) {
        _controller.text = result.trim();
        widget.onSearch(result.trim());
        
        // Show success feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Heard: "$result"'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No speech detected. Please try again.'),
              duration: Duration(seconds: 3),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isListening = false;
      });
      
      // Hide the listening snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
      
      String errorMessage = 'Voice search failed. Please try again.';
      if (e.toString().contains('permission')) {
        errorMessage = 'Microphone permission required for voice search.';
      } else if (e.toString().contains('not available')) {
        errorMessage = 'Voice search not available on this device.';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    // Call the original callback if provided
    if (widget.onVoiceSearch != null) {
      widget.onVoiceSearch!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withOpacity(0.1),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          hintText: widget.hintText ?? "Search or enter website URL",
          hintStyle: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
          ),
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search, color: Color(0xFF2196F3), size: 20),
          suffixIcon: IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _isListening
                ? const Icon(
                    Icons.mic,
                    color: Colors.red,
                    size: 20,
                    key: ValueKey('listening'),
                  )
                : const Icon(
                    Icons.mic,
                    color: Color(0xFF2196F3),
                    size: 20,
                    key: ValueKey('idle'),
                  ),
            ),
            onPressed: _handleVoiceSearch,
            tooltip: _isListening ? 'Stop listening' : 'Voice search',
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
        ),
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black87,
        ),
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            widget.onSearch(value.trim());
            _focusNode.unfocus();
          }
        },
        textInputAction: TextInputAction.search,
      ),
    );
  }
}
