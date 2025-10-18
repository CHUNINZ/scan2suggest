import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/api_service.dart';
import 'recipe_from_scan_page.dart';

class RecipeSuggestionsPage extends StatefulWidget {
  final List<Map<String, dynamic>> detectedIngredients;
  final List<Map<String, dynamic>>? recipeSuggestions;
  final Map<String, dynamic>? initialRecipe;

  const RecipeSuggestionsPage({
    super.key,
    required this.detectedIngredients,
    this.recipeSuggestions,
    this.initialRecipe,
  });

  @override
  State<RecipeSuggestionsPage> createState() => _RecipeSuggestionsPageState();
}

class _RecipeSuggestionsPageState extends State<RecipeSuggestionsPage>
    with TickerProviderStateMixin {
  
  List<Map<String, dynamic>> _recipeSuggestions = [];
  bool _isLoading = false;
  String? _error;
  String _sortBy = 'match'; // match, time, difficulty
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Initialize with provided suggestions or load them
    if (widget.recipeSuggestions != null) {
      _recipeSuggestions = List.from(widget.recipeSuggestions!);
      _sortRecipes();
      _animationController.forward();
    } else if (widget.initialRecipe != null) {
      _recipeSuggestions = [widget.initialRecipe!];
      _loadMoreSuggestions();
    } else {
      _loadRecipeSuggestions();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipeSuggestions() async {
    if (widget.detectedIngredients.isEmpty) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final result = await ApiService.getRecipeSuggestions(
        ingredients: widget.detectedIngredients,
      );

      if (result['success'] == true) {
        setState(() {
          _recipeSuggestions = List<Map<String, dynamic>>.from(
            result['recipeSuggestions'] ?? []
          );
        });
        _sortRecipes();
        _animationController.forward();
      } else {
        throw Exception(result['message'] ?? 'Failed to get recipe suggestions');
      }
      
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreSuggestions() async {
    try {
      final result = await ApiService.getRecipeSuggestions(
        ingredients: widget.detectedIngredients,
      );

      if (result['success'] == true) {
        final newSuggestions = List<Map<String, dynamic>>.from(
          result['recipeSuggestions'] ?? []
        );
        
        // Merge with existing, avoiding duplicates
        final existingNames = _recipeSuggestions.map((r) => r['name']).toSet();
        final uniqueNew = newSuggestions.where((r) => !existingNames.contains(r['name'])).toList();
        
        setState(() {
          _recipeSuggestions.addAll(uniqueNew);
        });
        _sortRecipes();
      }
    } catch (e) {
      // Silently handle errors for additional suggestions
    }
  }

  void _sortRecipes() {
    setState(() {
      switch (_sortBy) {
        case 'match':
          _recipeSuggestions.sort((a, b) {
            final aScore = (a['matchScore'] ?? 0.0) as double;
            final bScore = (b['matchScore'] ?? 0.0) as double;
            return bScore.compareTo(aScore);
          });
          break;
        case 'time':
          _recipeSuggestions.sort((a, b) {
            final aTime = a['cookTime'] ?? 30;
            final bTime = b['cookTime'] ?? 30;
            return aTime.compareTo(bTime);
          });
          break;
        case 'difficulty':
          _recipeSuggestions.sort((a, b) {
            final difficultyOrder = {'Easy': 1, 'Medium': 2, 'Hard': 3};
            final aDiff = difficultyOrder[a['difficulty']] ?? 2;
            final bDiff = difficultyOrder[b['difficulty']] ?? 2;
            return aDiff.compareTo(bDiff);
          });
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Recipe Suggestions'),
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
              _sortRecipes();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'match',
                child: Row(
                  children: [
                    Icon(Icons.star, size: 20),
                    SizedBox(width: 8),
                    Text('Best Match'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'time',
                child: Row(
                  children: [
                    Icon(Icons.timer, size: 20),
                    SizedBox(width: 8),
                    Text('Cooking Time'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'difficulty',
                child: Row(
                  children: [
                    Icon(Icons.trending_up, size: 20),
                    SizedBox(width: 8),
                    Text('Difficulty'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _recipeSuggestions.isEmpty) {
      return _buildLoadingState();
    } else if (_error != null && _recipeSuggestions.isEmpty) {
      return _buildErrorState();
    } else {
      return _buildSuggestionsState();
    }
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Finding recipe suggestions...',
            style: TextStyle(fontSize: 16),
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
              'Failed to Load Suggestions',
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
              onPressed: _loadRecipeSuggestions,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsState() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // Ingredients summary
          _buildIngredientsSummary(),
          
          // Recipe suggestions list
          Expanded(
            child: _recipeSuggestions.isEmpty
                ? _buildEmptyState()
                : _buildRecipesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsSummary() {
    return Container(
      margin: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.eco, color: Colors.green.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Your Ingredients (${widget.detectedIngredients.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.detectedIngredients.map((ingredient) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  ingredient['name'] ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 24),
            Text(
              'No Recipe Suggestions',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'We couldn\'t find recipes matching your ingredients. Try scanning more ingredients or explore our recipe collection.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadRecipeSuggestions,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Suggestions'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipesList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _recipeSuggestions.length,
      itemBuilder: (context, index) {
        final recipe = _recipeSuggestions[index];
        return _buildRecipeCard(recipe, index);
      },
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe, int index) {
    final matchedIngredients = recipe['matchedIngredients'] as List? ?? [];
    final missingIngredients = recipe['missingIngredients'] as List? ?? [];
    final matchScore = (recipe['matchScore'] ?? 0.0) as double;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 3,
        shadowColor: Colors.black12,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _viewRecipeDetails(recipe),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recipe header
                Row(
                  children: [
                    // Recipe image or icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: recipe['image'] != null 
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                recipe['image'],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => 
                                    Icon(Icons.restaurant_menu, 
                                         color: Colors.orange.shade600, size: 40),
                              ),
                            )
                          : Icon(Icons.restaurant_menu, 
                                 color: Colors.orange.shade600, size: 40),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Recipe info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recipe['name'] ?? 'Unknown Recipe',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
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
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              _buildInfoChip(
                                Icons.timer, 
                                '${recipe['cookTime'] ?? 30}m',
                                Colors.blue,
                              ),
                              _buildInfoChip(
                                Icons.people, 
                                '${recipe['servings'] ?? 4}',
                                Colors.green,
                              ),
                              _buildInfoChip(
                                Icons.signal_cellular_alt, 
                                recipe['difficulty'] ?? 'Medium',
                                Colors.purple,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Match score
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star, color: Colors.orange.shade600, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${(matchScore * 100).toStringAsFixed(0)}% ingredient match',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Matched ingredients
                if (matchedIngredients.isNotEmpty) ...[
                  Text(
                    'Matched ingredients:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: matchedIngredients.map((ingredient) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, size: 12, color: Colors.green.shade600),
                            const SizedBox(width: 4),
                            Text(
                              ingredient.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
                
                // Missing ingredients
                if (missingIngredients.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Additional ingredients needed:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: missingIngredients.take(5).map((ingredient) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 12, color: Colors.red.shade600),
                            const SizedBox(width: 4),
                            Text(
                              ingredient.toString(),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  if (missingIngredients.length > 5) ...[
                    const SizedBox(height: 4),
                    Text(
                      '+${missingIngredients.length - 5} more ingredients',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
                
                const SizedBox(height: 16),
                
                // Action button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _viewRecipeDetails(recipe),
                    icon: const Icon(Icons.restaurant_menu),
                    label: const Text('View Recipe & Instructions'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
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

  Future<void> _viewRecipeDetails(Map<String, dynamic> recipe) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Get full recipe details
      final result = await ApiService.getRecipeDetails(recipe['name']);
      
      // Hide loading
      Navigator.pop(context);

      if (result['success'] == true && result['recipe'] != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeFromScanPage(
              foodName: recipe['name'],
              recipe: result['recipe'],
              scanId: '',
            ),
          ),
        );
      } else {
        throw Exception('Failed to load recipe details');
      }
      
    } catch (e) {
      // Hide loading if still showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading recipe: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
