import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'services/api_service.dart';
import 'recipe_suggestions_page.dart';

class IngredientScanResultsPage extends StatefulWidget {
  final File imageFile;

  const IngredientScanResultsPage({
    super.key,
    required this.imageFile,
  });

  @override
  State<IngredientScanResultsPage> createState() => _IngredientScanResultsPageState();
}

class _IngredientScanResultsPageState extends State<IngredientScanResultsPage>
    with TickerProviderStateMixin {
  
  bool _isScanning = true;
  bool _isGettingSuggestions = false;
  String? _error;
  List<Map<String, dynamic>> _detectedIngredients = [];
  List<Map<String, dynamic>> _recipeSuggestions = [];
  
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
    _scanIngredients();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _scanIngredients() async {
    try {
      setState(() {
        _isScanning = true;
        _error = null;
      });

      final result = await ApiService.scanIngredients(
        imageFile: widget.imageFile,
      );

      if (result['success'] == true) {
        setState(() {
          _detectedIngredients = List<Map<String, dynamic>>.from(
            result['ingredients'] ?? []
          );
          _recipeSuggestions = List<Map<String, dynamic>>.from(
            result['recipeSuggestions'] ?? []
          );
          _isScanning = false;
        });
        
        _slideController.forward();
        HapticFeedback.lightImpact();
        
      } else {
        throw Exception(result['message'] ?? 'Ingredient scanning failed');
      }
      
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isScanning = false;
      });
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _getMoreRecipeSuggestions() async {
    if (_detectedIngredients.isEmpty) return;

    try {
      setState(() {
        _isGettingSuggestions = true;
      });

      final result = await ApiService.getRecipeSuggestions(
        ingredients: _detectedIngredients,
      );

      if (result['success'] == true) {
        setState(() {
          _recipeSuggestions = List<Map<String, dynamic>>.from(
            result['recipeSuggestions'] ?? []
          );
        });
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting recipe suggestions: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isGettingSuggestions = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Ingredient Scan'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isScanning) {
      return _buildScanningState();
    } else if (_error != null) {
      return _buildErrorState();
    } else {
      return _buildResultsState();
    }
  }

  Widget _buildScanningState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated ingredient icon
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
                    Icons.eco,
                    size: 60,
                    color: Colors.green.shade600,
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 32),
          
          Text(
            'Scanning Ingredients...',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            'Identifying ingredients in your image',
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
              'Scanning Failed',
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
            
            ElevatedButton.icon(
              onPressed: _scanIngredients,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsState() {
    return SlideTransition(
      position: _slideAnimation,
      child: SingleChildScrollView(
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
            
            // Detected ingredients section
            _buildIngredientsSection(),
            
            const SizedBox(height: 32),
            
            // Recipe suggestions section
            _buildRecipeSuggestionsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.eco, color: Colors.green.shade600, size: 24),
            const SizedBox(width: 8),
            Text(
              'Detected Ingredients (${_detectedIngredients.length})',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        if (_detectedIngredients.isEmpty) ...[
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
                    'No ingredients detected in the image',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          ...(_detectedIngredients.map((ingredient) => _buildIngredientItem(ingredient))),
        ],
      ],
    );
  }

  Widget _buildIngredientItem(Map<String, dynamic> ingredient) {
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
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getIngredientIcon(ingredient['category'] ?? 'other'),
              color: Colors.green.shade600,
            ),
          ),
          
          const SizedBox(width: 16),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ingredient['name'] ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${((ingredient['confidence'] ?? 0) * 100).toStringAsFixed(1)}% confidence',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        ingredient['category'] ?? 'other',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeSuggestionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.restaurant_menu, color: Colors.orange.shade600, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Recipe Suggestions (${_recipeSuggestions.length})',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
            if (_detectedIngredients.isNotEmpty) ...[
              TextButton.icon(
                onPressed: _isGettingSuggestions ? null : _getMoreRecipeSuggestions,
                icon: _isGettingSuggestions 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: const Text('More'),
              ),
            ],
          ],
        ),
        
        const SizedBox(height: 16),
        
        if (_recipeSuggestions.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.restaurant_menu, 
                     color: Colors.orange.shade400, size: 48),
                const SizedBox(height: 12),
                Text(
                  'No recipe suggestions yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try scanning more ingredients or tap "More" to get suggestions',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          ...(_recipeSuggestions.take(5).map((recipe) => _buildRecipeSuggestionItem(recipe))),
          
          if (_recipeSuggestions.length > 5) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _viewAllSuggestions(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('View All ${_recipeSuggestions.length} Suggestions'),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildRecipeSuggestionItem(Map<String, dynamic> recipe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        shadowColor: Colors.black12,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _viewRecipeDetails(recipe),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Recipe image or icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: recipe['image'] != null 
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            recipe['image'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => 
                                Icon(Icons.restaurant_menu, color: Colors.orange.shade600),
                          ),
                        )
                      : Icon(Icons.restaurant_menu, color: Colors.orange.shade600),
                ),
                
                const SizedBox(width: 16),
                
                // Recipe details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe['name'] ?? 'Unknown Recipe',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        recipe['description'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildRecipeTag(
                            Icons.timer, 
                            '${recipe['cookTime'] ?? 30} min',
                            Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          _buildRecipeTag(
                            Icons.people, 
                            '${recipe['servings'] ?? 4}',
                            Colors.green,
                          ),
                          const SizedBox(width: 8),
                          if (recipe['matchedIngredients'] != null) ...[
                            _buildRecipeTag(
                              Icons.check_circle, 
                              '${(recipe['matchedIngredients'] as List).length} match',
                              Colors.orange,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey.shade400,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecipeTag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIngredientIcon(String category) {
    switch (category.toLowerCase()) {
      case 'vegetable':
        return Icons.eco;
      case 'fruit':
        return Icons.apple;
      case 'meat':
        return Icons.set_meal;
      case 'dairy':
        return Icons.local_drink;
      case 'grain':
        return Icons.grain;
      case 'spice':
        return Icons.spa;
      case 'condiment':
        return Icons.local_dining;
      default:
        return Icons.fastfood;
    }
  }

  void _viewRecipeDetails(Map<String, dynamic> recipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeSuggestionsPage(
          detectedIngredients: _detectedIngredients,
          initialRecipe: recipe,
        ),
      ),
    );
  }

  void _viewAllSuggestions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeSuggestionsPage(
          detectedIngredients: _detectedIngredients,
          recipeSuggestions: _recipeSuggestions,
        ),
      ),
    );
  }
}
