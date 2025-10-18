import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'recipe_details_page.dart';
import 'edit_profile_screen.dart';
import 'splash_screen.dart';
import 'followers_list_page.dart';
import 'app_theme.dart';
import 'services/api_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with TickerProviderStateMixin {
  bool _showRecipes = true;
  late AnimationController _fadeController;
  late AnimationController _contentFadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _contentFadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Real user data from backend
  Map<String, dynamic>? _userProfile;
  List<Map<String, dynamic>> _userRecipes = [];
  List<Map<String, dynamic>> _likedRecipes = [];
  
  // Loading states
  bool _isLoadingProfile = true;
  bool _isLoadingRecipes = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _contentFadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _contentFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _contentFadeController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    // Load real data from backend
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    // Load profile first to get userId
    await _loadUserProfile();
    
    // Then load recipes using the userId
    await _loadUserRecipes();
    
    // Start animations after data is loaded
    _fadeController.forward();
    _contentFadeController.forward();
    _slideController.forward();
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() {
        _isLoadingProfile = true;
        _hasError = false;
      });

      final response = await ApiService.getCurrentUser();
      
      if (response['success'] == true && mounted) {
        final user = response['user'];
        setState(() {
          _userProfile = {
            'id': user['_id'] ?? user['id'],
            'name': user['name'] ?? 'User',
            'email': user['email'] ?? '',
            'bio': user['bio'] ?? 'Food lover 🍴',
            'location': user['location'] ?? '',
            'profileImageUrl': user['profileImage'],
            'followersCount': (user['followers'] as List?)?.length ?? 0,
            'followingCount': (user['following'] as List?)?.length ?? 0,
            'recipesCount': user['stats']?['recipesCreated'] ?? 0,
            'likesCount': user['stats']?['totalLikes'] ?? 0,
            'joinDate': _formatJoinDate(user['createdAt']),
            'isVerified': user['isVerified'] ?? false,
          };
          _isLoadingProfile = false;
        });
      } else {
        setState(() {
          _isLoadingProfile = false;
          _hasError = true;
          _errorMessage = response['message'] ?? 'Failed to load profile';
        });
      }
    } catch (e) {
      print('❌ Error loading user profile: $e');
      setState(() {
        _isLoadingProfile = false;
        _hasError = true;
        _errorMessage = 'Network error. Please check your connection.';
      });
    }
  }

  Future<void> _loadUserRecipes() async {
    try {
      setState(() {
        _isLoadingRecipes = true;
      });

      // Get current user ID
      final userId = _userProfile?['id'];
      
      if (userId == null) {
        setState(() {
          _isLoadingRecipes = false;
        });
        return;
      }

      // Get both user's own recipes and liked recipes in parallel
      final results = await Future.wait([
        ApiService.getRecipes(
          page: 1,
          limit: 50,
          creatorId: userId,
          sort: 'createdAt',
          order: 'desc',
        ),
        ApiService.getLikedRecipes(),
      ]);

      if (results[0]['success'] == true && results[1]['success'] == true && mounted) {
        final userRecipes = (results[0]['recipes'] as List).cast<Map<String, dynamic>>();
        final likedRecipes = (results[1]['recipes'] as List).cast<Map<String, dynamic>>();

        setState(() {
          _userRecipes = _transformRecipes(userRecipes);
          _likedRecipes = _transformRecipes(likedRecipes);
          _isLoadingRecipes = false;
        });
      } else {
        setState(() {
          _isLoadingRecipes = false;
        });
      }
    } catch (e) {
      print('❌ Error loading recipes: $e');
      setState(() {
        _isLoadingRecipes = false;
      });
    }
  }

  List<Map<String, dynamic>> _transformRecipes(List<Map<String, dynamic>> recipes) {
    return recipes.map((recipe) {
      final prepTime = recipe['prepTime'] ?? 0;
      final cookTime = recipe['cookTime'] ?? 0;
      final totalTime = prepTime + cookTime;
      
      // Extract ingredient names for display
      final ingredientsList = recipe['ingredients'] as List? ?? [];
      final ingredientNames = ingredientsList.map((ing) {
        if (ing is String) return ing;
        if (ing is Map) return ing['name'] ?? 'Unknown ingredient';
        return ing.toString();
      }).toList();
      
      // Extract instruction steps for display
      final instructionsList = recipe['instructions'] as List? ?? [];
      final instructionSteps = instructionsList.map((inst) {
        if (inst is String) return inst;
        if (inst is Map) return inst['instruction'] ?? inst['step'] ?? 'Step';
        return inst.toString();
      }).toList();
      
      return {
        'id': recipe['_id'] ?? recipe['id'],
        'name': recipe['title'] ?? recipe['name'] ?? 'Untitled Recipe',
        'type': _mapCategoryToType(recipe['category'] ?? 'Food'),
        'time': '${totalTime} mins',
        'likes': recipe['likesCount'] ?? (recipe['likes'] as List?)?.length ?? 0,
        'likesCount': recipe['likesCount'] ?? (recipe['likes'] as List?)?.length ?? 0,
        'creator': recipe['creator'] is Map 
            ? recipe['creator']['name'] ?? 'Unknown'
            : _userProfile?['name'] ?? 'Unknown',
        'description': recipe['description'] ?? '',
        'rating': (recipe['averageRating'] ?? 0).toDouble(),
        'serves': recipe['servings'] ?? 4,
        'difficulty': _capitalizeDifficulty(recipe['difficulty'] ?? 'Medium'),
        'category': recipe['category'] ?? 'Main Course',
        'prepTime': prepTime,
        'cookTime': cookTime,
        'ingredients': ingredientNames, // Pass actual list, not count
        'steps': instructionSteps, // Pass actual list, not count
        'isBookmarked': recipe['isBookmarked'] ?? false,
        'image': _getFullImageUrl(recipe['images']?.first),
        'dateCreated': _formatDate(recipe['createdAt']),
      };
    }).toList();
  }

  String _mapCategoryToType(String category) {
    final lowerCategory = category.toLowerCase();
    if (lowerCategory.contains('beverage') || 
        lowerCategory.contains('drink') ||
        lowerCategory.contains('juice')) {
      return 'Drink';
    } else if (lowerCategory.contains('snack') || 
               lowerCategory.contains('appetizer')) {
      return 'Snack';
    }
    return 'Food';
  }

  String _capitalizeDifficulty(String difficulty) {
    if (difficulty.isEmpty) return 'Medium';
    return difficulty[0].toUpperCase() + difficulty.substring(1).toLowerCase();
  }

  String? _getFullImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return null;
    if (imagePath.startsWith('http')) return imagePath;
    return 'http://192.168.194.185:3000$imagePath';
  }

  String _formatJoinDate(String? dateStr) {
    if (dateStr == null) return 'Recently joined';
    try {
      final date = DateTime.parse(dateStr);
      final months = ['January', 'February', 'March', 'April', 'May', 'June',
                     'July', 'August', 'September', 'October', 'November', 'December'];
      return '${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return 'Recently joined';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Recently';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
      } else if (difference.inDays < 365) {
        final months = (difference.inDays / 30).floor();
        return months == 1 ? '1 month ago' : '$months months ago';
      } else {
        final years = (difference.inDays / 365).floor();
        return years == 1 ? '1 year ago' : '$years years ago';
      }
    } catch (e) {
      return 'Recently';
    }
  }

  Future<void> _refreshProfile() async {
    await _loadUserData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _contentFadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _editProfile() async {
    HapticFeedback.lightImpact();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          userProfile: _userProfile ?? {},
          onProfileUpdated: (updatedProfile) {
            setState(() {
              _userProfile = updatedProfile;
            });
          },
        ),
      ),
    );
    
    // Reload profile if edited
    if (result == true) {
      _loadUserProfile();
    }
  }

  void _showShareOptions() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceWhite,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textDisabled,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Share Profile',
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
                _buildShareOption(Icons.share, 'Share', AppTheme.primaryDarkGreen),
                _buildShareOption(Icons.link, 'Copy Link', Colors.blue),
                _buildShareOption(Icons.qr_code, 'QR Code', Colors.purple),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _showSnackBar('Shared via $label', isSuccess: true);
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
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
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

  void _toggleBookmark(String recipeId, bool currentState) async {
    HapticFeedback.lightImpact();
    
    try {
      final response = await ApiService.bookmarkRecipe(recipeId);
      if (response['success'] == true) {
        setState(() {
          // Update bookmark state in user recipes
          final recipeIndex = _userRecipes.indexWhere((recipe) => recipe['id'] == recipeId);
          if (recipeIndex != -1) {
            _userRecipes[recipeIndex]['isBookmarked'] = !currentState;
          }
          
          // Update bookmark state in liked recipes
          final likedIndex = _likedRecipes.indexWhere((recipe) => recipe['id'] == recipeId);
          if (likedIndex != -1) {
            _likedRecipes[likedIndex]['isBookmarked'] = !currentState;
          }
        });
        
        _showSnackBar(
          !currentState ? 'Recipe bookmarked!' : 'Bookmark removed',
          isSuccess: !currentState,
        );
      }
    } catch (e) {
      print('❌ Error toggling bookmark: $e');
      _showSnackBar('Failed to update bookmark', isSuccess: false);
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? AppTheme.success : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _logout() async {
    HapticFeedback.lightImpact();
    
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      try {
        await ApiService.logout();
        
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const SplashScreen(isPostLogout: true),
            ),
            (route) => false,
          );
        }
      } catch (e) {
        print('❌ Logout error: $e');
        _showSnackBar('Failed to logout', isSuccess: false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundOffWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadUserData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryDarkGreen,
                  foregroundColor: AppTheme.surfaceWhite,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoadingProfile) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundOffWhite,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: AppTheme.primaryDarkGreen,
              ),
              const SizedBox(height: 16),
              const Text(
                'Loading profile...',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundOffWhite,
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        color: AppTheme.primaryDarkGreen,
        child: CustomScrollView(
          slivers: [
            _buildProfileHeader(),
            _buildStatsSection(),
            _buildTabBar(),
            _buildRecipesList(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final profile = _userProfile ?? {};
    
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Header actions
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: _showShareOptions,
                        icon: const Icon(Icons.share, color: AppTheme.surfaceWhite),
                      ),
                      const Text(
                        'Profile',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.surfaceWhite,
                        ),
                      ),
                      IconButton(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout, color: AppTheme.surfaceWhite),
                      ),
                    ],
                  ),
                ),
                
                // Profile picture
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.surfaceWhite,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 58,
                    backgroundColor: AppTheme.secondaryLightGreen,
                    backgroundImage: profile['profileImageUrl'] != null 
                        ? NetworkImage(profile['profileImageUrl'])
                        : null,
                    child: profile['profileImageUrl'] == null
                        ? Text(
                            (profile['name'] ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.surfaceWhite,
                            ),
                          )
                        : null,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Name and verification
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      profile['name'] ?? 'User',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.surfaceWhite,
                      ),
                    ),
                    if (profile['isVerified'] == true) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.verified,
                        color: Colors.blue,
                        size: 24,
                      ),
                    ],
                  ],
                ),
                
                const SizedBox(height: 8),
                
                // Bio
                if (profile['bio'] != null && profile['bio'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      profile['bio'],
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.surfaceWhite,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                
                const SizedBox(height: 8),
                
                // Location and join date
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (profile['location'] != null && profile['location'].toString().isNotEmpty) ...[
                      const Icon(Icons.location_on, size: 16, color: AppTheme.surfaceWhite),
                      const SizedBox(width: 4),
                      Text(
                        profile['location'],
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.surfaceWhite,
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
                    const Icon(Icons.calendar_today, size: 16, color: AppTheme.surfaceWhite),
                    const SizedBox(width: 4),
                    Text(
                      'Joined ${profile['joinDate'] ?? 'recently'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.surfaceWhite,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Edit Profile button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _editProfile,
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit Profile'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.surfaceWhite,
                        foregroundColor: AppTheme.primaryDarkGreen,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    final profile = _userProfile ?? {};
    
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _contentFadeAnimation,
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.cardDecoration(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                profile['recipesCount']?.toString() ?? '0',
                'Recipes',
                Icons.restaurant_menu,
              ),
              Container(
                width: 1,
                height: 40,
                color: AppTheme.textDisabled,
              ),
              _buildStatItem(
                profile['followersCount']?.toString() ?? '0',
                'Followers',
                Icons.people,
              ),
              Container(
                width: 1,
                height: 40,
                color: AppTheme.textDisabled,
              ),
              _buildStatItem(
                profile['followingCount']?.toString() ?? '0',
                'Following',
                Icons.person_add,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    final isClickable = label == 'Followers' || label == 'Following';
    final profile = _userProfile ?? {};
    final userId = profile['id'];
    final userName = profile['name'];
    
    Widget statContent = Column(
      children: [
        Icon(icon, color: AppTheme.primaryDarkGreen, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
    
    if (isClickable && userId != null && userName != null) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FollowersListPage(
                userId: userId.toString(),
                userName: userName,
                isFollowers: label == 'Followers',
              ),
            ),
          );
        },
        child: statContent,
      );
    }
    
    return statContent;
  }

  Widget _buildTabBar() {
    return SliverToBoxAdapter(
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceWhite,
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
                          'My Recipes',
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
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showRecipes = false;
                    });
                    HapticFeedback.selectionClick();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: !_showRecipes ? AppTheme.primaryDarkGreen : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.favorite,
                          size: 20,
                          color: !_showRecipes ? AppTheme.surfaceWhite : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Liked',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: !_showRecipes ? FontWeight.bold : FontWeight.w500,
                            color: !_showRecipes ? AppTheme.surfaceWhite : AppTheme.textSecondary,
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
    final recipes = _showRecipes ? _userRecipes : _likedRecipes;
    
    if (_isLoadingRecipes) {
      return SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryDarkGreen,
          ),
        ),
      );
    }
    
    if (recipes.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _showRecipes ? Icons.restaurant_menu : Icons.favorite_border,
                size: 64,
                color: AppTheme.textSecondary.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                _showRecipes ? 'No recipes yet' : 'No liked recipes',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _showRecipes 
                    ? 'Start creating your first recipe!' 
                    : 'Like recipes to see them here',
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
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final recipe = recipes[index];
            return _buildRecipeCard(recipe);
          },
          childCount: recipes.length,
        ),
      ),
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe) {
    final recipeType = recipe['type'] ?? 'Food';
    List<Color> gradientColors;
    IconData recipeIcon;

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

    return GestureDetector(
      onTap: () => _openRecipeDetails(recipe),
      child: Container(
        decoration: AppTheme.cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: Container(
                height: 120,
                width: double.infinity,
                child: recipe['image'] != null && recipe['image'].toString().isNotEmpty
                    ? Image.network(
                        recipe['image'],
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
                            recipe['isBookmarked'] == true
                                ? Icons.bookmark
                                : Icons.bookmark_border,
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
}
