import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../services/admin_card_service.dart';
import '../../components/admin_card_widget.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/auth_service.dart';
import '../../services/proxy_service.dart';
import 'dart:typed_data';

class NewAdminPanel extends StatefulWidget {
  const NewAdminPanel({super.key});

  @override
  State<NewAdminPanel> createState() => _NewAdminPanelState();
}

class _NewAdminPanelState extends State<NewAdminPanel> {
  final AuthService _authService = AuthService();

  // Notification controllers
  final TextEditingController _notificationTitleController = TextEditingController();
  final TextEditingController _notificationBodyController = TextEditingController();
  final TextEditingController _notificationUrlController = TextEditingController();

  // Admin Card controllers
  final List<Map<String, TextEditingController>> _cardControllers = [
    {
      'title': TextEditingController(),
      'url': TextEditingController(),
      'imageUrl': TextEditingController(),
    },
    {
      'title': TextEditingController(),
      'url': TextEditingController(),
      'imageUrl': TextEditingController(),
    },
    {
      'title': TextEditingController(),
      'url': TextEditingController(),
      'imageUrl': TextEditingController(),
    },
  ];

  bool _isLoading = false;
  double _uploadProgress = 0.0;
  bool _isUploading = false;
  String _uploadStatus = '';
  int? _currentUploadingCard;
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
      cardController['url']?.dispose();
      cardController['imageUrl']?.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    setState(() => _isLoading = true);

    try {
      // Load admin cards data using new service
      await AdminCardService.loadAdminCards();
      final adminCards = AdminCardService.adminCards;

      for (int i = 0; i < 3; i++) {
        if (i < adminCards.length) {
          final adminCard = adminCards[i];
          _cardControllers[i]['title']?.text = adminCard.title;
          _cardControllers[i]['url']?.text = adminCard.url;
          _cardControllers[i]['imageUrl']?.text = adminCard.imageUrl;
          _cardImageUrls[i] = adminCard.imageUrl;
        }
      }
    } catch (e) {
      print('Error loading admin cards: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<String?> _uploadImageToDatabase(File imageFile, String path, {Function(double)? onProgress}) async {
    try {
      print('🔥 [IMAGE UPLOAD] Starting Base64 conversion and upload to: $path');

      // Read file as bytes
      final bytes = await imageFile.readAsBytes();
      final fileSizeKB = (bytes.length / 1024).toStringAsFixed(2);
      print('📦 [IMAGE UPLOAD] Original file size: $fileSizeKB KB');

      // Simulate progress for reading
      if (onProgress != null) onProgress(0.2);

      // Convert to Base64
      print('🔄 [IMAGE UPLOAD] Converting to Base64...');
      final base64String = base64Encode(bytes);
      final base64SizeKB = (base64String.length / 1024).toStringAsFixed(2);
      print('📊 [IMAGE UPLOAD] Base64 size: $base64SizeKB KB');

      // Simulate progress for conversion
      if (onProgress != null) onProgress(0.5);

      // Create data URL format (so it can be used directly in Image.network)
      final imageDataUrl = 'data:image/jpeg;base64,$base64String';

      // Get database reference
      final database = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://bluex-browser-default-rtdb.firebaseio.com',
      ).ref();

      print('⬆️ [IMAGE UPLOAD] Uploading to Realtime Database at: $path');

      // Upload to Realtime Database
      await database.child(path).set({
        'imageData': imageDataUrl,
        'uploadedAt': DateTime.now().millisecondsSinceEpoch,
        'sizeKB': base64SizeKB,
      });

      // Simulate progress for upload
      if (onProgress != null) onProgress(0.9);

      print('✅ [IMAGE UPLOAD] Upload complete!');

      // Final progress
      if (onProgress != null) onProgress(1.0);

      return imageDataUrl;
    } catch (e, stackTrace) {
      print('❌ [IMAGE UPLOAD] Upload failed with error: $e');
      print('📚 [IMAGE UPLOAD] Stack trace: $stackTrace');

      // Show detailed error in UI
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      return null;
    }
  }

