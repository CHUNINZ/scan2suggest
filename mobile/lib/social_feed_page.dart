import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'recipe_details_page.dart';
import 'user_profile_page.dart';
import 'app_theme.dart';
import 'services/api_service.dart';
import 'config/api_config.dart';

class SocialFeedPage extends StatefulWidget {
  const SocialFeedPage({super.key});

  @override
  State<SocialFeedPage> createState() => _SocialFeedPageState();
}

class _SocialFeedPageState extends State<SocialFeedPage> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _recipes = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentPage = 1;
  bool _hasMorePages = true;
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadFeed();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && _hasMorePages) {
        _loadMoreRecipes();
      }
    }
  }

  Future<void> _loadFeed() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _currentPage = 1;
      });

      final response = await ApiService.getSocialFeed(page: 1, limit: 10);

      if (response['success'] == true && mounted) {
        final recipes = response['recipes'] as List? ?? [];
        final pagination = response['pagination'] as Map<String, dynamic>? ?? {};
        
        setState(() {
          _recipes = recipes.map((recipe) => _transformRecipe(recipe)).toList();
          _hasMorePages = pagination['page'] < pagination['pages'];
          _isLoading = false;
        });
      } else {
        throw Exception(response['message'] ?? 'Failed to load feed');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _loadMoreRecipes() async {
    if (_isLoading || !_hasMorePages) return;

    try {
      setState(() {
        _isLoading = true;
      });

      final nextPage = _currentPage + 1;
      final response = await ApiService.getSocialFeed(page: nextPage, limit: 10);

      if (response['success'] == true && mounted) {
        final recipes = response['recipes'] as List? ?? [];
        final pagination = response['pagination'] as Map<String, dynamic>? ?? {};
        
        setState(() {
          _recipes.addAll(recipes.map((recipe) => _transformRecipe(recipe)).toList());
          _currentPage = nextPage;
          _hasMorePages = pagination['page'] < pagination['pages'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _transformRecipe(dynamic recipe) {
    final creator = recipe['creator'];
    final creatorId = creator is Map ? (creator['_id'] ?? creator['id']) : creator;
    final creatorName = creator is Map ? creator['name'] : 'Unknown';
    final creatorImage = creator is Map ? creator['profileImage'] : null;
    
    final imagesList = recipe['images'] as List? ?? [];
    final firstImage = imagesList.isNotEmpty ? imagesList[0] : null;
    
    final ingredientsList = recipe['ingredients'] as List? ?? [];
    final ingredientNames = ingredientsList.map((ing) {
      if (ing is String) return ing;
      if (ing is Map) return ing['name'] ?? 'Unknown ingredient';
      return ing.toString();
    }).toList();
    
    final instructionsList = recipe['instructions'] as List? ?? [];
    final instructionSteps = instructionsList.map((inst) {
      if (inst is String) return inst;
      if (inst is Map) return inst['instruction'] ?? inst['step'] ?? 'Step';
      return inst.toString();
    }).toList();
    
    return {
      'id': recipe['_id'] ?? recipe['id'],
      'name': recipe['title'] ?? 'Untitled',
      'description': recipe['description'] ?? '',
      'creator': creatorName,
      'creatorId': creatorId,
      'creatorImage': creatorImage,
      'image': firstImage,
      'type': recipe['category'] ?? 'Food',
      'time': '${(recipe['prepTime'] ?? 0) + (recipe['cookTime'] ?? 0)} mins',
      'ingredients': ingredientNames,
      'steps': instructionSteps,
      'likesCount': recipe['likesCount'] ?? 0,
      'rating': (recipe['averageRating'] ?? 0).toDouble(),
      'isLiked': recipe['isLiked'] ?? false,
      'isBookmarked': recipe['isBookmarked'] ?? false,
      'createdAt': recipe['createdAt'],
    };
  }

  String? _getFullImageUrl(dynamic image) {
    if (image == null || image.toString().isEmpty) return null;
    
    final imageStr = image.toString();
    
    if (imageStr.startsWith('http://') || imageStr.startsWith('https://')) {
      return imageStr;
    }
    
    final baseUrl = ApiConfig.safeBaseUrl.replaceAll('/api', '');
    return '$baseUrl$imageStr';
  }

  String _getTimeAgo(dynamic createdAt) {
    if (createdAt == null) return 'Recently';
    
    try {
      final date = DateTime.parse(createdAt.toString());
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays > 7) {
        return '${(difference.inDays / 7).floor()}w ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Recently';
    }
  }

  Future<void> _refreshFeed() async {
    HapticFeedback.lightImpact();
    await _loadFeed();
  }

  void _openRecipeDetails(Map<String, dynamic> recipe) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeDetailsPage(recipe: recipe),
      ),
    );
  }

  void _openUserProfile(Map<String, dynamic> recipe) {
    final creatorId = recipe['creatorId'];
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
  }

  Future<void> _toggleLike(Map<String, dynamic> recipe) async {
    HapticFeedback.lightImpact();
    
    try {
      final recipeId = recipe['id'];
      if (recipeId == null) return;
      
      final response = await ApiService.likeRecipe(recipeId.toString());
      
      if (response['success'] == true && mounted) {
        setState(() {
          // Update the recipe in the list
          final index = _recipes.indexWhere((r) => r['id'] == recipeId);
          if (index != -1) {
            _recipes[index]['isLiked'] = response['isLiked'] ?? !_recipes[index]['isLiked'];
            _recipes[index]['likesCount'] = response['likesCount'] ?? _recipes[index]['likesCount'];
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['isLiked'] == true ? '❤️ Liked!' : 'Unliked'),
            backgroundColor: response['isLiked'] == true ? Colors.red : Colors.grey[700],
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _toggleBookmark(Map<String, dynamic> recipe) async {
    HapticFeedback.lightImpact();
    
    try {
      final recipeId = recipe['id'];
      if (recipeId == null) return;
      
      final response = await ApiService.bookmarkRecipe(recipeId.toString());
      
      if (response['success'] == true && mounted) {
        setState(() {
          // Update the recipe in the list
          final index = _recipes.indexWhere((r) => r['id'] == recipeId);
          if (index != -1) {
            _recipes[index]['isBookmarked'] = response['isBookmarked'] ?? !_recipes[index]['isBookmarked'];
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['isBookmarked'] == true ? '🔖 Bookmarked!' : 'Removed bookmark'),
            backgroundColor: response['isBookmarked'] == true ? AppTheme.primaryDarkGreen : Colors.grey[700],
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundOffWhite,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _recipes.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryDarkGreen),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Error loading feed',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadFeed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryDarkGreen,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Retry', style: TextStyle(color: AppTheme.surfaceWhite)),
            ),
          ],
        ),
      );
    }

    if (_recipes.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshFeed,
        color: AppTheme.primaryDarkGreen,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.rss_feed,
                    size: 64,
                    color: AppTheme.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No recipes in feed',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Follow users to see their recipes here!',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '⬇️ Pull down to refresh',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary.withOpacity(0.5),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshFeed,
      color: AppTheme.primaryDarkGreen,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 16, bottom: 100),
        itemCount: _recipes.length + (_hasMorePages ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _recipes.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: AppTheme.primaryDarkGreen),
              ),
            );
          }
          return _buildFeedCard(_recipes[index]);
        },
      ),
    );
  }

  Widget _buildFeedCard(Map<String, dynamic> recipe) {
    final recipeImageUrl = _getFullImageUrl(recipe['image']);
    final creatorImageUrl = _getFullImageUrl(recipe['creatorImage']);
    
    return GestureDetector(
      onTap: () => _openRecipeDetails(recipe),
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        decoration: AppTheme.cardDecoration(elevation: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Header with creator info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    _openUserProfile(recipe);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.secondaryLightGreen,
                    backgroundImage: creatorImageUrl != null ? NetworkImage(creatorImageUrl) : null,
                    child: creatorImageUrl == null
                        ? Text(
                            recipe['creator']?.toString().isNotEmpty == true
                                ? recipe['creator'][0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.surfaceWhite,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _openUserProfile(recipe);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe['creator'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          _getTimeAgo(recipe['createdAt']),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Recipe image
          recipeImageUrl != null
              ? Image.network(
                  recipeImageUrl,
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: double.infinity,
                      height: 250,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.secondaryLightGreen, AppTheme.primaryDarkGreen],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.restaurant, size: 60, color: AppTheme.surfaceWhite),
                      ),
                    );
                  },
                )
              : Container(
                  width: double.infinity,
                  height: 250,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.secondaryLightGreen, AppTheme.primaryDarkGreen],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.restaurant, size: 60, color: AppTheme.surfaceWhite),
                  ),
                ),
          
          // Recipe info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe['name'] ?? 'Untitled',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (recipe['description']?.toString().isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(
                    recipe['description'],
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary.withOpacity(0.8),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                // Action buttons row
                Row(
                  children: [
                    // Like button
                    IconButton(
                      onPressed: () => _toggleLike(recipe),
                      icon: Icon(
                        recipe['isLiked'] == true ? Icons.favorite : Icons.favorite_border,
                        color: recipe['isLiked'] == true ? Colors.red : AppTheme.textSecondary,
                        size: 24,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${recipe['likesCount']}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Bookmark button
                    IconButton(
                      onPressed: () => _toggleBookmark(recipe),
                      icon: Icon(
                        recipe['isBookmarked'] == true ? Icons.bookmark : Icons.bookmark_border,
                        color: recipe['isBookmarked'] == true ? AppTheme.primaryDarkGreen : AppTheme.textSecondary,
                        size: 24,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 20),
                    // Time info
                    Icon(Icons.access_time, size: 16, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      recipe['time'] ?? '30 mins',
                      style: const TextStyle(
                        fontSize: 13,
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
    );
  }
}

