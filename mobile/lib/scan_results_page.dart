import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'recipe_details_page.dart';
import 'camera_scan_page.dart';

class ScanResultsPage extends StatefulWidget {
  final String scanType;
  final List<String> detectedItems;
  
  const ScanResultsPage({
    super.key, 
    required this.scanType, 
    required this.detectedItems
  });

  @override
  State<ScanResultsPage> createState() => _ScanResultsPageState();
}

class _ScanResultsPageState extends State<ScanResultsPage>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _suggestedRecipes = [];
  List<Map<String, dynamic>> _commonIngredients = [];
  bool _isLoading = true;
  late AnimationController _slideAnimationController;
  late AnimationController _fadeAnimationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeIn,
    ));
    
    _loadResults();
  }

  @override
  void dispose() {
    _slideAnimationController.dispose();
    _fadeAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadResults() async {
    // Simulate processing time
    await Future.delayed(const Duration(milliseconds: 1500));
    
    _generateResults();
    
    setState(() {
      _isLoading = false;
    });
    
    _slideAnimationController.forward();
    _fadeAnimationController.forward();
    
    HapticFeedback.heavyImpact();
  }

  void _generateResults() {
    if (widget.scanType == 'Food') {
      _generateFoodResults();
    } else {
      _generateIngredientResults();
    }
  }

  void _generateFoodResults() {
    if (widget.detectedItems.isEmpty) {
      setState(() {
        _isLoading = false;
        _commonIngredients = [];
        _suggestedRecipes = [];
      });
      return;
    }
    
    // Handle case where detectedItems contains error messages
    if (widget.detectedItems.first.contains('failed') || 
        widget.detectedItems.first.contains('error') ||
        widget.detectedItems.first.contains('No ')) {
      setState(() {
        _isLoading = false;
        _commonIngredients = [];
        _suggestedRecipes = [];
      });
      return;
    }
    
    final String detectedFood = widget.detectedItems.first;
    
    // Enhanced ingredient mappings for different Filipino dishes
    final Map<String, List<Map<String, String>>> foodIngredients = {
      'Chicken Adobo': [
        {'name': 'Chicken pieces (thighs/drumsticks)', 'amount': '1 kg'},
        {'name': 'Soy sauce', 'amount': '1/2 cup'},
        {'name': 'White vinegar', 'amount': '1/4 cup'},
        {'name': 'Garlic cloves', 'amount': '6-8 pieces'},
        {'name': 'Bay leaves', 'amount': '3 pieces'},
        {'name': 'Black peppercorns', 'amount': '1 tsp'},
        {'name': 'Onion (medium)', 'amount': '1 piece'},
        {'name': 'Brown sugar (optional)', 'amount': '1 tbsp'},
      ],
      'Sinigang na Baboy': [
        {'name': 'Pork ribs or belly', 'amount': '1 kg'},
        {'name': 'Tamarind paste or mix', 'amount': '2-3 tbsp'},
        {'name': 'Tomatoes (medium)', 'amount': '2-3 pieces'},
        {'name': 'Onion (large)', 'amount': '1 piece'},
        {'name': 'Kangkong (water spinach)', 'amount': '1 bunch'},
        {'name': 'Radish (labanos)', 'amount': '1 piece'},
        {'name': 'Green chili (siling haba)', 'amount': '2-3 pieces'},
        {'name': 'Eggplant (long)', 'amount': '1 piece'},
        {'name': 'Fish sauce (patis)', 'amount': '2 tbsp'},
      ],
      'Kare-Kare': [
        {'name': 'Oxtail (cut into pieces)', 'amount': '1.5 kg'},
        {'name': 'Peanut butter (smooth)', 'amount': '1 cup'},
        {'name': 'Ground rice or rice flour', 'amount': '1/4 cup'},
        {'name': 'Eggplant (sliced)', 'amount': '2 pieces'},
        {'name': 'String beans (sitaw)', 'amount': '1 bundle'},
        {'name': 'Banana heart (puso ng saging)', 'amount': '1 piece'},
        {'name': 'Shrimp paste (bagoong)', 'amount': '3-4 tbsp'},
        {'name': 'Annatto seeds or powder', 'amount': '2 tbsp'},
      ],
    };

    _commonIngredients = (foodIngredients[detectedFood] ?? [
      {'name': 'Main ingredient', 'amount': '1 kg'},
      {'name': 'Secondary ingredient', 'amount': '2 tbsp'},
      {'name': 'Seasoning', 'amount': '1 tsp'},
    ]).map((ingredient) => {
      'name': ingredient['name']!,
      'amount': ingredient['amount']!,
      'available': false,
      'essential': true,
    }).toList();

    // Enhanced recipe suggestions
    _suggestedRecipes = [
      {
        'name': 'Traditional $detectedFood',
        'creator': 'Lola\'s Kitchen',
        'type': 'Food',
        'time': '90 mins',
        'difficulty': 'Medium',
        'rating': 4.9,
        'description': 'The authentic recipe passed down through generations with traditional cooking methods.',
        'serves': 6,
        'prepTime': 20,
        'cookTime': 70,
        'ingredients': foodIngredients[detectedFood]?.length ?? 8,
        'category': 'Traditional',
        'spiceLevel': 'Mild',
      },
      {
        'name': 'Quick $detectedFood',
        'creator': 'Modern Filipino Kitchen',
        'type': 'Food',
        'time': '45 mins',
        'difficulty': 'Easy',
        'rating': 4.6,
        'description': 'A time-saving version perfect for busy weekdays without compromising on taste.',
        'serves': 4,
        'prepTime': 15,
        'cookTime': 30,
        'ingredients': (foodIngredients[detectedFood]?.length ?? 8) - 2,
        'category': 'Quick & Easy',
        'spiceLevel': 'Mild',
      },
      {
        'name': 'Healthy $detectedFood',
        'creator': 'Wellness Chef',
        'type': 'Food',
        'time': '75 mins',
        'difficulty': 'Medium',
        'rating': 4.7,
        'description': 'A nutritious version with reduced sodium and added vegetables for health-conscious families.',
        'serves': 4,
        'prepTime': 25,
        'cookTime': 50,
        'ingredients': (foodIngredients[detectedFood]?.length ?? 8) + 3,
        'category': 'Healthy',
        'spiceLevel': 'Mild',
      },
    ];
  }

  void _generateIngredientResults() {
    if (widget.detectedItems.isEmpty) {
      setState(() {
        _isLoading = false;
        _suggestedRecipes = [];
      });
      return;
    }
    
    _suggestedRecipes = _getRecipesForIngredients(widget.detectedItems);
  }

  List<Map<String, dynamic>> _getRecipesForIngredients(List<String> ingredients) {
    final List<Map<String, dynamic>> allRecipes = [
      {
        'name': 'Chicken Adobo',
        'creator': 'Filipino Chef',
        'type': 'Food',
        'time': '60 mins',
        'difficulty': 'Medium',
        'rating': 4.8,
        'description': 'Classic Filipino braised chicken in soy sauce and vinegar.',
        'serves': 4,
        'ingredients': ['Chicken', 'Soy Sauce', 'Vinegar', 'Garlic'],
        'matchedIngredients': 0,
        'prepTime': 15,
        'cookTime': 45,
        'category': 'Main Course',
        'spiceLevel': 'Mild',
      },
      {
        'name': 'Chicken Tinola',
        'creator': 'Home Cook',
        'type': 'Food',
        'time': '45 mins',
        'difficulty': 'Easy',
        'rating': 4.6,
        'description': 'Comforting chicken soup with ginger and vegetables.',
        'serves': 4,
        'ingredients': ['Chicken', 'Ginger', 'Onion', 'Green Papaya'],
        'matchedIngredients': 0,
        'prepTime': 10,
        'cookTime': 35,
        'category': 'Soup',
        'spiceLevel': 'Mild',
      },
      {
        'name': 'Vegetable Lumpia',
        'creator': 'Veggie Master',
        'type': 'Food',
        'time': '40 mins',
        'difficulty': 'Medium',
        'rating': 4.4,
        'description': 'Fresh spring rolls with mixed vegetables.',
        'serves': 6,
        'ingredients': ['Bell Pepper', 'Carrots', 'Cabbage', 'Lettuce'],
        'matchedIngredients': 0,
        'prepTime': 30,
        'cookTime': 10,
        'category': 'Appetizer',
        'spiceLevel': 'None',
      },
      {
        'name': 'Ginataang Gulay',
        'creator': 'Traditional Cook',
        'type': 'Food',
        'time': '25 mins',
        'difficulty': 'Easy',
        'rating': 4.7,
        'description': 'Mixed vegetables cooked in coconut milk.',
        'serves': 4,
        'ingredients': ['Coconut Milk', 'Squash', 'String Beans', 'Eggplant'],
        'matchedIngredients': 0,
        'prepTime': 10,
        'cookTime': 15,
        'category': 'Vegetable',
        'spiceLevel': 'Mild',
      },
      {
        'name': 'Pancit Guisado',
        'creator': 'Noodle Expert',
        'type': 'Food',
        'time': '30 mins',
        'difficulty': 'Easy',
        'rating': 4.5,
        'description': 'Stir-fried noodles with vegetables and meat.',
        'serves': 6,
        'ingredients': ['Noodles', 'Cabbage', 'Carrots', 'Pork'],
        'matchedIngredients': 0,
        'prepTime': 15,
        'cookTime': 15,
        'category': 'Noodles',
        'spiceLevel': 'Mild',
      },
    ];

    // Calculate matched ingredients and sort by relevance
    for (var recipe in allRecipes) {
      final recipeIngredients = recipe['ingredients'] as List<String>;
      int matchCount = 0;
      
      for (String ingredient in ingredients) {
        for (String recipeIngredient in recipeIngredients) {
          if (recipeIngredient.toLowerCase().contains(ingredient.toLowerCase()) ||
              ingredient.toLowerCase().contains(recipeIngredient.toLowerCase())) {
            matchCount++;
            break;
          }
        }
      }
      recipe['matchedIngredients'] = matchCount;
    }

    // Sort by matched ingredients (descending) and rating
    allRecipes.sort((a, b) {
      if (a['matchedIngredients'] != b['matchedIngredients']) {
        return b['matchedIngredients'].compareTo(a['matchedIngredients']);
      }
      return b['rating'].compareTo(a['rating']);
    });

    return allRecipes.where((recipe) => recipe['matchedIngredients'] > 0).take(8).toList();
  }

  void _toggleIngredientAvailability(int index) {
    setState(() {
      _commonIngredients[index]['available'] = 
          !_commonIngredients[index]['available'];
    });
    HapticFeedback.selectionClick();
  }

  void _openRecipeDetails(Map<String, dynamic> recipe) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeDetailsPage(recipe: recipe),
      ),
    );
  }

  void _shareResults() {
    HapticFeedback.lightImpact();
    final itemsText = widget.detectedItems.join(', ');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Shared: ${widget.scanType} - $itemsText'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _scanAgain() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScanPage(scanType: widget.scanType),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Scan Results',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black),
            onPressed: _shareResults,
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingState() : _buildResultsContent(),
      bottomNavigationBar: _isLoading ? null : _buildBottomActions(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green.withOpacity(0.1),
            ),
            child: const Center(
              child: CircularProgressIndicator(
                color: Colors.green,
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Processing results...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Analyzing your ${widget.scanType.toLowerCase()}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsContent() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetectionResults(),
                const SizedBox(height: 24),
                if (widget.scanType == 'Food') ...[
                  _buildCommonIngredients(),
                  const SizedBox(height: 24),
                  _buildRecipeSuggestions(),
                ] else ...[
                  _buildRecipeSuggestions(),
                ],
                const SizedBox(height: 80), // Bottom padding for fixed buttons
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetectionResults() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.green.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detection Successful!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.scanType == 'Food' 
                          ? 'Detected: ${widget.detectedItems.first}'
                          : 'Found ${widget.detectedItems.length} ingredients',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.scanType == 'Ingredient') ...[
            const SizedBox(height: 20),
            const Text(
              'Detected Ingredients:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: widget.detectedItems.asMap().entries.map((entry) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade200,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.eco,
                        color: Colors.green.shade800,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        entry.value,
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommonIngredients() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.shopping_cart, color: Colors.black87, size: 24),
            const SizedBox(width: 12),
            const Text(
              'Recipe Ingredients',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Check off ingredients you already have at home:',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 20),
        ..._commonIngredients.asMap().entries.map((entry) {
          int index = entry.key;
          Map<String, dynamic> ingredient = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: ingredient['available'] ? Colors.green.withOpacity(0.08) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: ingredient['available'] ? Colors.green : Colors.grey.shade300,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: ingredient['available'] 
                      ? Colors.green.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _toggleIngredientAvailability(index),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: ingredient['available'] ? Colors.green : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: ingredient['available'] ? Colors.green : Colors.grey,
                            width: 2,
                          ),
                        ),
                        child: ingredient['available']
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : null,
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ingredient['name'],
                              style: TextStyle(
                                fontSize: 16,
                                color: ingredient['available'] ? Colors.green.shade700 : Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ingredient['amount'],
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (ingredient['essential'] == true)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Essential',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildRecipeSuggestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              widget.scanType == 'Food' ? Icons.restaurant_menu : Icons.lightbulb_outline,
              color: Colors.black87,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              widget.scanType == 'Food' ? 'Recipe Variations' : 'Suggested Recipes',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          widget.scanType == 'Food' 
              ? 'Different ways to prepare this dish:'
              : 'Delicious recipes you can make:',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 20),
        if (_suggestedRecipes.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No recipes found',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try scanning different ingredients',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Column(
            children: _suggestedRecipes.map((recipe) => Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openRecipeDetails(recipe),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.green.shade200, Colors.green.shade300],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.restaurant,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                recipe['name'],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'By ${recipe['creator']}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _buildRecipeInfo(Icons.access_time, recipe['time']),
                                  const SizedBox(width: 16),
                                  _buildRecipeInfo(Icons.star, '${recipe['rating']}'),
                                  if (widget.scanType == 'Ingredient' && recipe['matchedIngredients'] > 0) ...[
                                    const SizedBox(width: 16),
                                    _buildRecipeInfo(Icons.eco, '${recipe['matchedIngredients']} matched'),
                                  ],
                                ],
                              ),
                              if (recipe['difficulty'] != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getDifficultyColor(recipe['difficulty']).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    recipe['difficulty'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _getDifficultyColor(recipe['difficulty']),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.grey,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )).toList(),
          ),
      ],
    );
  }

  Widget _buildRecipeInfo(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'hard':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _scanAgain,
              icon: const Icon(Icons.document_scanner, size: 20),
              label: const Text(
                'Scan Again',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.green,
                side: const BorderSide(color: Colors.green, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
              icon: const Icon(Icons.home, size: 20),
              label: const Text(
                'Back to Home',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}