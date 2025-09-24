import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translator/translator.dart';
import 'language_preference_service.dart';

class TranslationService {
  static final GoogleTranslator _translator = GoogleTranslator();
  static const Duration _cacheExpiration = Duration(hours: 24);
  static const String _cacheKeyPrefix = 'translation_cache_';
  static const int _maxCacheSize = 1000; // Maximum cached translations

  // Translation cache in memory for faster access
  static final Map<String, Map<String, dynamic>> _memoryCache = {};

  /// Translates text from English to the target language
  static Future<String> translateText(String text, NewsLanguage targetLanguage) async {
    // If target is English, return original text
    if (targetLanguage == NewsLanguage.english) {
      return text;
    }

    // Check memory cache first
    final cacheKey = _generateCacheKey(text, targetLanguage);
    if (_memoryCache.containsKey(cacheKey)) {
      final cached = _memoryCache[cacheKey]!;
      if (_isCacheValid(cached['timestamp'])) {
        print('📝 Translation cache HIT (memory): ${text.substring(0, 50)}...');
        return cached['translation'];
      } else {
        _memoryCache.remove(cacheKey);
      }
    }

    // Check persistent cache
    final cachedTranslation = await _getCachedTranslation(text, targetLanguage);
    if (cachedTranslation != null) {
      // Add to memory cache
      _memoryCache[cacheKey] = {
        'translation': cachedTranslation,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      print('📝 Translation cache HIT (disk): ${text.substring(0, 50)}...');
      return cachedTranslation;
    }

    try {
      print('🌐 Translating: ${text.substring(0, 50)}... -> ${targetLanguage.displayName}');

      // Perform translation
      final translation = await _translator.translate(
        text,
        from: 'en',
        to: targetLanguage.code,
      );

      final translatedText = translation.text;
      print('✅ Translation success: ${translatedText.substring(0, 50)}...');

      // Cache the translation
      await _cacheTranslation(text, targetLanguage, translatedText);

      // Add to memory cache
      _memoryCache[cacheKey] = {
        'translation': translatedText,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      return translatedText;

    } catch (e) {
      print('❌ Translation failed: $e');

      // Return original text with language indicator on failure
      switch (targetLanguage) {
        case NewsLanguage.bengali:
          return '$text [অনুবাদ ব্যর্থ]';
        case NewsLanguage.hindi:
          return '$text [अनुवाद असफल]';
        case NewsLanguage.urdu:
          return '$text [ترجمہ ناکام]';
        default:
          return text;
      }
    }
  }

  /// Translates multiple texts in batch for better performance
  static Future<List<String>> translateBatch(List<String> texts, NewsLanguage targetLanguage) async {
    if (targetLanguage == NewsLanguage.english) {
      return texts;
    }

    final List<String> results = [];

    // Process in chunks of 5 to avoid overwhelming the API
    const chunkSize = 5;
    for (int i = 0; i < texts.length; i += chunkSize) {
      final chunk = texts.sublist(i, i + chunkSize > texts.length ? texts.length : i + chunkSize);
      final futures = chunk.map((text) => translateText(text, targetLanguage));
      final chunkResults = await Future.wait(futures);
      results.addAll(chunkResults);

      // Small delay between chunks to be respectful to the API
      if (i + chunkSize < texts.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    return results;
  }

  /// Preloads common translations for better UX
  static Future<void> preloadCommonTranslations(NewsLanguage targetLanguage) async {
    if (targetLanguage == NewsLanguage.english) return;

    final commonTexts = [
      'Technology Updates',
      'Business News',
      'Sports News',
      'Health News',
      'Entertainment News',
      'Breaking News',
      'Latest News',
      'World News',
      'Loading...',
      'Read More',
      'Share',
      'Save',
    ];

    print('🔄 Preloading common translations for ${targetLanguage.displayName}...');
    await translateBatch(commonTexts, targetLanguage);
    print('✅ Common translations preloaded');
  }

  /// Generates a unique cache key for translation
  static String _generateCacheKey(String text, NewsLanguage targetLanguage) {
    final textHash = text.hashCode.toString();
    return '${_cacheKeyPrefix}${targetLanguage.code}_$textHash';
  }

  /// Checks if cached translation is still valid
  static bool _isCacheValid(int timestamp) {
    final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateTime.now().difference(cacheTime) < _cacheExpiration;
  }

  /// Gets cached translation from persistent storage
  static Future<String?> _getCachedTranslation(String text, NewsLanguage targetLanguage) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _generateCacheKey(text, targetLanguage);
      final cachedData = prefs.getString(cacheKey);

      if (cachedData != null) {
        final Map<String, dynamic> cache = json.decode(cachedData);
        if (_isCacheValid(cache['timestamp'])) {
          return cache['translation'];
        } else {
          // Remove expired cache
          await prefs.remove(cacheKey);
        }
      }
    } catch (e) {
      print('Error reading translation cache: $e');
    }
    return null;
  }

  /// Caches translation to persistent storage
  static Future<void> _cacheTranslation(String originalText, NewsLanguage targetLanguage, String translation) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _generateCacheKey(originalText, targetLanguage);

      // Check cache size and clean if necessary
      await _cleanCacheIfNeeded(prefs);

      final cacheData = {
        'translation': translation,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'original': originalText,
        'language': targetLanguage.code,
      };

      await prefs.setString(cacheKey, json.encode(cacheData));
    } catch (e) {
      print('Error caching translation: $e');
    }
  }

