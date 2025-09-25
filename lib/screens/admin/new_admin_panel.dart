import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/auth_service.dart';

class NewAdminPanel extends StatefulWidget {
  const NewAdminPanel({super.key});

  @override
  State<NewAdminPanel> createState() => _NewAdminPanelState();
}

class _NewAdminPanelState extends State<NewAdminPanel> {
  final DatabaseReference _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://test-51a88-default-rtdb.firebaseio.com',
  ).ref();

  final AuthService _authService = AuthService();

  // Notification controllers
  final TextEditingController _notificationTitleController = TextEditingController();
  final TextEditingController _notificationBodyController = TextEditingController();
  final TextEditingController _notificationUrlController = TextEditingController();

  // Admin Card controllers
  final List<Map<String, TextEditingController>> _cardControllers = [
    {
      'title': TextEditingController(),
      'description': TextEditingController(),
      'imageUrl': TextEditingController(),
    },
    {
      'title': TextEditingController(),
      'description': TextEditingController(),
      'imageUrl': TextEditingController(),
    },
    {
      'title': TextEditingController(),
      'description': TextEditingController(),
      'imageUrl': TextEditingController(),
    },
  ];

  bool _isLoading = false;
  String? _notificationImageUrl;
  final List<String?> _cardImageUrls = [null, null, null];

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  @override
  void dispose() {
    _notificationTitleController.dispose();
    _notificationBodyController.dispose();
    _notificationUrlController.dispose();

    for (var cardController in _cardControllers) {
      cardController['title']?.dispose();
      cardController['description']?.dispose();
      cardController['imageUrl']?.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    setState(() => _isLoading = true);

    try {
      // Load admin cards data
      final cardsSnapshot = await _database.child('admin_cards').get();
      if (cardsSnapshot.exists && cardsSnapshot.value is Map) {
        final cardsData = cardsSnapshot.value as Map<dynamic, dynamic>;

        for (int i = 0; i < 3; i++) {
          final cardKey = 'card${i + 1}';
          if (cardsData.containsKey(cardKey)) {
            final cardData = cardsData[cardKey] as Map<dynamic, dynamic>;
            _cardControllers[i]['title']?.text = cardData['title'] ?? '';
            _cardControllers[i]['description']?.text = cardData['description'] ?? '';
            _cardControllers[i]['imageUrl']?.text = cardData['imageUrl'] ?? '';
            _cardImageUrls[i] = cardData['imageUrl'];
          }
        }
      }
    } catch (e) {
    }

    setState(() => _isLoading = false);
  }

  Future<String?> _uploadImage(File imageFile, String path) async {
    try {
      final storageRef = FirebaseStorage.instance.ref().child(path);
      final uploadTask = await storageRef.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      return null;
    }
  }

  Future<void> _pickAndUploadImage({bool isNotification = false, int? cardIndex}) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() => _isLoading = true);

      final file = File(pickedFile.path);
      final path = isNotification
          ? 'notifications/${DateTime.now().millisecondsSinceEpoch}.jpg'
          : 'admin_cards/card_${cardIndex! + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final downloadUrl = await _uploadImage(file, path);

      if (downloadUrl != null) {
        setState(() {
          if (isNotification) {
            _notificationImageUrl = downloadUrl;
          } else {
            _cardImageUrls[cardIndex!] = downloadUrl;
            _cardControllers[cardIndex]['imageUrl']?.text = downloadUrl;
          }
        });
      }

      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendNotification() async {
    if (_notificationTitleController.text.isEmpty ||
        _notificationBodyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill title and body')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final notificationData = {
        'title': _notificationTitleController.text,
        'body': _notificationBodyController.text,
        'imageUrl': _notificationImageUrl ?? '',
        'actionUrl': _notificationUrlController.text,
        'sentAt': DateTime.now().millisecondsSinceEpoch,
      };

      await _database.child('notifications').push().set(notificationData);

      _notificationTitleController.clear();
      _notificationBodyController.clear();
      _notificationUrlController.clear();
      _notificationImageUrl = null;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Notification sent successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error sending notification: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _saveAdminCard(int cardIndex) async {
    final titleController = _cardControllers[cardIndex]['title']!;
    final descriptionController = _cardControllers[cardIndex]['description']!;

    if (titleController.text.isEmpty || descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill title and description for Card ${cardIndex + 1}')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cardData = {
        'title': titleController.text,
        'description': descriptionController.text,
        'imageUrl': _cardImageUrls[cardIndex] ?? '',
        'isActive': true,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      await _database.child('admin_cards/card${cardIndex + 1}').set(cardData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Card ${cardIndex + 1} saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error saving Card ${cardIndex + 1}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _logout() async {
    try {
      await _authService.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Logged out successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Go back to home screen
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error logging out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 8),
              Text('Logout'),
            ],
          ),
          content: const Text('Are you sure you want to logout from admin panel?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _logout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2196F3),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _showLogoutDialog,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Admin Welcome Section
                  _buildAdminWelcomeSection(),
                  const SizedBox(height: 16),

                  // Notifications Section
                  _buildNotificationSection(),
                  const SizedBox(height: 32),

                  // Admin Cards Section
                  _buildAdminCardsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildAdminWelcomeSection() {
    final user = _authService.currentUser;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Row(
          children: [
            // Admin icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.admin_panel_settings,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),

            // Welcome text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome Admin!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? 'admin@app.com',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Logout button
            ElevatedButton.icon(
              onPressed: _showLogoutDialog,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF2196F3),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications, color: Color(0xFF2196F3), size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Send Notification',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _notificationTitleController,
              decoration: const InputDecoration(
                labelText: 'Notification Title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _notificationBodyController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notification Body',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.message),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _notificationUrlController,
              decoration: const InputDecoration(
                labelText: 'Action URL (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 12),

            // Image upload for notification
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickAndUploadImage(isNotification: true),
                  icon: const Icon(Icons.image),
                  label: const Text('Upload Image'),
                ),
                const SizedBox(width: 8),
                if (_notificationImageUrl != null)
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(_notificationImageUrl!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sendNotification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Send Notification',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminCardsSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.dashboard, color: Color(0xFF2196F3), size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Admin Cards for News Feed',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'These cards will appear in news feed in order: Card 1, Card 2, Card 3, then repeat',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Build 3 admin cards
            for (int i = 0; i < 3; i++) ...[
              _buildAdminCardEditor(i),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdminCardEditor(int cardIndex) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Admin Card ${cardIndex + 1}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _cardControllers[cardIndex]['title']!,
            decoration: const InputDecoration(
              labelText: 'Card Title',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.title),
            ),
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _cardControllers[cardIndex]['description']!,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Card Description',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description),
            ),
          ),
          const SizedBox(height: 8),

          // Image upload for card
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _pickAndUploadImage(cardIndex: cardIndex),
                icon: const Icon(Icons.image),
                label: const Text('Upload Image'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              if (_cardImageUrls[cardIndex] != null)
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(_cardImageUrls[cardIndex]!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _saveAdminCard(cardIndex),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
              ),
              child: Text('Save Card ${cardIndex + 1}'),
            ),
          ),
        ],
      ),
    );
  }
}