  Future<void> _pickAndUploadImage({bool isNotification = false, int? cardIndex}) async {
    try {
      print('🖼️ [IMAGE PICKER] Starting image picker...');
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        print('⚠️ [IMAGE PICKER] No image selected');
        return;
      }

      print('✅ [IMAGE PICKER] Image selected: ${pickedFile.path}');

      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
        _uploadStatus = 'Preparing upload...';
        _currentUploadingCard = cardIndex;
      });

      final file = File(pickedFile.path);

      // Verify file exists
      if (!await file.exists()) {
        throw Exception('Selected file does not exist');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = isNotification
          ? 'images/notifications/notification_$timestamp'
          : 'images/admin_cards/card_${cardIndex! + 1}_$timestamp';

      print('📂 [UPLOAD] Target database path: $path');

      setState(() => _uploadStatus = 'Converting and uploading image...');

      final imageDataUrl = await _uploadImageToDatabase(
        file,
        path,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress = progress;
              if (progress < 0.3) {
                _uploadStatus = 'Reading image... ${(progress * 100).toInt()}%';
              } else if (progress < 0.7) {
                _uploadStatus = 'Converting... ${(progress * 100).toInt()}%';
              } else {
                _uploadStatus = 'Uploading... ${(progress * 100).toInt()}%';
              }
            });
          }
        },
      );

      if (imageDataUrl != null && mounted) {
        setState(() {
          if (isNotification) {
            _notificationImageUrl = imageDataUrl;
          } else {
            _cardImageUrls[cardIndex!] = imageDataUrl;
            _cardControllers[cardIndex]['imageUrl']?.text = imageDataUrl;
          }
          _uploadStatus = 'Upload completed!';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Image uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Auto-clear progress after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _isUploading = false;
              _uploadProgress = 0.0;
              _uploadStatus = '';
              _currentUploadingCard = null;
            });
          }
        });
      } else if (mounted) {
        setState(() {
          _uploadStatus = 'Upload failed!';
          _isUploading = false;
          _currentUploadingCard = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Image upload failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ [PICK AND UPLOAD] Error: $e');
      print('📚 [PICK AND UPLOAD] Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
          _uploadStatus = '';
          _currentUploadingCard = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
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

      // Create database connection only for notifications (Realtime Database)
      final database = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://bluex-browser-default-rtdb.firebaseio.com',
      ).ref();

      await database.child('notifications').push().set(notificationData);

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
    final urlController = _cardControllers[cardIndex]['url']!;

    if (titleController.text.isEmpty || urlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill title and URL for Card ${cardIndex + 1}')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Create AdminCard object
      final adminCard = AdminCard(
        title: titleController.text,
        url: urlController.text,
        imageUrl: _cardImageUrls[cardIndex] ?? '',
        isActive: true,
        updatedAt: DateTime.now(),
      );

      // Save using the new AdminCardService
      await AdminCardService.saveAdminCard(cardIndex + 1, adminCard);

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

  void _editCard(int cardIndex) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.edit, color: Color(0xFF2196F3)),
              const SizedBox(width: 8),
              Text('Edit Card ${cardIndex + 1}'),
            ],
          ),
          content: const Text('The card fields are already editable below. Make your changes and click Save to update.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _clearCard(int cardIndex) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text('Clear Card?'),
            ],
          ),
          content: Text('Are you sure you want to clear all data from Card ${cardIndex + 1}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Delete from database first
                try {
                  await AdminCardService.deleteAdminCard(cardIndex + 1);

                  setState(() {
                    _cardControllers[cardIndex]['title']?.clear();
                    _cardControllers[cardIndex]['url']?.clear();
                    _cardControllers[cardIndex]['imageUrl']?.clear();
                    _cardImageUrls[cardIndex] = null;
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🗑️ Card ${cardIndex + 1} cleared successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Error clearing Card ${cardIndex + 1}: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );
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
                  const SizedBox(height: 32),

                  // Proxy Configuration Section
                  _buildProxyConfigSection(),
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
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        base64Decode(_notificationImageUrl!.split(',')[1]),
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
              'These cards will appear in news feed in pattern: 3 news, Card 1, 4 news, Card 2, 5 news, Card 3, then repeat',
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
    final isCurrentlyUploading = _isUploading && _currentUploadingCard == cardIndex;
    final hasData = _cardControllers[cardIndex]['title']!.text.isNotEmpty ||
                    _cardControllers[cardIndex]['url']!.text.isNotEmpty ||
                    _cardImageUrls[cardIndex] != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Admin Card ${cardIndex + 1}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (hasData)
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _editCard(cardIndex),
                      icon: const Icon(Icons.edit, color: Color(0xFF2196F3)),
                      tooltip: 'Edit Card ${cardIndex + 1}',
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3).withOpacity(0.1),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _clearCard(cardIndex),
                      icon: const Icon(Icons.clear, color: Colors.red),
                      tooltip: 'Clear Card ${cardIndex + 1}',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.1),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
            ],
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
            controller: _cardControllers[cardIndex]['url']!,
            maxLines: 1,
            decoration: const InputDecoration(
              labelText: 'Card URL',
              hintText: 'https://example.com',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link),
            ),
          ),
          const SizedBox(height: 8),

          // Image upload for card
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _isUploading ? null : () => _pickAndUploadImage(cardIndex: cardIndex),
                icon: const Icon(Icons.image),
                label: Text(isCurrentlyUploading ? 'Uploading...' : 'Upload Image'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade600,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade400,
                ),
              ),
              const SizedBox(width: 8),
              if (_cardImageUrls[cardIndex] != null)
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _cardImageUrls[cardIndex]!.startsWith('data:image')
                        ? Image.memory(
                            base64Decode(_cardImageUrls[cardIndex]!.split(',')[1]),
                            fit: BoxFit.cover,
                          )
                        : Image.network(
                            _cardImageUrls[cardIndex]!,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Beautiful Progress Bar
          if (isCurrentlyUploading) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.blue.shade100],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade300, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cloud_upload, color: Colors.blue.shade700, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _uploadStatus,
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        '${(_uploadProgress * 100).toInt()}%',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _uploadProgress,
                      backgroundColor: Colors.blue.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(_uploadProgress * 100).toStringAsFixed(1)}% completed',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

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

  Widget _buildProxyConfigSection() {
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
                Icon(Icons.vpn_lock, color: Colors.orange[700], size: 24),
                const SizedBox(width: 8),
                Text(
                  'Proxy Configuration',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Proxy Status
            FutureBuilder<bool>(
              future: _getProxyStatus(),
              builder: (context, snapshot) {
                final isEnabled = snapshot.data ?? false;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isEnabled ? Colors.green[50] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isEnabled ? Colors.green : Colors.grey,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isEnabled ? Icons.check_circle : Icons.cancel,
                        color: isEnabled ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEnabled ? 'Proxy Enabled' : 'Proxy Disabled',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isEnabled ? Colors.green[700] : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Proxy Servers
            Text(
              'Available VPS Servers:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),

            ...ProxyService().servers.map((server) => _buildServerCard(server)),

            const SizedBox(height: 16),

            // Control Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _toggleProxy,
                    icon: const Icon(Icons.power_settings_new),
                    label: const Text('Toggle Proxy'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _testProxyConnection,
                    icon: const Icon(Icons.speed),
                    label: const Text('Test Connection'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerCard(ProxyServer server) {
    return FutureBuilder<ProxyServer?>(
      future: _getSelectedServer(),
      builder: (context, snapshot) {
        final selectedServer = snapshot.data;
        final isSelected = selectedServer?.host == server.host;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: isSelected ? 3 : 1,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isSelected ? Colors.green : Colors.grey[300],
              child: Icon(
                Icons.dns,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
            ),
            title: Text(
              server.name,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${server.host}:${server.port}'),
                Text(
                  server.location,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            trailing: isSelected
                ? Icon(Icons.check_circle, color: Colors.green)
                : null,
            onTap: () => _selectServer(server),
          ),
        );
      },
    );
  }

  Future<bool> _getProxyStatus() async {
    await ProxyService().initialize();
    return ProxyService().isProxyEnabled;
  }

  Future<ProxyServer?> _getSelectedServer() async {
    await ProxyService().initialize();
    return ProxyService().selectedServer;
  }

  Future<void> _toggleProxy() async {
    try {
      await ProxyService().initialize();
      final currentStatus = ProxyService().isProxyEnabled;
      await ProxyService().setProxyEnabled(!currentStatus);

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !currentStatus ? '✅ Proxy Enabled' : '❌ Proxy Disabled',
          ),
          backgroundColor: !currentStatus ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error toggling proxy: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _selectServer(ProxyServer server) async {
    try {
      await ProxyService().selectServer(server);
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Selected ${server.name}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error selecting server: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _testProxyConnection() async {
    final proxyService = ProxyService();
    await proxyService.initialize();

    final selectedServer = proxyService.selectedServer;
    if (selectedServer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Please select a server first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final isConnected = await proxyService.testProxyConnection(selectedServer);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isConnected
                ? '✅ ${selectedServer.name} is working'
                : '❌ ${selectedServer.name} connection failed',
          ),
          backgroundColor: isConnected ? Colors.green : Colors.red,
        ),
      );

      // Show current IP for testing
      if (isConnected) {
        final currentIP = await proxyService.getCurrentIP();
        if (currentIP != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🌐 Current IP: $currentIP'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error testing connection: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isLoading = false);
  }
}