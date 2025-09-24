import 'services/translation_service.dart';
import 'services/language_preference_service.dart';

/// Test file to verify translation system works correctly
/// Run this with: dart lib/test_translation.dart
void main() async {
  print('🧪 Testing Translation System...\n');

  // Initialize language service
  await LanguagePreferenceService.loadLanguagePreference();

  // Test translations for each language
  final testTexts = [
    'Breaking News: Technology stocks surge on AI breakthrough',
    'Global markets rally as inflation fears ease',
    'Scientists discover new treatment for diabetes',
    'Football World Cup final attracts record viewership',
    'Climate change summit reaches historic agreement',
  ];

  for (final language in NewsLanguage.values) {
    if (language == NewsLanguage.english) continue;

    print('📝 Testing ${language.displayName} translation:');
    print('=' * 50);

    for (int i = 0; i < testTexts.length; i++) {
      final originalText = testTexts[i];
      print('Original: $originalText');

      try {
        final translatedText = await TranslationService.translateText(originalText, language);
        print('Translated: $translatedText');
        print('✅ Success!\n');
      } catch (e) {
        print('❌ Failed: $e\n');
      }

      // Small delay between translations
      await Future.delayed(const Duration(milliseconds: 500));
    }

    print('\n');
  }

  // Test batch translation
  print('🔄 Testing batch translation to Bengali...');
  try {
    final batchResults = await TranslationService.translateBatch(testTexts, NewsLanguage.bengali);
    for (int i = 0; i < testTexts.length; i++) {
      print('${i + 1}. ${testTexts[i]}');
      print('   → ${batchResults[i]}\n');
    }
    print('✅ Batch translation successful!');
  } catch (e) {
    print('❌ Batch translation failed: $e');
  }

  // Test cache stats
  print('\n📊 Cache Statistics:');
  final cacheStats = await TranslationService.getCacheStats();
  cacheStats.forEach((key, value) {
    print('$key: $value');
  });

  print('\n🎉 Translation system test completed!');
}