import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'services/api_service.dart';
import 'widgets/food_confirmation_dialog.dart';
import 'recipe_from_scan_page.dart';
import 'ai_recipe_page.dart';

class EnhancedScanResultsPage extends StatefulWidget {
  final File imageFile;
  final String scanType;

  const EnhancedScanResultsPage({
    super.key,
    required this.imageFile,
    required this.scanType,
  });

  @override
  State<EnhancedScanResultsPage> createState() => _EnhancedScanResultsPageState();
}

class _EnhancedScanResultsPageState extends State<EnhancedScanResultsPage>
    with TickerProviderStateMixin {
  
  bool _isAnalyzing = true;
  bool _isGettingRecipe = false;
  String? _error;
  Map<String, dynamic>? _scanResult;
  List<Map<String, dynamic>> _detectedItems = [];
  
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _pulseController.repeat(reverse: true);
    _analyzeImage();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _analyzeImage() async {
    try {
      setState(() {
        _isAnalyzing = true;
        _error = null;
      });

      // Call the HuggingFace API through backend
      final result = await ApiService.analyzeImage(
        imageFile: widget.imageFile,
        scanType: widget.scanType.toLowerCase(),
      );

      if (result['success'] == true) {
        final detectedItemsList = List<Map<String, dynamic>>.from(
          result['detectedItems'] ?? []
        );
        
        // If AI recipe is available and successful, navigate directly without showing this screen
        if (result['aiRecipe'] != null && 
            result['aiRecipe']['error'] == null &&
            detectedItemsList.isNotEmpty && 
            detectedItemsList[0]['name'] != null) {
          // Navigate immediately without showing results screen
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => AIRecipePage(
                  foodName: detectedItemsList[0]['name'] as String,
                  aiRecipe: result['aiRecipe'] as Map<String, dynamic>,
                  imageFile: widget.imageFile,
                ),
              ),
            );
          }
        } else {
          // Show results screen for confirmation
          setState(() {
            _scanResult = result;
            _detectedItems = detectedItemsList;
            _isAnalyzing = false;
          });
          
          _slideController.forward();
          HapticFeedback.lightImpact();
          
          // Show confirmation dialog after a brief delay
          await Future.delayed(const Duration(milliseconds: 500));
          _showConfirmationDialog();
        }
        
      } else {
        throw Exception(result['message'] ?? 'Analysis failed');
      }
      
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isAnalyzing = false;
      });
      HapticFeedback.heavyImpact();
    }
  }

  void _showConfirmationDialog() {
    if (_detectedItems.isEmpty) {
      _showManualInputDialog();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => FoodConfirmationDialog(
        detectedItems: _detectedItems,
        onConfirm: _handleFoodConfirmation,
        onCancel: () {
          Navigator.pop(context);
          Navigator.pop(context); // Go back to camera
        },
      ),
    );
  }

  void _showManualInputDialog() {
    final TextEditingController controller = TextEditingController();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('No Food Detected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('We couldn\'t detect any food in the image. Please enter the food name manually:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'e.g., Chicken Adobo, Lechon, Sinigang...',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to camera
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final foodName = controller.text.trim();
              if (foodName.isNotEmpty) {
                Navigator.pop(context);
                _handleFoodConfirmation(foodName, false);
              }
            },
            child: const Text('Get Recipe'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleFoodConfirmation(String foodName, bool isCorrect) async {
    setState(() {
      _isGettingRecipe = true;
    });

    try {
      Map<String, dynamic> result;
      
      if (isCorrect && _scanResult != null) {
        // User confirmed the detection
        result = await ApiService.confirmDetection(
          scanId: _scanResult!['scanId'],
          foodName: foodName,
          isCorrect: true,
        );
      } else {
        // User entered manually or corrected the detection
        result = await ApiService.manualFoodInput(
          foodName: foodName,
          scanId: _scanResult?['scanId'],
        );
      }

      if (result['success'] == true && result['recipe'] != null) {
        // Navigate to recipe page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeFromScanPage(
              foodName: foodName,
              recipe: result['recipe'],
              scanId: result['scanId'] ?? _scanResult?['scanId'] ?? '',
            ),
          ),
        );
      } else {
        throw Exception('Failed to get recipe');
      }
      
    } catch (e) {
      setState(() {
        _error = 'Failed to get recipe: ${e.toString()}';
        _isGettingRecipe = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('${widget.scanType} Analysis'),
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isAnalyzing) {
      return _buildAnalyzingState();
    } else if (_isGettingRecipe) {
      return _buildGettingRecipeState();
    } else if (_error != null) {
      return _buildErrorState();
    } else {
      return _buildResultsState();
    }
  }

  Widget _buildAnalyzingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated food icon
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.restaurant_menu,
                    size: 60,
                    color: Colors.orange.shade600,
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 32),
          
          Text(
            'Analyzing ${widget.scanType}...',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            'Using AI to identify your food',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Progress indicator
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGettingRecipeState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated cooking icon
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.menu_book,
                    size: 60,
                    color: Colors.green.shade600,
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 32),
          
          Text(
            'Getting Recipe...',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            'Preparing ingredients and cooking steps',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          
          const SizedBox(height: 32),
          
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red.shade400,
            ),
            
            const SizedBox(height: 24),
            
            Text(
              'Analysis Failed',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            
            const SizedBox(height: 32),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _analyzeImage,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
                
                TextButton.icon(
                  onPressed: _showManualInputDialog,
                  icon: const Icon(Icons.edit),
                  label: const Text('Enter Manually'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsState() {
    return SlideTransition(
      position: _slideAnimation,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image preview
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: DecorationImage(
                  image: FileImage(widget.imageFile),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Detection results
            Text(
              'Detection Results',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            
            const SizedBox(height: 16),
            
            if (_detectedItems.isNotEmpty) ...[
              ..._detectedItems.map((item) => _buildDetectionItem(item)),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No food detected in the image',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const Spacer(),
            
            // Action button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _showConfirmationDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continue to Recipe',
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
    );
  }

  Widget _buildDetectionItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.restaurant_menu,
              color: Colors.orange.shade600,
            ),
          ),
          
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${((item['confidence'] ?? 0) * 100).toStringAsFixed(1)}% confidence',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              item['category'] ?? 'food',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
