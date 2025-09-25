import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import '../components/admin_card_widget.dart';

class AdminCardService {
  static final DatabaseReference _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://test-51a88-default-rtdb.firebaseio.com',
  ).ref();

  static List<AdminCard> _adminCards = [];
  static bool _isLoaded = false;

  /// Get all admin cards
  static List<AdminCard> get adminCards => _adminCards;

  /// Check if admin cards are loaded
  static bool get isLoaded => _isLoaded;

  /// Load admin cards from Firebase
  static Future<List<AdminCard>> loadAdminCards() async {
    try {
      final snapshot = await _database.child('admin_cards').get();

      _adminCards.clear();

      if (snapshot.exists && snapshot.value is Map) {
        final cardsData = snapshot.value as Map<dynamic, dynamic>;

        // Load cards in order: card1, card2, card3
        for (int i = 1; i <= 3; i++) {
          final cardKey = 'card$i';
          if (cardsData.containsKey(cardKey)) {
            final cardData = cardsData[cardKey] as Map<dynamic, dynamic>;

            // Only add card if it has title and description
            if (cardData['title'] != null &&
                cardData['description'] != null &&
                cardData['title'].toString().trim().isNotEmpty &&
                cardData['description'].toString().trim().isNotEmpty) {

              final adminCard = AdminCard.fromJson(cardData);
              if (adminCard.isActive) {
                _adminCards.add(adminCard);
              }
            }
          }
        }
      }

      _isLoaded = true;
      print('🟢 ADMIN CARDS: Loaded ${_adminCards.length} admin cards');

      return _adminCards;
    } catch (e) {
      print('🔴 ADMIN CARDS ERROR: Failed to load admin cards: $e');
      _adminCards = [];
      _isLoaded = true;
      return [];
    }
  }

  /// Get admin card by index with cycling (0, 1, 2, 0, 1, 2, ...)
  static AdminCard? getCardByIndex(int index) {
    if (_adminCards.isEmpty) return null;

    final cycleIndex = index % _adminCards.length;
    return _adminCards[cycleIndex];
  }

  /// Get card number for display (cycles through 1, 2, 3, 1, 2, 3, ...)
  static int getCardDisplayNumber(int index) {
    if (_adminCards.isEmpty) return 0;

    return (index % _adminCards.length);
  }

  /// Refresh admin cards (reload from Firebase)
  static Future<void> refreshAdminCards() async {
    _isLoaded = false;
    await loadAdminCards();
  }

  /// Clear loaded admin cards
  static void clearCards() {
    _adminCards.clear();
    _isLoaded = false;
  }
}