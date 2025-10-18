import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'recipe_details_page.dart';
import 'app_theme.dart';
import 'services/api_service.dart';
import 'config/api_config.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;
  final String? userName;

  const UserProfilePage({
    super.key,
    required this.userId,
    this.userName,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  bool _showRecipes = true;
  
  // User data from backend
  Map<String, dynamic>? _userProfile;
  List<Map<String, dynamic>> _userRecipes = [];
  
  // Loading states
  bool _isLoadingProfile = true;
  bool _isLoadingRecipes = true;
  bool _isFollowing = false;
  bool _isLoadingFollow = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    await Future.wait([
      _loadUserProfile(),
      _loadUserRecipes(),
    ]);
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() {
        _isLoadingProfile = true;
        _hasError = false;
      });

      // Get user profile (need to add this API endpoint)
      final response = await ApiService.getRecipes(
        creatorId: widget.userId,
        limit: 1,
      );

      if (response['success'] == true && mounted) {
        final recipes = response['recipes'] as List? ?? [];
        if (recipes.isNotEmpty) {
          final recipe = recipes[0];
          final creator = recipe['creator'];
          
          setState(() {
            _userProfile = {
              'id': widget.userId,
              'name': creator is Map ? creator['name'] : widget.userName ?? 'User',
              'profileImage': creator is Map ? creator['profileImage'] : null,
              'bio': '',
              'location': '',
              'followersCount': creator is Map ? creator['followersCount'] : 0,
              'followingCount': creator is Map ? creator['followingCount'] : 0,
            };
            _isLoadingProfile = false;
          });
        } else {
          // No recipes, create basic profile
          setState(() {
            _userProfile = {
              'id': widget.userId,
              'name': widget.userName ?? 'User',
              'profileImage': null,
              'bio': '',
              'location': '',
              'followersCount': 0,
              'followingCount': 0,
            };
            _isLoadingProfile = false;
          });
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to load user profile');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
          _hasError = true;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _loadUserRecipes() async {
    try {
      setState(() {
        _isLoadingRecipes = true;
      });

      final response = await ApiService.getRecipes(
        creatorId: widget.userId,
        limit: 50,
      );

      if (response['success'] == true && mounted) {
        final recipes = response['recipes'] as List? ?? [];
        
        final transformedRecipes = recipes.map((recipe) {
          final creator = recipe['creator'];
          final creatorName = creator is Map ? creator['name'] : creator?.toString() ?? 'Unknown';
          
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
            'creator': creatorName,
            'type': recipe['category'] ?? 'Food',
            'time': '${(recipe['prepTime'] ?? 0) + (recipe['cookTime'] ?? 0)} mins',
            'image': firstImage,
            'description': recipe['description'] ?? '',
            'ingredients': ingredientNames,
            'steps': instructionSteps,
            'rating': (recipe['averageRating'] ?? 0).toDouble(),
            'likes': recipe['likesCount'] ?? 0,
            'isBookmarked': recipe['isBookmarked'] ?? false,
          };
        }).toList();

        setState(() {
          _userRecipes = transformedRecipes;
          _isLoadingRecipes = false;
        });
      } else {
        throw Exception(response['message'] ?? 'Failed to load recipes');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRecipes = false;
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (_isLoadingFollow) return;

    setState(() {
      _isLoadingFollow = true;
    });

    HapticFeedback.lightImpact();

    try {
      final response = await ApiService.followUser(widget.userId);

      if (response['success'] == true && mounted) {
        setState(() {
          _isFollowing = response['isFollowing'] ?? !_isFollowing;
          _isLoadingFollow = false;
          
          // Update follower count
          if (_userProfile != null) {
            _userProfile!['followersCount'] = response['followersCount'] ?? _userProfile!['followersCount'];
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isFollowing ? '✓ Following ${_userProfile?['name'] ?? 'user'}' : 'Unfollowed'),
            backgroundColor: _isFollowing ? Colors.green : Colors.grey[700],
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception(response['message'] ?? 'Failed to follow/unfollow user');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFollow = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _toggleBookmark(String recipeId, bool isCurrentlyBookmarked) async {
    HapticFeedback.lightImpact();

    try {
      final response = await ApiService.bookmarkRecipe(recipeId);

      if (response['success'] == true && mounted) {
        setState(() {
          // Update the recipe's bookmark status
          final recipeIndex = _userRecipes.indexWhere((r) => r['id'] == recipeId);
          if (recipeIndex != -1) {
            _userRecipes[recipeIndex]['isBookmarked'] = response['isBookmarked'] ?? !isCurrentlyBookmarked;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['isBookmarked'] == true ? '🔖 Recipe saved!' : 'Recipe removed from saved'),
            backgroundColor: response['isBookmarked'] == true ? Colors.green : Colors.grey[700],
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception(response['message'] ?? 'Failed to bookmark recipe');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundOffWhite,
      body: _isLoadingProfile
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryDarkGreen),
            )
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading profile',
                        style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loadUserData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryDarkGreen,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    _buildHeader(),
                    _buildTabBar(),
                    _buildRecipesList(),
                  ],
                ),
    );
  }

  Widget _buildHeader() {
    final profileImageUrl = _getFullImageUrl(_userProfile?['profileImage']);
    
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppTheme.surfaceWhite,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: AppTheme.primaryGradientDecoration(),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Profile picture
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.surfaceWhite, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.textPrimary.withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: AppTheme.surfaceWhite,
                    backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
                    child: profileImageUrl == null
                        ? Text(
                            _userProfile?['name']?.toString().isNotEmpty == true
                                ? _userProfile!['name'][0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryDarkGreen,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                // Name
                Text(
                  _userProfile?['name'] ?? 'User',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.surfaceWhite,
                  ),
                ),
                const SizedBox(height: 8),
                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatItem(
                      _userRecipes.length.toString(),
                      'Recipes',
                    ),
                    Container(
                      height: 24,
                      width: 1,
                      color: AppTheme.surfaceWhite.withOpacity(0.3),
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    _buildStatItem(
                      (_userProfile?['followersCount'] ?? 0).toString(),
                      'Followers',
                    ),
                    Container(
                      height: 24,
                      width: 1,
                      color: AppTheme.surfaceWhite.withOpacity(0.3),
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    _buildStatItem(
                      (_userProfile?['followingCount'] ?? 0).toString(),
                      'Following',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          color: AppTheme.surfaceWhite,
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoadingFollow ? null : _toggleFollow,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isFollowing ? Colors.grey[300] : AppTheme.primaryDarkGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoadingFollow
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isFollowing ? Icons.check : Icons.person_add,
                          color: _isFollowing ? AppTheme.textPrimary : AppTheme.surfaceWhite,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isFollowing ? 'Following' : 'Follow',
                          style: TextStyle(
                            color: _isFollowing ? AppTheme.textPrimary : AppTheme.surfaceWhite,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.surfaceWhite,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.surfaceWhite.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration(),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showRecipes = true;
                    });
                    HapticFeedback.selectionClick();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _showRecipes ? AppTheme.primaryDarkGreen : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_menu,
                          size: 20,
                          color: _showRecipes ? AppTheme.surfaceWhite : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Recipes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: _showRecipes ? FontWeight.bold : FontWeight.w500,
                            color: _showRecipes ? AppTheme.surfaceWhite : AppTheme.textSecondary,
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
      ),
    );
  }

  Widget _buildRecipesList() {
    if (_isLoadingRecipes) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryDarkGreen),
        ),
      );
    }

    if (_userRecipes.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.restaurant_menu,
                size: 64,
                color: AppTheme.textSecondary.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'No recipes yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This user hasn\'t shared any recipes',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textSecondary.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return _buildRecipeCard(_userRecipes[index]);
          },
          childCount: _userRecipes.length,
        ),
      ),
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe) {
    final gradientColors = _getGradientColors(recipe['type'] ?? 'Food');
    final recipeIcon = _getRecipeIcon(recipe['type'] ?? 'Food');
    final imageUrl = _getFullImageUrl(recipe['image']);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeDetailsPage(recipe: recipe),
          ),
        );
      },
      child: Container(
        decoration: AppTheme.cardDecoration(elevation: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Recipe image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: Container(
                height: 120,
                width: double.infinity,
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
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
                                size: 40,
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
                            size: 40,
                            color: AppTheme.surfaceWhite.withOpacity(0.8),
                          ),
                        ),
                      ),
              ),
            ),

            // Recipe info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      recipe['name'] ?? 'Untitled',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 11, color: AppTheme.textSecondary),
                        const SizedBox(width: 3),
                        Text(
                          recipe['time'] ?? '30 mins',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.favorite, size: 13, color: Colors.red),
                        const SizedBox(width: 3),
                        Text(
                          recipe['likes']?.toString() ?? '0',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _toggleBookmark(
                            recipe['id'],
                            recipe['isBookmarked'] ?? false,
                          ),
                          child: Icon(
                            recipe['isBookmarked'] == true ? Icons.bookmark : Icons.bookmark_border,
                            size: 18,
                            color: recipe['isBookmarked'] == true
                                ? AppTheme.primaryDarkGreen
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
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

  List<Color> _getGradientColors(String type) {
    switch (type.toLowerCase()) {
      case 'dessert':
        return [const Color(0xFFFF6B9D), const Color(0xFFC44569)];
      case 'breakfast':
        return [const Color(0xFFFFA726), const Color(0xFFFB8C00)];
      case 'lunch':
        return [const Color(0xFF66BB6A), const Color(0xFF43A047)];
      case 'dinner':
        return [const Color(0xFF42A5F5), const Color(0xFF1E88E5)];
      default:
        return [AppTheme.secondaryLightGreen, AppTheme.primaryDarkGreen];
    }
  }

  IconData _getRecipeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'dessert':
        return Icons.cake;
      case 'breakfast':
        return Icons.free_breakfast;
      case 'lunch':
        return Icons.lunch_dining;
      case 'dinner':
        return Icons.dinner_dining;
      default:
        return Icons.restaurant;
    }
  }
}

