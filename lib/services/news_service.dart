import 'dart:convert';
import 'package:http/http.dart' as http;
import 'language_preference_service.dart';

class NewsArticle {
  final String title;
  final String description;
  final String url;
  final String? urlToImage;
  final String source;
  final String? author;
  final DateTime publishedAt;
  final String? content;
  final NewsLanguage language;

  NewsArticle({
    required this.title,
    required this.description,
    required this.url,
    this.urlToImage,
    required this.source,
    this.author,
    required this.publishedAt,
    this.content,
    required this.language,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json, {NewsLanguage? language}) {
    return NewsArticle(
      title: json['title'] ?? 'No title',
      description: json['description'] ?? 'No description available',
      url: json['url'] ?? '',
      urlToImage: json['urlToImage'],
      source: json['source']?['name'] ?? 'Unknown',
      author: json['author'],
      publishedAt: DateTime.tryParse(json['publishedAt'] ?? '') ?? DateTime.now(),
      content: json['content'],
      language: language ?? LanguagePreferenceService.currentLanguage,
    );
  }
}

class NewsService {
  // Using your actual NewsAPI.org API key
  static const String _baseUrl = 'https://newsapi.org/v2';
  static const String _apiKey = '6b47f16b85974dd3aa3f31e2540aa459';
  
  // Alternative free news sources (no API key required)
  static const String _rssToJsonUrl = 'https://api.rss2json.com/v1/api.json';

  static Future<List<NewsArticle>> getTopHeadlines() async {
    final language = LanguagePreferenceService.currentLanguage;
    return getTopHeadlinesForLanguage(language);
  }

  static Future<List<NewsArticle>> getTopHeadlinesForLanguage(NewsLanguage language) async {
    try {
      // Get top headlines based on language/country
      final response = await http.get(
        Uri.parse('$_baseUrl/top-headlines?country=${language.countryCode}&apiKey=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'ok') {
          final articles = data['articles'] as List;
          return articles.take(5).map<NewsArticle>((article) {
            return NewsArticle.fromJson(article, language: language);
          }).toList();
        } else {
          throw Exception('API Error: ${data['message'] ?? 'Unknown error'}');
        }
      } else {
        throw Exception('Failed to load news: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching top headlines for ${language.displayName}: $e');
      return _getFallbackNewsForLanguage(language);
    }
  }

  static Future<List<NewsArticle>> getAllNews() async {
    try {
      // Get more comprehensive news
      final response = await http.get(
        Uri.parse('$_baseUrl/top-headlines?country=us&pageSize=50&apiKey=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'ok') {
          final articles = data['articles'] as List;
          return articles.map<NewsArticle>((article) {
            return NewsArticle.fromJson(article);
          }).toList();
        } else {
          throw Exception('API Error: ${data['message'] ?? 'Unknown error'}');
        }
      } else {
        throw Exception('Failed to load news: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching all news: $e');
      return _getFallbackNews();
    }
  }

  static Future<List<NewsArticle>> getTechNews() async {
    try {
      // Get tech news from TechCrunch
      final response = await http.get(
        Uri.parse('$_baseUrl/top-headlines?sources=techcrunch&apiKey=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'ok') {
          final articles = data['articles'] as List;
          return articles.take(8).map<NewsArticle>((article) {
            return NewsArticle.fromJson(article, language: LanguagePreferenceService.currentLanguage);
          }).toList();
        } else {
          throw Exception('API Error: ${data['message'] ?? 'Unknown error'}');
        }
      } else {
        throw Exception('Failed to load tech news: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching tech news: $e');
      return _getFallbackTechNews();
    }
  }

  static Future<List<NewsArticle>> getBusinessNews() async {
    try {
      // Reuters Business RSS feed
      final response = await http.get(
        Uri.parse('$_rssToJsonUrl?rss_url=http://feeds.reuters.com/reuters/businessNews'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List;
        
        return items.take(8).map<NewsArticle>((item) {
          return NewsArticle(
            title: item['title'] ?? 'No title',
            description: _cleanDescription(item['description'] ?? 'No description available'),
            url: item['link'] ?? '',
            urlToImage: _extractImageFromDescription(item['description']),
            source: 'Reuters',
            publishedAt: DateTime.tryParse(item['pubDate'] ?? '') ?? DateTime.now(),
            language: LanguagePreferenceService.currentLanguage,
          );
        }).toList();
      } else {
        throw Exception('Failed to load business news: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching business news: $e');
      return _getFallbackBusinessNews();
    }
  }

  static Future<List<NewsArticle>> getSportsNews() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/top-headlines?category=sports&country=us&apiKey=$_apiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final articles = data['articles'] as List;
        return articles.map((article) => NewsArticle.fromJson(article, language: LanguagePreferenceService.currentLanguage)).toList();
      } else {
        throw Exception('Failed to load sports news: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching sports news: $e');
      return _getFallbackSportsNews();
    }
  }

  static Future<List<NewsArticle>> getHealthNews() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/top-headlines?category=health&country=us&apiKey=$_apiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final articles = data['articles'] as List;
        return articles.map((article) => NewsArticle.fromJson(article, language: LanguagePreferenceService.currentLanguage)).toList();
      } else {
        throw Exception('Failed to load health news: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching health news: $e');
      return _getFallbackHealthNews();
    }
  }

  static Future<List<NewsArticle>> getScienceNews() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/top-headlines?category=science&country=us&apiKey=$_apiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final articles = data['articles'] as List;
        return articles.map((article) => NewsArticle.fromJson(article, language: LanguagePreferenceService.currentLanguage)).toList();
      } else {
        throw Exception('Failed to load science news: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching science news: $e');
      return _getFallbackScienceNews();
    }
  }

