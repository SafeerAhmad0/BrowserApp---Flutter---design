import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class VoiceSearchService {
  static final stt.SpeechToText _speech = stt.SpeechToText();
  static bool _isInitialized = false;
  static bool _isListening = false;
  static String _lastWords = '';

  static Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      _isInitialized = await _speech.initialize(
        onError: (error) {
          print('Speech recognition error: $error');
          _isListening = false;
        },
        onStatus: (status) {
          print('Speech recognition status: $status');
          _isListening = status == 'listening';
        },
      );
      
      print('VoiceSearchService initialized: $_isInitialized');
      return _isInitialized;
    } catch (e) {
      print('Error initializing speech recognition: $e');
      _isInitialized = false;
      return false;
    }
  }

  static Future<bool> requestPermission() async {
    try {
      final status = await Permission.microphone.request();
      return status == PermissionStatus.granted;
    } catch (e) {
      print('Error requesting microphone permission: $e');
      return false;
    }
  }

  static bool get isAvailable => _isInitialized && _speech.isAvailable;
  static bool get isListening => _isListening;

  static Future<String?> startListening() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_isInitialized || !_speech.isAvailable) {
      throw Exception('Speech recognition not available');
    }

    // Request microphone permission
    final hasPermission = await requestPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission denied');
    }

    try {
      _lastWords = '';
      _isListening = true;

      await _speech.listen(
        onResult: (result) {
          _lastWords = result.recognizedWords;
          print('Speech result: $_lastWords');
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: 'en_US',
        onSoundLevelChange: (level) {
          // Optional: Handle sound level changes
        },
      );

      // Wait for listening to complete
      while (_isListening && _speech.isListening) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      return _lastWords.isNotEmpty ? _lastWords : null;
    } catch (e) {
      print('Error during speech recognition: $e');
      _isListening = false;
      throw Exception('Speech recognition failed: $e');
    }
  }

  static Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
    _isListening = false;
  }

  static Future<void> cancel() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
    _isListening = false;
    _lastWords = '';
  }
}
