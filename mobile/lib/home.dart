import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'search_page.dart';
import 'recipe_details_page.dart';
import 'camera_scan_page.dart';
import 'user_profile_page.dart';
import 'app_theme.dart';
import 'services/api_service.dart';
import 'config/api_config.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  
  // State variables
  String _selectedCategory = 'All';
  bool _isLoading = false;
  String? _errorMessage;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Real recipes from API
  List<Map<String, dynamic>> _recipes = [];

  // Old mock data removed - now fetching from backend
  /* {
      'id': 'recipe_1',
      'name': 'Ginataang Kalabasa at Sitaw',
      'creator': 'Filipino Chef',
      'type': 'Food',
      'time': '25 mins',
      'duration': 25,
      'tags': ['vegetarian', 'coconut', 'squash', 'filipino'],
      'category': 'Lunch',
      'calories': 200,
      'carbs': '20g',
      'fat': '12g',
      'protein': '5g',
      'rating': 4.7,
      'difficulty': 'Easy',
      'serves': 4,
      'description': 'A traditional Filipino vegetable stew made with squash and string beans cooked in coconut milk.',
      'image': null,
      'prepTime': 10,
      'cookTime': 15,
      'ingredients': [
        'Kalabasa (Squash)',
        'Sitaw (String beans)',
        'Coconut milk',
        'Onion',
        'Garlic',
        'Ginger',
        'Salt',
        'Pepper'
      ],
      'steps': [
        'Prepare and cut vegetables',
        'Sauté aromatics',
        'Add coconut milk',
        'Simmer until tender'
      ],
    },
    {
      'id': 'recipe_2',
      'name': 'Chicken Inasal',
      'creator': 'Ilonggo Chef',
      'type': 'Food',
      'time': '90 mins',
      'duration': 90,
      'tags': ['grilled', 'chicken', 'filipino', 'visayas'],
      'category': 'Dinner',
      'calories': 350,
      'carbs': '5g',
      'fat': '25g',
      'protein': '35g',
      'rating': 4.8,
      'difficulty': 'Medium',
      'serves': 6,
      'description': 'A famous grilled chicken dish from the Philippines, marinated in lemongrass, calamansi, and annatto.',
      'image': null,
      'prepTime': 45,
      'cookTime': 45,
      'ingredients': [
        'Whole chicken',
        'Lemongrass',
        'Calamansi',
        'Annatto oil',
        'Garlic',
        'Ginger',
        'Salt',
        'Brown sugar'
      ],
      'steps': [
        'Prepare marinade',
        'Marinate chicken',
        'Preheat grill',
        'Grill until cooked'
      ],
    },
    {
      'id': 'recipe_3',
      'name': 'Taho',
      'creator': 'Street Vendor',
      'type': 'Drink',
      'time': '15 mins',
      'duration': 15,
      'tags': ['snack', 'sweet', 'tofu', 'filipino'],
      'category': 'Snack',
      'calories': 220,
      'carbs': '45g',
      'fat': '2g',
      'protein': '7g',
      'rating': 4.5,
      'difficulty': 'Easy',
      'serves': 2,
      'description': 'A popular Filipino street food dessert made of soft silken tofu, arnibal syrup, and sago pearls.',
      'image': null,
      'prepTime': 5,
      'cookTime': 10,
      'ingredients': [
        'Silken tofu',
        'Brown sugar',
        'Sago pearls',
        'Water',
        'Vanilla extract'
      ],
      'steps': [
        'Prepare arnibal syrup',
        'Cook sago pearls',
        'Steam tofu',
        'Assemble and serve'
      ],
    },
    {
      'id': 'recipe_4',
      'name': 'Sinigang na Baboy',
      'creator': 'Grandma\'s Recipe',
      'type': 'Food',
      'time': '60 mins',
      'duration': 60,
      'tags': ['sour', 'pork', 'soup', 'filipino'],
      'category': 'Lunch',
      'calories': 300,
      'carbs': '15g',
      'fat': '20g',
      'protein': '20g',
      'rating': 4.9,
      'difficulty': 'Medium',
      'serves': 4,
      'description': 'A classic Filipino sour soup made with pork, vegetables, and tamarind.',
      'image': null,
      'prepTime': 20,
      'cookTime': 40,
      'ingredients': [
        'Pork ribs',
        'Tamarind paste',
        'Tomatoes',
        'Onion',
        'Kangkong',
        'Radish',
        'Green chili',
        'Fish sauce'
      ],
      'steps': [
        'Boil pork until tender',
        'Add vegetables',
        'Season with tamarind',
        'Simmer until done'
      ],
    },
    {
      'id': 'recipe_5',
      'name': 'Bibingka',
      'creator': 'Traditional Baker',
      'type': 'Food',
      'time': '45 mins',
      'duration': 45,
      'tags': ['dessert', 'rice cake', 'christmas', 'filipino'],
      'category': 'Snack',
      'calories': 300,
      'carbs': '50g',
      'fat': '10g',
      'protein': '6g',
      'rating': 4.6,
      'difficulty': 'Medium',
      'serves': 8,
      'description': 'A traditional Filipino rice cake that is especially popular during Christmas season.',
      'image': null,
      'prepTime': 20,
      'cookTime': 25,
      'ingredients': [
        'Rice flour',
        'Coconut milk',
        'Eggs',
        'Sugar',
        'Baking powder',
        'Salted egg',
        'Cheese',
        'Banana leaves'
      ],
      'steps': [
        'Mix batter ingredients',
        'Prepare banana leaves',
        'Pour and add toppings',
        'Bake until golden'
      ],
    },
    {
      'id': 'recipe_6',
      'name': 'Chicken Adobo',
      'creator': 'Lola\'s Kitchen',
      'type': 'Food',
      'time': '60 mins',
      'duration': 60,
      'tags': ['chicken', 'soy sauce', 'vinegar', 'filipino'],
      'category': 'Dinner',
      'calories': 380,
      'carbs': '8g',
      'fat': '28g',
      'protein': '32g',
      'rating': 4.9,
      'difficulty': 'Easy',
      'serves': 6,
      'description': 'The most iconic Filipino dish. Chicken braised in soy sauce, vinegar, garlic, and spices.',
      'image': null,
      'prepTime': 15,
      'cookTime': 45,
      'ingredients': [
        'Chicken pieces',
        'Soy sauce',
        'White vinegar',
        'Garlic',
        'Bay leaves',
        'Black peppercorns',
        'Onion',
        'Brown sugar'
      ],
      'steps': [
        'Marinate chicken',
        'Brown the chicken',
        'Add liquids and aromatics',
        'Simmer until tender'
      ],
    },
  */ // End of mock data

  final List<Map<String, dynamic>> _categories = [
    {'id': 'cat_all', 'name': 'All', 'icon': Icons.all_inclusive},
    {'id': 'cat_food', 'name': 'Food', 'icon': Icons.fastfood},
    {'id': 'cat_drink', 'name': 'Drink', 'icon': Icons.local_drink},
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _loadInitialData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // Computed property for filtered recipes
  List<Map<String, dynamic>> get filteredRecipes {
    if (_selectedCategory == 'All') {
      return _recipes;
    }
    return _recipes.where((recipe) => recipe['type'] == _selectedCategory).toList();
  }

  // Load initial data from API
  Future<void> _loadInitialData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // Get current user ID first
      String? currentUserId;
      try {
        final userResponse = await ApiService.getCurrentUser();
        if (userResponse['success'] == true) {
          currentUserId = userResponse['user']['_id'] ?? userResponse['user']['id'];
          print('✅ Current user ID: $currentUserId');
        }
      } catch (e) {
        print('⚠️ Could not fetch current user, showing all recipes: $e');
      }
      
      // Fetch recipes from API
      final response = await ApiService.getRecipes(
        page: 1,
        limit: 50, // Fetch more to ensure we have enough after filtering
      );
      
      if (mounted && response['success'] == true) {
        final List<dynamic> recipesData = response['recipes'] ?? [];
        
        // Filter out current user's recipes
        final filteredRecipes = recipesData.where((recipe) {
          // Get the creator ID from the recipe
          final creatorId = recipe['creator'] is Map 
              ? (recipe['creator']['_id'] ?? recipe['creator']['id'])
              : recipe['creator'];
          
          // Only include recipes NOT created by current user
          final isOtherUser = creatorId != currentUserId;
          
          if (!isOtherUser && currentUserId != null) {
            print('🚫 Filtering out own recipe: ${recipe['title']}');
          }
          
          return isOtherUser;
        }).toList();
        
        print('📊 Total recipes: ${recipesData.length}, Other users: ${filteredRecipes.length}');
        
        setState(() {
          _recipes = filteredRecipes.map((recipe) {
            // Extract creator ID for navigation
            final creator = recipe['creator'];
            final creatorId = creator is Map 
                ? (creator['_id'] ?? creator['id'])
                : creator;
            
            return {
              'id': recipe['_id'] ?? '',
              'name': recipe['title'] ?? 'Untitled Recipe',
              'creator': creator is Map 
                  ? (creator['name'] ?? 'Anonymous')
                  : 'Anonymous',
              'creatorId': creatorId,
              'type': _mapCategoryToType(recipe['category']),
              'time': '${(recipe['prepTime'] ?? 0) + (recipe['cookTime'] ?? 0)} mins',
              'duration': (recipe['prepTime'] ?? 0) + (recipe['cookTime'] ?? 0),
              'tags': List<String>.from(recipe['tags'] ?? []),
              'category': recipe['category'] ?? 'Lunch',
              'calories': recipe['nutrition']?['calories'] ?? 0,
              'carbs': recipe['nutrition']?['carbs'] ?? '0g',
              'fat': recipe['nutrition']?['fat'] ?? '0g',
              'protein': recipe['nutrition']?['protein'] ?? '0g',
              'rating': (recipe['averageRating'] ?? 0).toDouble(),
              'difficulty': _capitalizeDifficulty(recipe['difficulty'] ?? 'easy'),
              'serves': recipe['servings'] ?? 1,
              'description': recipe['description'] ?? '',
              'likesCount': recipe['likesCount'] ?? 0,
              'ratingsCount': recipe['ratingsCount'] ?? 0,
              'image': _getFullImageUrl(
                recipe['images'] != null && (recipe['images'] as List).isNotEmpty 
                    ? recipe['images'][0] 
                    : null
              ),
              'prepTime': recipe['prepTime'] ?? 0,
              'cookTime': recipe['cookTime'] ?? 0,
              'ingredients': _extractIngredientNames(recipe['ingredients']),
              'steps': _extractInstructionSteps(recipe['instructions']),
            };
          }).toList();
          _isLoading = false;
        });
        _fadeController.forward();
      }
    } catch (error) {
      print('Error loading recipes: $error');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load recipes. Please try again.';
        });
      }
    }
  }

  String _mapCategoryToType(String? category) {
    if (category == null) return 'Food';
    if (category.toLowerCase().contains('bever') || category.toLowerCase().contains('drink')) {
      return 'Drink';
    }
    return 'Food';
  }

  String _capitalizeDifficulty(String difficulty) {
    return difficulty[0].toUpperCase() + difficulty.substring(1).toLowerCase();
  }

  List<String> _extractIngredientNames(dynamic ingredients) {
    if (ingredients == null) return [];
    if (ingredients is List) {
      return ingredients.map((ing) {
        if (ing is Map) return ing['name']?.toString() ?? ing['ingredient']?.toString() ?? '';
        return ing.toString();
      }).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  List<String> _extractInstructionSteps(dynamic instructions) {
    if (instructions == null) return [];
    if (instructions is List) {
      return instructions.map((inst) {
        if (inst is Map) return inst['instruction']?.toString() ?? inst['step']?.toString() ?? '';
        return inst.toString();
      }).where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  String? _getFullImageUrl(dynamic image) {
    if (image == null || image.toString().isEmpty) return null;
    
    final imageStr = image.toString();
    
    // If it's already a full URL, return as is
    if (imageStr.startsWith('http://') || imageStr.startsWith('https://')) {
      return imageStr;
    }
    
    // Otherwise, construct full URL from base URL
    final baseUrl = ApiConfig.safeBaseUrl.replaceAll('/api', ''); // Remove /api suffix
    return '$baseUrl$imageStr'; // imageStr should start with /uploads/...
  }

  // Refresh data
  Future<void> _refreshData() async {
    HapticFeedback.lightImpact();
    await _loadInitialData();
  }

  // Navigate to scan page
  void _selectScanOption(String option) {
    try {
      HapticFeedback.selectionClick();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraScanPage(scanType: option),
        ),
      ).catchError((error) {
        if (mounted) {
          _showSnackBar('Unable to open camera. Please try again.');
        }
      });
    } catch (error) {
      _showSnackBar('Unable to open scanner. Please check your permissions.');
    }
  }

  // Navigate to recipe details
  void _openRecipeDetails(Map<String, dynamic> recipe) {
    try {
      HapticFeedback.selectionClick();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecipeDetailsPage(recipe: recipe),
        ),
      ).catchError((error) {
        if (mounted) {
          _showSnackBar('Unable to open recipe details.');
        }
      });
    } catch (error) {
      _showSnackBar('Error opening recipe details.');
    }
  }

  // Navigate to search page
  void _openSearch() {
    try {
      HapticFeedback.selectionClick();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SearchPage(),
        ),
      ).catchError((error) {
        if (mounted) {
          _showSnackBar('Unable to open search.');
        }
      });
    } catch (error) {
      _showSnackBar('Error opening search.');
    }
  }

  // Show snackbar message
  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.error,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  // Handle category selection
  void _selectCategory(String categoryName) {
    if (_selectedCategory != categoryName) {
      HapticFeedback.selectionClick();
      setState(() {
        _selectedCategory = categoryName;
      });
      _fadeController.reset();
      _fadeController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    return Container(
      decoration: AppTheme.backgroundGradientDecoration(),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: AppTheme.primaryDarkGreen,
          backgroundColor: AppTheme.surfaceWhite,
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return _buildMainContent();
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppTheme.primaryDarkGreen,
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            'Loading recipes...',
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.error,
            ),
            const SizedBox(height: 16),
            const Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error occurred',
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryDarkGreen,
                foregroundColor: AppTheme.surfaceWhite,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeSection(),
            const SizedBox(height: 32),
            _buildQuickActions(),
            const SizedBox(height: 32),
            _buildCategoriesSection(),
            const SizedBox(height: 24),
            _buildRecipesHeader(),
            const SizedBox(height: 20),
            _buildRecipesGrid(),
            const SizedBox(height: 100), // Bottom padding for navigation
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.primaryGradientDecoration(
        borderRadius: BorderRadius.circular(20),
        elevation: 15,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Discover Filipino Recipes',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppTheme.surfaceWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Explore authentic dishes and find your next favorite meal',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.surfaceWhite.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.surfaceWhite.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.restaurant_menu,
              color: AppTheme.surfaceWhite,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickAction(
            'Scan Food',
            Icons.restaurant,
            AppTheme.primaryDarkGreen,
            () => _selectScanOption('Food'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildQuickAction(
            'Scan Ingredients',
            Icons.eco,
            Colors.orange,
            () => _selectScanOption('Ingredient'),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: AppTheme.surfaceWhite, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Categories',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              final isSelected = _selectedCategory == category['name'];
              
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: GestureDetector(
                  key: ValueKey(category['id']),
                  onTap: () => _selectCategory(category['name']),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryDarkGreen : AppTheme.surfaceWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryDarkGreen : AppTheme.textDisabled,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: AppTheme.primaryDarkGreen.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ] : [
                        BoxShadow(
                          color: AppTheme.textPrimary.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          category['icon'],
                          color: isSelected ? AppTheme.surfaceWhite : AppTheme.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          category['name'],
                          style: TextStyle(
                            color: isSelected ? AppTheme.surfaceWhite : AppTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecipesHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Featured Recipes',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          children: [
            Text(
              '${filteredRecipes.length} recipes',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _openSearch,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryDarkGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.search,
                  color: AppTheme.primaryDarkGreen,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecipesGrid() {
    if (filteredRecipes.isEmpty) {
      return _buildEmptyRecipesState();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 16,
          mainAxisSpacing: 20,
        ),
        itemCount: filteredRecipes.length,
        itemBuilder: (context, index) {
          final recipe = filteredRecipes[index];
          return _buildRecipeCard(recipe, index);
        },
      ),
    );
  }

  Widget _buildEmptyRecipesState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu_outlined,
            size: 64,
            color: AppTheme.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No recipes found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try selecting a different category',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe, int index) {
    final recipeType = recipe['type'] ?? 'Food';
    List<Color> gradientColors;
    IconData recipeIcon;

    // Set colors and icons based on recipe type using theme colors
    switch (recipeType.toLowerCase()) {
      case 'drink':
        gradientColors = [Colors.blue.shade300, Colors.blue.shade600];
        recipeIcon = Icons.local_drink;
        break;
      case 'snack':
        gradientColors = [AppTheme.secondaryLightGreen, AppTheme.primaryDarkGreen];
        recipeIcon = Icons.local_cafe;
        break;
      default:
        gradientColors = [AppTheme.secondaryLightGreen, AppTheme.primaryDarkGreen];
        recipeIcon = Icons.restaurant;
        break;
    }

    return Hero(
      tag: 'recipe-${recipe['id']}-$index',
      child: GestureDetector(
        onTap: () => _openRecipeDetails(recipe),
        child: Container(
          key: ValueKey('${recipe['id']}_$index'),
          decoration: AppTheme.cardDecoration(elevation: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Recipe Image
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Display recipe image or gradient fallback
                      recipe['image'] != null && recipe['image'].toString().isNotEmpty
                          ? Image.network(
                              recipe['image'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback to gradient if image fails to load
                                return Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: gradientColors,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      recipeIcon,
                                      size: 50,
                                      color: AppTheme.surfaceWhite.withOpacity(0.8),
                                    ),
                                  ),
                                );
                              },
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: gradientColors,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  recipeIcon,
                                  size: 50,
                                  color: AppTheme.surfaceWhite.withOpacity(0.8),
                                ),
                              ),
                            ),
                      // Difficulty badge
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceWhite.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            recipe['difficulty'] ?? 'Medium',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      // Rating badge
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, size: 12, color: AppTheme.surfaceWhite),
                              const SizedBox(width: 2),
                              Text(
                                (recipe['rating'] ?? 4.5).toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.surfaceWhite,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Recipe name
                    Text(
                      recipe['name'] ?? 'Unknown Recipe',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        height: 1.15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    
                    // Creator name (clickable)
                    GestureDetector(
                      onTap: () {
                        final creatorId = recipe['creatorId'] ?? recipe['creator_id'];
                        if (creatorId != null) {
                          HapticFeedback.selectionClick();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserProfilePage(
                                userId: creatorId.toString(),
                                userName: recipe['creator'],
                              ),
                            ),
                          );
                        }
                      },
                      child: Text(
                        recipe['creator'] ?? 'Unknown Chef',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                          fontSize: 10,
                          height: 1.1,
                          decoration: TextDecoration.underline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 6),
                    
                    // Time and Type info
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 12, color: AppTheme.textSecondary),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            recipe['time'] ?? '30 mins',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryDarkGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            recipeType,
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppTheme.primaryDarkGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    
                    // Serves and favorite
                    Row(
                      children: [
                        Icon(Icons.people, size: 12, color: AppTheme.textSecondary),
                        const SizedBox(width: 3),
                        Text(
                          'Serves ${recipe['serves'] ?? 4}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppTheme.textSecondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Icon(
                            Icons.favorite_border,
                            size: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Compatibility class for backward compatibility
class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomePage();
  }
}