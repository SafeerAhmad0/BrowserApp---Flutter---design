import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import '../components/admin_card_widget.dart';

class AdminCardService {
  static final DatabaseReference _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://bluex-browser-default-rtdb.firebaseio.com',
  ).ref();

  static List<AdminCard> _adminCards = [];
  static bool _isLoaded = false;

  /// Get all admin cards
  static List<AdminCard> get adminCards => _adminCards;

  /// Check if admin cards are loaded
  static bool get isLoaded => _isLoaded;

  /// Load admin cards from Realtime Database
  static Future<List<AdminCard>> loadAdminCards() async {
    try {
      final snapshot = await _database.child('admin_cards').get();

      _adminCards.clear();

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;

        // Sort by card number (card1, card2, card3)
        final sortedKeys = data.keys.toList()..sort();

        for (final key in sortedKeys) {
          final cardData = data[key] as Map<dynamic, dynamic>;

          // Only add card if it has title and url
          if (cardData['title'] != null &&
              cardData['url'] != null &&
              cardData['title'].toString().trim().isNotEmpty &&
              cardData['url'].toString().trim().isNotEmpty) {

            final adminCard = AdminCard.fromJson(Map<String, dynamic>.from(cardData));
            if (adminCard.isActive) {
              _adminCards.add(adminCard);
            }
          }
        }
      }

      _isLoaded = true;

      return _adminCards;
    } catch (e) {
      _adminCards = [];
      _isLoaded = true;
      return [];
    }
  }

  /// Save admin card to Realtime Database
  static Future<void> saveAdminCard(int cardNumber, AdminCard card) async {
    try {
      await _database.child('admin_cards').child('card$cardNumber').set(card.toJson());

      // Reload cards to update the local list
      await loadAdminCards();
    } catch (e) {
      throw Exception('Failed to save admin card: $e');
    }
  }

  /// Delete admin card from Realtime Database
  static Future<void> deleteAdminCard(int cardNumber) async {
    try {
      await _database.child('admin_cards').child('card$cardNumber').remove();

      // Reload cards to update the local list
      await loadAdminCards();
    } catch (e) {
      throw Exception('Failed to delete admin card: $e');
    }
  }

  /// Get admin card by cycling index (for display in news feed)
  static AdminCard? getCardByIndex(int index) {
    if (_adminCards.isEmpty) return null;
    return _adminCards[index % _adminCards.length];
  }

  /// Get display number for card (1, 2, 3, 1, 2, 3...)
  static int getCardDisplayNumber(int index) {
    if (_adminCards.isEmpty) return 1;
    return (index % _adminCards.length) + 1;
  }

  /// Calculate news articles to show before next admin card
  /// Pattern: 3, 4, 5, 3, 4, 5, ...
  static int getNewsCountBeforeCard(int cardIndex) {
    final pattern = [3, 4, 5];
    return pattern[cardIndex % pattern.length];
  }

  /// NEW PATTERN: Get positions where admin cards should appear
  /// After 3 news → card1, after 4 more news → card2, after 5 more news → card3, repeat
  static List<int> getAdminCardPositions(int totalNewsCount) {
    List<int> positions = [];

    // Return empty if no admin cards
    if (_adminCards.isEmpty) {
      return positions;
    }

    int currentPosition = 0;
    int cardIndex = 0;

    while (currentPosition < totalNewsCount && cardIndex < 100) { // Safety limit
      // Get how many news articles before this card
      final newsBeforeCard = getNewsCountBeforeCard(cardIndex % 3);
      currentPosition += newsBeforeCard;

      if (currentPosition <= totalNewsCount) {
        positions.add(currentPosition);
      }

      cardIndex++;
    }

    return positions;
  }

  /// Check if admin card should be shown at this news position
  static bool shouldShowAdminCardAt(int newsPosition, List<int> cardPositions) {
    return cardPositions.contains(newsPosition);
  }

  /// Get which admin card to show at a specific position
  static AdminCard? getAdminCardAtPosition(int position, List<int> cardPositions) {
    final positionIndex = cardPositions.indexOf(position);
    if (positionIndex == -1) return null;

    return getCardByIndex(positionIndex);
  }

  /// Get admin card by card number (1, 2, or 3)
  static AdminCard? getAdminCardByNumber(int cardNumber) {
    if (cardNumber < 1 || cardNumber > _adminCards.length) return null;
    return _adminCards[cardNumber - 1];
  }

  /// Refresh admin cards (reload from Realtime Database)
  static Future<void> refreshAdminCards() async {
    _isLoaded = false;
    await loadAdminCards();
  }

  /// Clear loaded admin cards
  static void clearCards() {
    _adminCards.clear();
    _isLoaded = false;
  }

  /// Debug: Print current pattern
  static void debugPattern(int totalNews) {
    final positions = getAdminCardPositions(totalNews);
  }
}