  static Future<List<NewsArticle>> getEntertainmentNews() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/top-headlines?category=entertainment&country=us&apiKey=$_apiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final articles = data['articles'] as List;
        return articles.map((article) => NewsArticle.fromJson(article, language: LanguagePreferenceService.currentLanguage)).toList();
      } else {
        throw Exception('Failed to load entertainment news: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching entertainment news: $e');
      return _getFallbackEntertainmentNews();
    }
  }

  // Helper methods
  static String _cleanDescription(String description) {
    // Remove HTML tags and clean up description
    return description
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'&[a-zA-Z]+;'), ' ')
        .trim();
  }

  static String? _extractImageFromDescription(String? description) {
    if (description == null) return null;
    
    // Try to extract image URL from HTML content
    final imgRegex = RegExp(r'<img[^>]+src="([^">]+)"');
    final match = imgRegex.firstMatch(description);
    return match?.group(1);
  }

  // Fallback news when API fails
  static List<NewsArticle> _getFallbackNews() {
    return _getFallbackNewsForLanguage(LanguagePreferenceService.currentLanguage);
  }

  static List<NewsArticle> _getFallbackNewsForLanguage(NewsLanguage language) {
    switch (language) {
      case NewsLanguage.english:
        return [
          NewsArticle(
            title: 'Technology Updates',
            description: 'Stay updated with the latest technology trends and innovations.',
            url: 'https://techcrunch.com',
            urlToImage: null,
            source: 'Tech News',
            publishedAt: DateTime.now().subtract(const Duration(hours: 1)),
            language: language,
          ),
          NewsArticle(
            title: 'Global Business News',
            description: 'Latest business and economic news from around the world.',
            url: 'https://reuters.com/business',
            urlToImage: null,
            source: 'Business',
            publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
            language: language,
          ),
        ];
      case NewsLanguage.bengali:
        return [
          NewsArticle(
            title: 'প্রযুক্তির সর্বশেষ খবর',
            description: 'প্রযুক্তির জগতের সর্বশেষ উন্নতি এবং উদ্ভাবনের খবর।',
            url: 'https://prothomalo.com/technology',
            urlToImage: null,
            source: 'প্রথম আলো',
            publishedAt: DateTime.now().subtract(const Duration(hours: 1)),
            language: language,
          ),
          NewsArticle(
            title: 'ব্যবসা ও অর্থনীতি',
            description: 'দেশ ও বিদেশের ব্যবসা ও অর্থনীতির সর্বশেষ খবর।',
            url: 'https://prothomalo.com/business',
            urlToImage: null,
            source: 'প্রথম আলো',
            publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
            language: language,
          ),
        ];
      case NewsLanguage.hindi:
        return [
          NewsArticle(
            title: 'तकनीकी समाचार',
            description: 'नवीनतम तकनीकी रुझान और नवाचारों के साथ अपडेट रहें।',
            url: 'https://navbharattimes.indiatimes.com/tech',
            urlToImage: null,
            source: 'नव भारत टाइम्स',
            publishedAt: DateTime.now().subtract(const Duration(hours: 1)),
            language: language,
          ),
          NewsArticle(
            title: 'व्यापार समाचार',
            description: 'व्यापार और अर्थव्यवस्था की नवीनतम खबरें।',
            url: 'https://navbharattimes.indiatimes.com/business',
            urlToImage: null,
            source: 'नव भारत टाइम्स',
            publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
            language: language,
          ),
        ];
      case NewsLanguage.urdu:
        return [
          NewsArticle(
            title: 'ٹیکنالوجی کی خبریں',
            description: 'جدید ترین ٹیکنالوجی کے رجحانات اور ایجادات سے باخبر رہیں۔',
            url: 'https://jang.com.pk/category/tech',
            urlToImage: null,
            source: 'روزنامہ جنگ',
            publishedAt: DateTime.now().subtract(const Duration(hours: 1)),
            language: language,
          ),
          NewsArticle(
            title: 'کاروباری خبریں',
            description: 'کاروبار اور معیشت کی تازہ ترین خبریں۔',
            url: 'https://jang.com.pk/category/business',
            urlToImage: null,
            source: 'روزنامہ جنگ',
            publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
            language: language,
          ),
        ];
    }
  }

  static List<NewsArticle> _getFallbackTechNews() {
    return [
      NewsArticle(
        title: 'AI and Machine Learning Breakthroughs',
        description: 'Latest developments in artificial intelligence and ML technology.',
        url: 'https://techcrunch.com',
        urlToImage: null,
        source: 'Tech Today',
        publishedAt: DateTime.now().subtract(const Duration(hours: 1)),
        language: LanguagePreferenceService.currentLanguage,
      ),
    ];
  }

  static List<NewsArticle> _getFallbackBusinessNews() {
    return [
      NewsArticle(
        title: 'Stock Market Updates',
        description: 'Latest financial market trends and business developments.',
        url: 'https://reuters.com/business',
        urlToImage: null,
        source: 'Financial Times',
        publishedAt: DateTime.now().subtract(const Duration(hours: 1)),
        language: LanguagePreferenceService.currentLanguage,
      ),
    ];
  }

  static List<NewsArticle> _getFallbackSportsNews() {
    return [
      NewsArticle(
        title: 'Sports Headlines',
        description: 'Latest sports news and updates from around the world.',
        url: 'https://espn.com',
        urlToImage: null,
        source: 'ESPN',
        publishedAt: DateTime.now().subtract(const Duration(hours: 1)),
        language: LanguagePreferenceService.currentLanguage,
      ),
    ];
  }

  static List<NewsArticle> _getFallbackHealthNews() {
    return [
      NewsArticle(
        title: 'Health & Wellness',
        description: 'Latest health news and medical breakthroughs.',
        url: 'https://webmd.com',
        urlToImage: null,
        source: 'Health News',
        publishedAt: DateTime.now().subtract(const Duration(hours: 1)),
        language: LanguagePreferenceService.currentLanguage,
      ),
    ];
  }

  static List<NewsArticle> _getFallbackScienceNews() {
    return [
      NewsArticle(
        title: 'Science & Research',
        description: 'Latest scientific discoveries and research findings.',
        url: 'https://science.org',
        urlToImage: null,
        source: 'Science Journal',
        publishedAt: DateTime.now().subtract(const Duration(hours: 1)),
        language: LanguagePreferenceService.currentLanguage,
      ),
    ];
  }

  static List<NewsArticle> _getFallbackEntertainmentNews() {
    return [
      NewsArticle(
        title: 'Entertainment News',
        description: 'Latest entertainment and celebrity news.',
        url: 'https://variety.com',
        urlToImage: null,
        source: 'Entertainment Weekly',
        publishedAt: DateTime.now().subtract(const Duration(hours: 1)),
        language: LanguagePreferenceService.currentLanguage,
      ),
    ];
  }
}