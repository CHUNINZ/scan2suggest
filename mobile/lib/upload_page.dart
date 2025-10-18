import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'camera_scan_page.dart';
import 'app_theme.dart';
import 'services/api_service.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> with TickerProviderStateMixin {
  int _currentStep = 0;
  final PageController _pageController = PageController();
  
  String _foodName = '';
  String _description = '';
  String _cookingDuration = '30';
  double _durationSliderValue = 2.0; // Index for slider (0-4 for 5 options)
  final List<String> _ingredients = [];
  final List<String> _steps = [];
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  
  // Form validation
  bool _showValidationErrors = false;
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  // Show success overlay
  bool _isSuccessOverlayVisible = false;
  
  // Animation controllers for success overlay
  late AnimationController _overlayController;
  late AnimationController _successAnimationController;
  late AnimationController _celebrationController;
  late AnimationController _shareButtonController;
  
  late Animation<double> _overlayFadeAnimation;
  late Animation<Offset> _modalSlideAnimation;
  late Animation<double> _successScaleAnimation;
  late Animation<double> _celebrationPulseAnimation;
  late Animation<double> _shareButtonScaleAnimation;

  // Duration options with slider mapping
  final List<Map<String, dynamic>> _durationOptions = [
    {'value': '10', 'label': '<10', 'description': 'Quick', 'minutes': 10},
    {'value': '15', 'label': '15', 'description': 'Fast', 'minutes': 15},
    {'value': '30', 'label': '30', 'description': 'Moderate', 'minutes': 30},
    {'value': '45', 'label': '45', 'description': 'Standard', 'minutes': 45},
    {'value': '60', 'label': '>60', 'description': 'Traditional', 'minutes': 60},
  ];

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _overlayController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _successAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _shareButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    // Setup animations
    _overlayFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 0.7,
    ).animate(CurvedAnimation(
      parent: _overlayController,
      curve: Curves.easeInOut,
    ));
    
    _modalSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _overlayController,
      curve: Curves.easeOutCubic,
    ));
    
    _successScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _successAnimationController,
      curve: Curves.elasticOut,
    ));
    
    _celebrationPulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _celebrationController,
      curve: Curves.easeInOut,
    ));

    _shareButtonScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _shareButtonController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _overlayController.dispose();
    _successAnimationController.dispose();
    _celebrationController.dispose();
    _shareButtonController.dispose();
    _pageController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _selectScanOption(String option) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScanPage(scanType: option),
      ),
    );
  }

  void _updateDurationFromSlider(double value) {
    setState(() {
      _durationSliderValue = value;
      int index = value.round().clamp(0, _durationOptions.length - 1);
      _cookingDuration = _durationOptions[index]['value'];
    });
  }

  String? _validateStep1() {
    if (_foodName.trim().isEmpty) {
      return 'Please enter a recipe name';
    }
    if (_foodName.trim().length < 3) {
      return 'Recipe name must be at least 3 characters';
    }
    if (_description.trim().isEmpty) {
      return 'Please enter a description';
    }
    if (_description.trim().length < 10) {
      return 'Description must be at least 10 characters (current: ${_description.trim().length})';
    }
    return null;
  }

  String? _validateStep2() {
    if (_ingredients.isEmpty) {
      return 'Please add at least one ingredient';
    }
    if (_steps.isEmpty) {
      return 'Please add at least one cooking step';
    }
    return null;
  }

  bool _canProceedToStep2() {
    return _validateStep1() == null;
  }

  bool _canSubmitRecipe() {
    return _validateStep1() == null && _validateStep2() == null;
  }

  Future<void> _submitRecipe() async {
    setState(() {
      _showValidationErrors = true;
    });

    // Validate Step 1
    final step1Error = _validateStep1();
    if (step1Error != null) {
      _showErrorSnackbar(step1Error);
      // Go back to step 1
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep = 0);
      return;
    }

    // Validate Step 2
    final step2Error = _validateStep2();
    if (step2Error != null) {
      _showErrorSnackbar(step2Error);
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          color: AppTheme.primaryDarkGreen,
        ),
      ),
    );

    try {
      // Prepare ingredients list (match backend schema)
      final ingredientsList = _ingredients.map((ing) => {
        'name': ing,
        'amount': '1', // Required field in backend
        'unit': 'piece',
      }).toList();

      // Prepare instructions list (match backend schema)
      final instructionsList = _steps.asMap().entries.map((entry) => {
        'step': entry.key + 1, // Required field in backend (number)
        'instruction': entry.value, // Required field in backend (string)
      }).toList();

      // Calculate prep and cook time (simple split for now)
      final totalDuration = int.parse(_cookingDuration);
      final prepTime = (totalDuration * 0.3).round();
      final cookTime = totalDuration - prepTime;

      // Submit recipe
      final result = await ApiService.createRecipe(
        title: _foodName.trim(),
        description: _description.trim(),
        category: 'main_course', // Default category
        difficulty: 'medium', // Default difficulty
        prepTime: prepTime,
        cookTime: cookTime,
        servings: 4, // Default servings
        ingredients: ingredientsList,
        instructions: instructionsList,
        tags: ['filipino', 'homemade'],
        images: _selectedImage != null ? [_selectedImage!] : null,
      );

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (result['success'] == true) {
        _showSuccessOverlay();
      } else {
        _showErrorSnackbar(result['message'] ?? 'Failed to upload recipe');
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      _showErrorSnackbar('Error uploading recipe: $e');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showSuccessOverlay() {
    setState(() {
      _isSuccessOverlayVisible = true;
    });
    
    _overlayController.forward();
    
    // Start success animations with delay
    Future.delayed(const Duration(milliseconds: 300), () {
      _successAnimationController.forward();
      _celebrationController.repeat(reverse: true);
    });
    
    HapticFeedback.heavyImpact();
  }

  void _hideSuccessOverlay() {
    _overlayController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isSuccessOverlayVisible = false;
        });
        _successAnimationController.reset();
        _celebrationController.reset();
      }
    });
  }

  void _resetForm() {
    setState(() {
      _currentStep = 0;
      _foodName = '';
      _description = '';
      _cookingDuration = '30';
      _durationSliderValue = 2.0;
      _ingredients.clear();
      _steps.clear();
      _selectedImage = null;
      _showValidationErrors = false;
      _nameController.clear();
      _descriptionController.clear();
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      _showErrorSnackbar('Failed to pick image: $e');
    }
  }

  void _uploadAnother() {
    HapticFeedback.mediumImpact();
    
    // Hide overlay first
    _hideSuccessOverlay();
    
    // Reset form and navigate back to step 1
    Future.delayed(const Duration(milliseconds: 300), () {
      _resetForm();
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      
      // Show feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.upload, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Ready for your next recipe!'),
            ],
          ),
          backgroundColor: AppTheme.primaryDarkGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  void _navigateToHome() {
    HapticFeedback.mediumImpact();
    
    // Hide overlay first with animation
    _overlayController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isSuccessOverlayVisible = false;
        });
        _successAnimationController.reset();
        _celebrationController.reset();
        
        // Show brief success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Recipe saved successfully!'),
              ],
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Navigate to home and clear upload stack
        // This will pop all routes until we reach the first route (MainNavigationController)
        // which contains the home page
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            // Reset the form state
            _resetForm();
            
            // Pop until we reach the main navigation (home)
            Navigator.of(context).popUntil((route) {
              // Check if this is the first route (main navigation)
              return route.isFirst;
            });
          }
        });
      }
    });
  }

  void _shareRecipe() {
    HapticFeedback.lightImpact();
    _shareButtonController.forward().then((_) {
      _shareButtonController.reverse();
    });

    // Create share content
    final shareContent = '''
🍽️ Check out my new Filipino recipe: ${_foodName.isEmpty ? 'My Special Dish' : _foodName}

${_description.isEmpty ? 'A delicious Filipino dish made with love!' : _description}

⏰ Cooking time: $_cookingDuration minutes
🥘 Ingredients: ${_ingredients.isEmpty ? 'Traditional Filipino ingredients' : _ingredients.join(', ')}

Made with Start Cooking App 🇵🇭
''';

    // Show share options modal
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
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
              'Share Your Recipe',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Spread the love of Filipino cuisine!',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            
            // Share options
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildShareOption(Icons.message, 'Messages', AppTheme.primaryDarkGreen),
                  _buildShareOption(Icons.email, 'Email', Colors.blue),
                  _buildShareOption(Icons.link, 'Copy Link', Colors.orange),
                  _buildShareOption(Icons.more_horiz, 'More', AppTheme.textSecondary),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recipe shared via $label!'),
            backgroundColor: color,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      },
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
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundOffWhite,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(),
                _buildStep2(),
              ],
            ),
            
            // Success overlay
            if (_isSuccessOverlayVisible) _buildEnhancedSuccessOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressIndicator(0),
          const SizedBox(height: 32),
          
          const Text(
            'Upload Filipino Recipe - Step 1',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add basic information about your dish',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          
          // Photo upload section
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: AppTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedImage != null 
                      ? AppTheme.primaryDarkGreen 
                      : AppTheme.textDisabled,
                  width: _selectedImage != null ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _selectedImage != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            _selectedImage!,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _selectedImage = null;
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, size: 50, color: AppTheme.textSecondary),
                        SizedBox(height: 16),
                        Text(
                          'Add Filipino Dish Photo',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Tap to select from gallery',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Dish name field
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Filipino Dish Name *',
              hintText: 'e.g., Adobo, Sinigang, Kare-Kare',
              helperText: 'Minimum 3 characters',
              errorText: _showValidationErrors && _foodName.trim().length < 3 && _foodName.isNotEmpty
                  ? 'Name must be at least 3 characters'
                  : null,
              prefixIcon: const Icon(Icons.restaurant, color: AppTheme.primaryDarkGreen),
              suffixIcon: _foodName.trim().length >= 3
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
              filled: true,
              fillColor: AppTheme.surfaceWhite,
            ),
            onChanged: (value) {
              setState(() {
                _foodName = value;
              });
            },
          ),
          const SizedBox(height: 16),
          
          // Description field
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Description *',
              hintText: 'Tell us about this Filipino dish and its origins...',
              helperText: 'Minimum 10 characters (${_description.trim().length}/10)',
              helperStyle: TextStyle(
                color: _description.trim().length >= 10 ? Colors.green : AppTheme.textSecondary,
              ),
              errorText: _showValidationErrors && _description.trim().length < 10 && _description.isNotEmpty
                  ? 'Description must be at least 10 characters'
                  : null,
              prefixIcon: const Icon(Icons.description, color: AppTheme.primaryDarkGreen),
              suffixIcon: _description.trim().length >= 10
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
              filled: true,
              fillColor: AppTheme.surfaceWhite,
            ),
            onChanged: (value) {
              setState(() {
                _description = value;
              });
            },
          ),
          const SizedBox(height: 32),
          
          // Cooking Duration Section with Slider
          _buildCookingDurationSlider(),
        
          const SizedBox(height: 32),
          
          // Next button with validation
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canProceedToStep2() ? () {
                if (_currentStep < 1) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _currentStep++;
                  });
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              } : () {
                // Show what's missing
                setState(() {
                  _showValidationErrors = true;
                });
                final error = _validateStep1();
                if (error != null) {
                  _showErrorSnackbar(error);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _canProceedToStep2() 
                    ? AppTheme.primaryDarkGreen 
                    : AppTheme.textDisabled,
                foregroundColor: AppTheme.surfaceWhite,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _canProceedToStep2() ? Icons.arrow_forward : Icons.error_outline,
                    size: 20
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _canProceedToStep2() ? 'Next Step' : 'Complete Required Fields',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 120), // Account for bottom nav
        ],
      ),
    );
  }

  Widget _buildCookingDurationSlider() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.textDisabled.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryDarkGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.access_time,
                  color: AppTheme.surfaceWhite,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Cooking Duration',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Select approximate cooking time in minutes',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 24),
          
          // Duration options row - Responsive with SingleChildScrollView
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _durationOptions.asMap().entries.map((entry) {
                int index = entry.key;
                var option = entry.value;
                bool isSelected = _durationSliderValue.round() == index;
                
                return Padding(
                  padding: EdgeInsets.only(
                    right: index < _durationOptions.length - 1 ? 8.0 : 0,
                  ),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _durationSliderValue = index.toDouble();
                        _cookingDuration = option['value'];
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryDarkGreen : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppTheme.primaryDarkGreen : AppTheme.textDisabled,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            option['label'],
                            style: TextStyle(
                              color: isSelected ? AppTheme.surfaceWhite : AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            option['description'],
                            style: TextStyle(
                              color: isSelected ? AppTheme.surfaceWhite.withOpacity(0.8) : AppTheme.textSecondary,
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.primaryDarkGreen,
              inactiveTrackColor: AppTheme.primaryDarkGreen.withOpacity(0.3),
              thumbColor: AppTheme.primaryDarkGreen,
              overlayColor: AppTheme.primaryDarkGreen.withOpacity(0.2),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              trackHeight: 4,
            ),
            child: Slider(
              value: _durationSliderValue,
              min: 0,
              max: _durationOptions.length - 1.0,
              divisions: _durationOptions.length - 1,
              onChanged: _updateDurationFromSlider,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Current selection display
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryDarkGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryDarkGreen.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, size: 16, color: AppTheme.primaryDarkGreen),
                  const SizedBox(width: 6),
                  Text(
                    'Selected: ${_durationOptions[_durationSliderValue.round()]['minutes']} minutes',
                    style: const TextStyle(
                      color: AppTheme.primaryDarkGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressIndicator(1),
          const SizedBox(height: 32),
          
          const Text(
            'Upload Filipino Recipe - Step 2',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add ingredients and cooking instructions',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          
          // Requirements indicator
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _canSubmitRecipe() 
                  ? Colors.green.withOpacity(0.1) 
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _canSubmitRecipe() ? Colors.green : Colors.orange,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _canSubmitRecipe() ? Icons.check_circle : Icons.info_outline,
                  color: _canSubmitRecipe() ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _canSubmitRecipe()
                        ? 'All requirements met! Ready to upload.'
                        : 'Required: At least 1 ingredient and 1 step',
                    style: TextStyle(
                      color: _canSubmitRecipe() ? Colors.green[800] : Colors.orange[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Ingredients section
          _buildIngredientsSection(),
          const SizedBox(height: 32),
          
          // Cooking steps section
          _buildCookingStepsSection(),
          const SizedBox(height: 32),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _currentStep--;
                    });
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.textDisabled),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    _submitRecipe();
                  },
                  icon: Icon(_canSubmitRecipe() ? Icons.upload : Icons.error_outline),
                  label: Text(_canSubmitRecipe() ? 'Upload Recipe' : 'Add Required Fields'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canSubmitRecipe() 
                        ? AppTheme.primaryDarkGreen 
                        : AppTheme.textDisabled,
                    foregroundColor: AppTheme.surfaceWhite,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 120), // Account for bottom nav
        ],
      ),
    );
  }

  Widget _buildIngredientsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ingredients',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.orange.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Tip: Add ingredients in the order you use them',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        if (_ingredients.isNotEmpty) ...[
          Column(
            children: _ingredients.asMap().entries.map((entry) {
              int index = entry.key;
              String ingredient = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.textDisabled),
                ),
                child: Row(
                  children: [
                    Text(
                      '${index + 1}.',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(ingredient)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _ingredients.removeAt(index);
                        });
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        
        TextField(
          decoration: const InputDecoration(
            hintText: 'Add Filipino ingredient (e.g., pork belly, calamansi)',
            prefixIcon: Icon(Icons.add, color: AppTheme.primaryDarkGreen),
            filled: true,
            fillColor: AppTheme.surfaceWhite,
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              HapticFeedback.lightImpact();
              setState(() {
                _ingredients.add(value.trim());
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildCookingStepsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cooking Steps',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        
        TextField(
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Describe the traditional cooking process step by step...\n\n1. First step\n2. Second step\n3. Third step',
            prefixIcon: Icon(Icons.list_alt, color: AppTheme.primaryDarkGreen),
            filled: true,
            fillColor: AppTheme.surfaceWhite,
          ),
          onChanged: (value) {
            setState(() {
              if (_steps.isEmpty) {
                _steps.add(value);
              } else {
                _steps[0] = value;
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(int currentStep) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.upload_file,
                color: AppTheme.primaryDarkGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Step ${currentStep + 1} of 2',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${((currentStep + 1) / 2 * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (int i = 0; i < 2; i++)
                Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i < 1 ? 8 : 0),
                    height: 6,
                    decoration: BoxDecoration(
                      color: i <= currentStep 
                          ? AppTheme.primaryDarkGreen 
                          : AppTheme.textDisabled.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: i <= currentStep ? [
                        BoxShadow(
                          color: AppTheme.primaryDarkGreen.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ] : [],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedSuccessOverlay() {
    return Stack(
      children: [
        // Semi-transparent background that prevents tap-through
        GestureDetector(
          onTap: () {}, // Prevent closing on background tap
          child: FadeTransition(
            opacity: _overlayFadeAnimation,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black,
            ),
          ),
        ),
        
        // Success modal
        SlideTransition(
          position: _modalSlideAnimation,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: AppTheme.surfaceWhite,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  // Header with share button
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 40),
                        const Text(
                          'Upload Success',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _shareButtonScaleAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _shareButtonScaleAnimation.value,
                              child: GestureDetector(
                                onTap: _shareRecipe,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryDarkGreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppTheme.primaryDarkGreen.withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.share,
                                    color: AppTheme.primaryDarkGreen,
                                    size: 20,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  // Success content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        // Success icon with celebration animation
                        AnimatedBuilder(
                          animation: _successScaleAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _successScaleAnimation.value,
                              child: AnimatedBuilder(
                                animation: _celebrationPulseAnimation,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: _celebrationPulseAnimation.value,
                                    child: Container(
                                      width: 90,
                                      height: 90,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppTheme.success.withOpacity(0.1),
                                            AppTheme.success.withOpacity(0.05),
                                          ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppTheme.success.withOpacity(0.2),
                                          width: 2,
                                        ),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.check_circle,
                                          size: 48,
                                          color: AppTheme.success,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Recipe name display
                        if (_foodName.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryDarkGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.primaryDarkGreen.withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              _foodName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryDarkGreen,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        
                        if (_foodName.isNotEmpty) const SizedBox(height: 12),
                        
                        // Success message
                        const Text(
                          'Recipe uploaded successfully!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 6),
                        
                        const Text(
                          'Your delicious Filipino recipe is now part of our community!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.3,
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Recipe stats
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.backgroundOffWhite,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.textDisabled.withOpacity(0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatItem(
                                Icons.access_time,
                                '$_cookingDuration min',
                                'Cook Time',
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: AppTheme.textDisabled,
                              ),
                              _buildStatItem(
                                Icons.restaurant_menu,
                                '${_ingredients.length}',
                                'Ingredients',
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: AppTheme.textDisabled,
                              ),
                              _buildStatItem(
                                Icons.favorite,
                                'Filipino',
                                'Cuisine',
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Upload Another button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _uploadAnother,
                            icon: const Icon(Icons.add_circle_outline, size: 18),
                            label: const Text('Upload Another Recipe'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryDarkGreen,
                              side: const BorderSide(
                                color: AppTheme.primaryDarkGreen,
                                width: 2,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Back to Home button - FIXED VERSION
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _navigateToHome,
                            icon: const Icon(Icons.home, size: 18),
                            label: const Text('Back to Home'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryDarkGreen,
                              foregroundColor: AppTheme.surfaceWhite,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                              shadowColor: AppTheme.primaryDarkGreen.withOpacity(0.3),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: AppTheme.primaryDarkGreen,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}