  /// Cleans old cache entries if cache size exceeds limit
  static Future<void> _cleanCacheIfNeeded(SharedPreferences prefs) async {
    try {
      final keys = prefs.getKeys().where((key) => key.startsWith(_cacheKeyPrefix)).toList();

      if (keys.length > _maxCacheSize) {
        print('🧹 Cleaning translation cache (${keys.length} entries)...');

        // Sort by timestamp and remove oldest entries
        final List<Map<String, dynamic>> cacheEntries = [];

        for (final key in keys) {
          try {
            final cachedData = prefs.getString(key);
            if (cachedData != null) {
              final cache = json.decode(cachedData);
              cacheEntries.add({
                'key': key,
                'timestamp': cache['timestamp'],
              });
            }
          } catch (e) {
            // Remove corrupted cache entry
            await prefs.remove(key);
          }
        }

        // Sort by timestamp (oldest first)
        cacheEntries.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));

        // Remove oldest 20% of entries
        final entriesToRemove = (cacheEntries.length * 0.2).round();
        for (int i = 0; i < entriesToRemove; i++) {
          await prefs.remove(cacheEntries[i]['key']);
        }

        print('✅ Removed $entriesToRemove old cache entries');
      }
    } catch (e) {
      print('Error cleaning translation cache: $e');
    }
  }

  /// Clears all translation cache
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith(_cacheKeyPrefix)).toList();

      for (final key in keys) {
        await prefs.remove(key);
      }

      _memoryCache.clear();
      print('🗑️ All translation cache cleared (${keys.length} entries)');
    } catch (e) {
      print('Error clearing translation cache: $e');
    }
  }

  /// Gets cache statistics
  static Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith(_cacheKeyPrefix)).toList();

      int validEntries = 0;
      int expiredEntries = 0;

      for (final key in keys) {
        try {
          final cachedData = prefs.getString(key);
          if (cachedData != null) {
            final cache = json.decode(cachedData);
            if (_isCacheValid(cache['timestamp'])) {
              validEntries++;
            } else {
              expiredEntries++;
            }
          }
        } catch (e) {
          expiredEntries++;
        }
      }

      return {
        'total_entries': keys.length,
        'valid_entries': validEntries,
        'expired_entries': expiredEntries,
        'memory_cache_entries': _memoryCache.length,
        'cache_hit_ratio': _memoryCache.isNotEmpty ? '${(_memoryCache.length / (keys.length + _memoryCache.length) * 100).toStringAsFixed(1)}%' : '0%',
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}