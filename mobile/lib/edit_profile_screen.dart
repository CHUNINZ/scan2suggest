import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'app_theme.dart';
import 'services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userProfile;
  final Function(Map<String, dynamic>) onProfileUpdated;

  const EditProfileScreen({
    super.key,
    required this.userProfile,
    required this.onProfileUpdated,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with TickerProviderStateMixin {
  
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _locationController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _bioFocus = FocusNode();
  final FocusNode _locationFocus = FocusNode();
  
  bool _isLoading = false;
  bool _hasUnsavedChanges = false;
  String? _profileImagePath;
  File? _newProfileImage;
  bool _imageChanged = false;
  final ImagePicker _imagePicker = ImagePicker();
  
  // Character limits
  static const int _maxNameLength = 50;
  static const int _maxBioLength = 150;
  static const int _maxLocationLength = 100;

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers with current profile data
    _nameController = TextEditingController(text: widget.userProfile['name'] ?? '');
    _bioController = TextEditingController(text: widget.userProfile['bio'] ?? '');
    _locationController = TextEditingController(text: widget.userProfile['location'] ?? '');
    _profileImagePath = widget.userProfile['profileImageUrl'];
    
    // Setup animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
    
    // Track changes
    _nameController.addListener(_onFieldChanged);
    _bioController.addListener(_onFieldChanged);
    _locationController.addListener(_onFieldChanged);
    
    // Start animation
    _fadeController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _nameFocus.dispose();
    _bioFocus.dispose();
    _locationFocus.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    final hasChanges = _nameController.text.trim() != (widget.userProfile['name'] ?? '') ||
        _bioController.text.trim() != (widget.userProfile['bio'] ?? '') ||
        _locationController.text.trim() != (widget.userProfile['location'] ?? '');
    
    if (hasChanges != _hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = hasChanges;
      });
    }
  }

  void _changeProfilePicture() {
    HapticFeedback.lightImpact();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: AppTheme.textDisabled,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Change Profile Picture',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPhotoOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromCamera();
                  },
                ),
                _buildPhotoOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                ),
                _buildPhotoOption(
                  icon: Icons.delete,
                  label: 'Remove',
                  color: AppTheme.error,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _profileImagePath = null;
                      _newProfileImage = null;
                      _imageChanged = true;
                      _hasUnsavedChanges = true;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _newProfileImage = File(image.path);
          _imageChanged = true;
          _hasUnsavedChanges = true;
        });
      }
    } catch (e) {
      _showSnackBar('Error accessing camera: ${e.toString()}');
    }
  }
  
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _newProfileImage = File(image.path);
          _imageChanged = true;
          _hasUnsavedChanges = true;
        });
      }
    } catch (e) {
      _showSnackBar('Error accessing gallery: ${e.toString()}');
    }
  }

  Widget _buildPhotoOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Discard Changes?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          content: const Text(
            'You have unsaved changes. Are you sure you want to discard them?',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Continue Editing',
                style: TextStyle(
                  color: AppTheme.primaryDarkGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Close edit screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: AppTheme.surfaceWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Discard',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    // Validate fields
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Please enter your name');
      _nameFocus.requestFocus();
      return;
    }

    if (_nameController.text.trim().length > _maxNameLength) {
      _showSnackBar('Name is too long (max $_maxNameLength characters)');
      _nameFocus.requestFocus();
      return;
    }

    if (_bioController.text.trim().length > _maxBioLength) {
      _showSnackBar('Bio is too long (max $_maxBioLength characters)');
      _bioFocus.requestFocus();
      return;
    }

    if (_locationController.text.trim().length > _maxLocationLength) {
      _showSnackBar('Location is too long (max $_maxLocationLength characters)');
      _locationFocus.requestFocus();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? newProfileImageUrl = _profileImagePath;
      
      // Upload new profile image if changed
      if (_imageChanged && _newProfileImage != null) {
        final uploadResponse = await ApiService.uploadProfileImage(_newProfileImage!);
        
        if (uploadResponse['success'] == true) {
          newProfileImageUrl = uploadResponse['profileImageUrl'];
        } else {
          throw Exception(uploadResponse['message'] ?? 'Failed to upload image');
        }
      } else if (_imageChanged && _newProfileImage == null) {
        // User removed profile image
        newProfileImageUrl = null;
      }
      
      // Update profile data
      final response = await ApiService.updateProfile(
        name: _nameController.text.trim(),
        bio: _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : null,
        location: _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
      );
      
      if (response['success'] == true && mounted) {
        final updatedProfile = {
          'name': _nameController.text.trim(),
          'bio': _bioController.text.trim(),
          'location': _locationController.text.trim(),
          'profileImageUrl': newProfileImageUrl,
        };

        widget.onProfileUpdated(updatedProfile);

        setState(() {
          _isLoading = false;
          _hasUnsavedChanges = false;
          _imageChanged = false;
        });

        // Show success message
        _showSnackBar('Profile updated successfully!', isSuccess: true);
        
        // Close the screen
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      } else {
        throw Exception(response['message'] ?? 'Failed to update profile');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        _showSnackBar('Error: ${e.toString().replaceAll('Exception: ', '')}');
      }
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess ? AppTheme.success : AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildCharacterCounter(int currentLength, int maxLength) {
    final isNearLimit = currentLength > maxLength * 0.8;
    final isOverLimit = currentLength > maxLength;
    
    return Text(
      '$currentLength/$maxLength',
      style: TextStyle(
        fontSize: 12,
        color: isOverLimit 
            ? AppTheme.error 
            : isNearLimit 
                ? AppTheme.warning 
                : AppTheme.textSecondary,
        fontWeight: isOverLimit ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    String? hintText,
    int? maxLength,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: focusNode.hasFocus ? [
              BoxShadow(
                color: AppTheme.primaryDarkGreen.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ] : [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            maxLength: maxLength,
            maxLines: maxLines,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              prefixIcon: Icon(
                icon,
                color: focusNode.hasFocus 
                    ? AppTheme.primaryDarkGreen 
                    : AppTheme.textSecondary,
                size: 20,
              ),
              counterText: '', // Hide default counter
              filled: true,
              fillColor: AppTheme.surfaceWhite,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppTheme.textDisabled),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: (maxLength != null && controller.text.length > maxLength) 
                      ? AppTheme.error 
                      : AppTheme.textDisabled,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: (maxLength != null && controller.text.length > maxLength) 
                      ? AppTheme.error 
                      : AppTheme.primaryDarkGreen,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.error, width: 2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.error, width: 2),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: maxLines > 1 ? 16 : 18,
              ),
            ),
          ),
        ),
        if (maxLength != null) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (controller.text.length > maxLength)
                Text(
                  'Exceeds character limit',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                )
              else
                const SizedBox.shrink(),
              _buildCharacterCounter(controller.text.length, maxLength),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundOffWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textPrimary),
          onPressed: () {
            if (_hasUnsavedChanges) {
              _showDiscardDialog();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _hasUnsavedChanges && !_isLoading ? _saveProfile : null,
            child: Text(
              'Save',
              style: TextStyle(
                color: _hasUnsavedChanges && !_isLoading 
                    ? AppTheme.primaryDarkGreen 
                    : AppTheme.textDisabled,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Picture Section
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryDarkGreen.withOpacity(0.8),
                                AppTheme.secondaryLightGreen,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryDarkGreen.withOpacity(0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: _profileImagePath != null
                              ? ClipOval(
                                  child: Image.network(
                                    _profileImagePath!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Center(
                                        child: Text(
                                          _nameController.text.isNotEmpty 
                                              ? _nameController.text[0].toUpperCase()
                                              : 'U',
                                          style: const TextStyle(
                                            color: AppTheme.surfaceWhite,
                                            fontSize: 40,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    _nameController.text.isNotEmpty 
                                        ? _nameController.text[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      color: AppTheme.surfaceWhite,
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _changeProfilePicture,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryDarkGreen,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.surfaceWhite,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: AppTheme.surfaceWhite,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tap to change profile picture',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Personal Information Section
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryDarkGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.person,
                            color: AppTheme.primaryDarkGreen,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Personal Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Name Field
                    _buildFormField(
                      label: 'Full Name',
                      controller: _nameController,
                      focusNode: _nameFocus,
                      icon: Icons.person_outline,
                      hintText: 'Enter your full name',
                      maxLength: _maxNameLength,
                      textCapitalization: TextCapitalization.words,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Bio Field
                    _buildFormField(
                      label: 'Bio',
                      controller: _bioController,
                      focusNode: _bioFocus,
                      icon: Icons.description_outlined,
                      hintText: 'Tell us about yourself and your cooking style...',
                      maxLength: _maxBioLength,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Location Field
                    _buildFormField(
                      label: 'Location',
                      controller: _locationController,
                      focusNode: _locationFocus,
                      icon: Icons.location_on_outlined,
                      hintText: 'City, Country',
                      maxLength: _maxLocationLength,
                      textCapitalization: TextCapitalization.words,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Additional Information Section
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.info_outline,
                            color: Colors.blue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Profile Tips',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    _buildTipItem(
                      icon: Icons.lightbulb_outline,
                      text: 'Add a friendly bio to connect with other food lovers',
                      color: Colors.amber,
                    ),
                    const SizedBox(height: 12),
                    _buildTipItem(
                      icon: Icons.location_on_outlined,
                      text: 'Share your location to discover local recipes',
                      color: Colors.green,
                    ),
                    const SizedBox(height: 12),
                    _buildTipItem(
                      icon: Icons.photo_camera_outlined,
                      text: 'A profile picture helps build trust in the community',
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _hasUnsavedChanges && !_isLoading ? _saveProfile : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasUnsavedChanges && !_isLoading 
                        ? AppTheme.primaryDarkGreen 
                        : AppTheme.textDisabled,
                    foregroundColor: AppTheme.surfaceWhite,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: _hasUnsavedChanges ? 4 : 0,
                    shadowColor: AppTheme.primaryDarkGreen.withOpacity(0.3),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.surfaceWhite),
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipItem({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: color,
          size: 18,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}