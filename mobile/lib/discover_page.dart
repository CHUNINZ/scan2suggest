import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'user_profile_page.dart';
import 'app_theme.dart';
import 'services/api_service.dart';
import 'config/api_config.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentPage = 1;
  bool _hasMorePages = true;
  final ScrollController _scrollController = ScrollController();
  final Set<String> _followingUsers = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
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
        _loadMoreUsers();
      }
    }
  }

  Future<void> _loadUsers() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _currentPage = 1;
      });

      final response = await ApiService.discoverUsers(page: 1, limit: 20);

      if (response['success'] == true && mounted) {
        final users = response['users'] as List? ?? [];
        final pagination = response['pagination'] as Map<String, dynamic>? ?? {};
        
        setState(() {
          _users = users.map((user) => _transformUser(user)).toList();
          _hasMorePages = pagination['page'] < pagination['pages'];
          _isLoading = false;
        });
      } else {
        throw Exception(response['message'] ?? 'Failed to load users');
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

  Future<void> _loadMoreUsers() async {
    if (_isLoading || !_hasMorePages) return;

    try {
      setState(() {
        _isLoading = true;
      });

      final nextPage = _currentPage + 1;
      final response = await ApiService.discoverUsers(page: nextPage, limit: 20);

      if (response['success'] == true && mounted) {
        final users = response['users'] as List? ?? [];
        final pagination = response['pagination'] as Map<String, dynamic>? ?? {};
        
        setState(() {
          _users.addAll(users.map((user) => _transformUser(user)).toList());
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

  Map<String, dynamic> _transformUser(dynamic user) {
    return {
      'id': user['_id'] ?? user['id'],
      'name': user['name'] ?? 'Unknown User',
      'profileImage': user['profileImage'],
      'bio': user['bio'] ?? '',
      'stats': user['stats'],
      'recipesCount': user['stats']?['recipesCreated'] ?? 0,
      'followersCount': user['stats']?['followersCount'] ?? 0,
      'followingCount': user['stats']?['followingCount'] ?? 0,
      'totalLikes': user['stats']?['totalLikes'] ?? 0,
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

  Future<void> _refreshUsers() async {
    HapticFeedback.lightImpact();
    await _loadUsers();
  }

  void _openUserProfile(Map<String, dynamic> user) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfilePage(
          userId: user['id'].toString(),
          userName: user['name'],
        ),
      ),
    );
  }

  Future<void> _toggleFollow(String userId) async {
    final isCurrentlyFollowing = _followingUsers.contains(userId);
    
    // Optimistic update
    setState(() {
      if (isCurrentlyFollowing) {
        _followingUsers.remove(userId);
      } else {
        _followingUsers.add(userId);
      }
    });
    
    HapticFeedback.lightImpact();
    
    try {
      final response = await ApiService.followUser(userId);
      
      if (response['success'] == true && mounted) {
        final isFollowing = response['isFollowing'] ?? false;
        
        setState(() {
          if (isFollowing) {
            _followingUsers.add(userId);
          } else {
            _followingUsers.remove(userId);
          }
        });
        
        // Update follower count in user list
        final userIndex = _users.indexWhere((u) => u['id'] == userId);
        if (userIndex != -1 && response['followersCount'] != null) {
          setState(() {
            _users[userIndex]['followersCount'] = response['followersCount'];
          });
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFollowing ? '✓ Following user' : 'Unfollowed'),
            backgroundColor: isFollowing ? Colors.green : Colors.grey[700],
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // Revert on error
        setState(() {
          if (isCurrentlyFollowing) {
            _followingUsers.add(userId);
          } else {
            _followingUsers.remove(userId);
          }
        });
        throw Exception(response['message'] ?? 'Failed to follow/unfollow user');
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          if (isCurrentlyFollowing) {
            _followingUsers.add(userId);
          } else {
            _followingUsers.remove(userId);
          }
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

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundOffWhite,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _users.isEmpty) {
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
              'Error loading users',
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
              onPressed: _loadUsers,
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

    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: AppTheme.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No users to discover',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'re already following everyone!',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshUsers,
      color: AppTheme.primaryDarkGreen,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: AppTheme.primaryGradientDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.explore, color: AppTheme.surfaceWhite, size: 32),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Discover Users',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.surfaceWhite,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Find new people to follow and discover amazing recipes',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.surfaceWhite.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == _users.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(color: AppTheme.primaryDarkGreen),
                      ),
                    );
                  }
                  return _buildUserCard(_users[index]);
                },
                childCount: _users.length + (_hasMorePages ? 1 : 0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final profileImageUrl = _getFullImageUrl(user['profileImage']);
    final userId = user['id'].toString();
    final isFollowing = _followingUsers.contains(userId);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AppTheme.cardDecoration(elevation: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                // Profile picture
                GestureDetector(
                  onTap: () => _openUserProfile(user),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primaryDarkGreen.withOpacity(0.2),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: AppTheme.secondaryLightGreen,
                      backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
                      child: profileImageUrl == null
                          ? Text(
                              user['name']?.toString().isNotEmpty == true
                                  ? user['name'][0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.surfaceWhite,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // User info
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openUserProfile(user),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user['name'] ?? 'Unknown User',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (user['bio']?.toString().isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            user['bio'],
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary.withOpacity(0.8),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                
                // Follow button
                SizedBox(
                  width: 100,
                  child: ElevatedButton(
                    onPressed: () => _toggleFollow(userId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowing ? Colors.grey[300] : AppTheme.primaryDarkGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: isFollowing ? 0 : 2,
                    ),
                    child: Text(
                      isFollowing ? 'Following' : 'Follow',
                      style: TextStyle(
                        color: isFollowing ? AppTheme.textPrimary : AppTheme.surfaceWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Stats
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundOffWhite,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn(
                    user['recipesCount'].toString(),
                    'Recipes',
                    Icons.restaurant_menu,
                  ),
                  Container(width: 1, height: 30, color: AppTheme.textDisabled),
                  _buildStatColumn(
                    user['followersCount'].toString(),
                    'Followers',
                    Icons.people,
                  ),
                  Container(width: 1, height: 30, color: AppTheme.textDisabled),
                  _buildStatColumn(
                    user['totalLikes'].toString(),
                    'Likes',
                    Icons.favorite,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryDarkGreen, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

