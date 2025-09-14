import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:image/image.dart' as img;

class NotificationDialog extends StatefulWidget {
  final Map<String, dynamic>? editingNotification;

  const NotificationDialog({super.key, this.editingNotification});

  @override
  State<NotificationDialog> createState() => _NotificationDialogState();
}

class _NotificationDialogState extends State<NotificationDialog> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _actionUrlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  File? _selectedImage;
  String? _existingImageUrl;
  final ImagePicker _picker = ImagePicker();
  double _uploadProgress = 0.0;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.editingNotification != null) {
      _isEditing = true;
      _titleController.text = widget.editingNotification!['title'] ?? '';
      _bodyController.text = widget.editingNotification!['body'] ?? '';
      _actionUrlController.text = widget.editingNotification!['actionUrl'] ?? '';
      _existingImageUrl = widget.editingNotification!['imageBase64'];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _actionUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _showSnackBar('Error picking image: $e', Colors.red);
    }
  }

  Future<String?> _processImageAsBase64() async {
    if (_selectedImage == null) return null;

    try {
      print('Starting image compression for database storage...');

      // Read and compress image
      final originalBytes = await _selectedImage!.readAsBytes();
      final decoded = img.decodeImage(originalBytes);
      if (decoded == null) throw Exception('Could not decode image');

      // Create compressed image for database storage (smaller size)
      final compressed = img.copyResize(decoded, width: decoded.width > 800 ? 800 : decoded.width);
      final compressedBytes = Uint8List.fromList(img.encodeJpg(compressed, quality: 60));

      // Convert to base64 for database storage
      final imageBase64 = base64Encode(compressedBytes);

      print('Image compressed and converted to base64 successfully');
      return imageBase64;
    } catch (e) {
      print('Image processing error: $e');
      _showSnackBar('Error processing image: $e', Colors.red);
      return null;
    } finally {
      if (mounted) setState(() => _uploadProgress = 0.0);
    }
  }

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String? imageBase64;
      if (_selectedImage != null) {
        imageBase64 = await _processImageAsBase64();
        if (imageBase64 == null) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      } else if (_isEditing && _existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
        // Keep existing image if no new image selected
        imageBase64 = _existingImageUrl;
      }

      final db = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://test-51a88-default-rtdb.firebaseio.com',
      );
      final ref = db.ref('notifications').push();
      await ref.set({
        'title': _titleController.text.trim(),
        'body': _bodyController.text.trim(),
        'actionUrl': _actionUrlController.text.trim().isEmpty
            ? null
            : _actionUrlController.text.trim(),
        'imageBase64': imageBase64,
        'sentAt': ServerValue.timestamp,
        'sentBy': 'admin',
      }).timeout(const Duration(seconds: 10));

      if (mounted) {
        Navigator.of(context).pop();
        _showSnackBar('Notification sent successfully!', Colors.green);
      }
    } catch (e) {
      _showSnackBar('Error sending notification: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2196F3).withOpacity(0.3),
                    offset: const Offset(0, 4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.notifications_active, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing ? 'Edit Notification' : 'Create Notification',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Send to all app users instantly',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title field
                      const Text(
                        'Title *',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          hintText: 'Enter notification title',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.title),
                        ),
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Title is required';
                          }
                          return null;
                        },
                        maxLength: 50,
                      ),

                      const SizedBox(height: 16),

                      // Body field
                      const Text(
                        'Message *',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _bodyController,
                        decoration: InputDecoration(
                          hintText: 'Enter notification message',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.message),
                        ),
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'Message is required';
                          }
                          return null;
                        },
                        maxLines: 3,
                        maxLength: 200,
                      ),

                      const SizedBox(height: 16),

                      // Action URL field
                      const Text(
                        'Action URL (Optional)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _actionUrlController,
                        decoration: InputDecoration(
                          hintText: 'https://example.com',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.link),
                        ),
                        keyboardType: TextInputType.url,
                      ),

                      const SizedBox(height: 16),

                      // Image section
                      const Text(
                        'Image (Optional)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Show existing image if editing
                      if (_isEditing && _existingImageUrl != null && _existingImageUrl!.isNotEmpty && _selectedImage == null) ...[
                        Container(
                          height: 120,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  base64Decode(_existingImageUrl!),
                                  height: 120,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _existingImageUrl = null;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Show selected new image
                      if (_selectedImage != null) ...[
                        Container(
                          height: 100,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  _selectedImage!,
                                  height: 100,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedImage = null;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      
                      OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image),
                        label: Text(_selectedImage != null
                          ? 'Change Image'
                          : (_isEditing && _existingImageUrl != null && _existingImageUrl!.isNotEmpty)
                            ? 'Replace Image'
                            : 'Add Image'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      if (_uploadProgress > 0 && _uploadProgress < 1.0) ...[
                        LinearProgressIndicator(
                          value: _uploadProgress,
                          backgroundColor: Colors.grey[300],
                          color: const Color(0xFF667eea),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Send button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _sendNotification,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF667eea),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? LoadingAnimationWidget.staggeredDotsWave(
                                  color: Colors.white,
                                  size: 20,
                                )
                              : const Text(
                                  'Send Notification',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}