import 'package:shared_preferences/shared_preferences.dart';

enum NewsLanguage {
  english('en', 'English', 'us'),
  bengali('bn', 'বাংলা', 'bd'),
  hindi('hi', 'हिंदी', 'in'),
  urdu('ur', 'اردو', 'pk');

  const NewsLanguage(this.code, this.displayName, this.countryCode);

  final String code;
  final String displayName;
  final String countryCode;
}

class LanguagePreferenceService {
  static const String _languageKey = 'preferred_news_language';
  static NewsLanguage _currentLanguage = NewsLanguage.english;

  static NewsLanguage get currentLanguage => _currentLanguage;

  static Future<void> loadLanguagePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString(_languageKey);

      if (savedLanguage != null) {
        for (NewsLanguage lang in NewsLanguage.values) {
          if (lang.code == savedLanguage) {
            _currentLanguage = lang;
            break;
          }
        }
      }
    } catch (e) {
      _currentLanguage = NewsLanguage.english;
    }
  }

  static Future<void> setLanguagePreference(NewsLanguage language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, language.code);
      _currentLanguage = language;
    } catch (e) {
      // Silent error handling
    }
  }

  static List<NewsLanguage> get availableLanguages => NewsLanguage.values;

  // Get news sources based on language
  static List<String> getNewsSourcesForLanguage(NewsLanguage language) {
    switch (language) {
      case NewsLanguage.english:
        return ['bbc-news', 'cnn', 'techcrunch', 'reuters'];
      case NewsLanguage.bengali:
        return ['google-news-bd']; // Will use country-based news
      case NewsLanguage.hindi:
        return ['google-news-in']; // Will use country-based news
      case NewsLanguage.urdu:
        return ['google-news-pk']; // Will use country-based news
    }
  }

  // Get search terms for different languages
  static List<String> getLocalSearchTerms(NewsLanguage language) {
    switch (language) {
      case NewsLanguage.english:
        return ['technology', 'business', 'sports', 'health'];
      case NewsLanguage.bengali:
        return ['প্রযুক্তি', 'ব্যবসা', 'খেলাধুলা', 'স্বাস্থ্য'];
      case NewsLanguage.hindi:
        return ['प्रौद्योगिकी', 'व्यापार', 'खेल', 'स्वास्थ्य'];
      case NewsLanguage.urdu:
        return ['ٹیکنالوجی', 'کاروبار', 'کھیل', 'صحت'];
    }
  }
}