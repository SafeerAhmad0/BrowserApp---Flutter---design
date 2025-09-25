import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';

class NotificationSlider extends StatefulWidget {
  const NotificationSlider({super.key});

  @override
  State<NotificationSlider> createState() => _NotificationSliderState();
}

class _NotificationSliderState extends State<NotificationSlider> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    try {
      final db = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://test-51a88-default-rtdb.firebaseio.com',
      );
      final ref = db.ref('notifications');
      final snapshot = await ref.get();

      final List<Map<String, dynamic>> items = [];
      if (snapshot.exists && snapshot.value is Map) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          if (value is Map) {
            final map = Map<String, dynamic>.from(value as Map);
            map['id'] = key;
            items.add(map);
          }
        });
        // Sort latest first by sentAt (millis)
        items.sort((a, b) => ((b['sentAt'] ?? 0) as int).compareTo((a['sentAt'] ?? 0) as int));
      }

      setState(() {
        _notifications = items.take(5).toList(); // Take only 5 most recent
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getTimeAgo(int? millis) {
    if (millis == null) return 'Just now';

    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _handleNotificationTap(String? actionUrl) {
    if (actionUrl != null && actionUrl.isNotEmpty) {
      // TODO: Navigate to URL or handle action
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening: $actionUrl'),
          backgroundColor: const Color(0xFF667eea),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Widget _buildSliderImage(String imageBase64) {
    try {
      // Clean the base64 string if it contains data URL prefix
      String cleanBase64 = imageBase64;
      if (imageBase64.contains(',')) {
        cleanBase64 = imageBase64.split(',').last;
      }

      return Image.memory(
        base64Decode(cleanBase64),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
          );
        },
      );
    } catch (e) {
      return Container(
        color: Colors.grey[300],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 120,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF667eea),
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return const SizedBox.shrink(); // Don't show anything if no notifications
    }

    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: _notifications.length,
            itemBuilder: (context, index) {
              final notification = _notifications[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                child: _buildNotificationCard(notification),
              );
            },
          ),
          
          // Page indicators
          if (_notifications.length > 1)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _notifications.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == _currentIndex
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final title = notification['title'] ?? 'Announcement';
    final body = notification['body'] ?? '';
    final imageBase64 = notification['imageBase64'] as String?;
    final actionUrl = notification['actionUrl'] as String?;
    final sentAt = notification['sentAt'] is int ? notification['sentAt'] as int : null;
    final hasImage = imageBase64 != null && imageBase64.isNotEmpty;

    return GestureDetector(
      onTap: () => _handleNotificationTap(actionUrl),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              offset: const Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background image if available
            if (hasImage)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _buildSliderImage(imageBase64!),
                ),
              ),

            // Overlay
            if (hasImage)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),
            
            // Content
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with admin badge and time
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.admin_panel_settings,
                                size: 14,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Admin',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _getTimeAgo(sentAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Title
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 6),
                    
                    // Body
                    Expanded(
                      child: Text(
                        body,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    // Action indicator
                    if (actionUrl != null && actionUrl.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(
                              Icons.touch_app,
                              size: 16,
                              color: Colors.white.withOpacity(0.8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Tap to open',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}