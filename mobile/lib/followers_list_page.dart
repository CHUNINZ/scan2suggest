import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'user_profile_page.dart';
import 'app_theme.dart';
import 'services/api_service.dart';
import 'config/api_config.dart';

class FollowersListPage extends StatefulWidget {
  final String userId;
  final String userName;
  final bool isFollowers; // true for followers, false for following

  const FollowersListPage({
    super.key,
    required this.userId,
    required this.userName,
    required this.isFollowers,
  });

  @override
  State<FollowersListPage> createState() => _FollowersListPageState();
}

class _FollowersListPageState extends State<FollowersListPage> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentPage = 1;
  bool _hasMorePages = true;
  final ScrollController _scrollController = ScrollController();

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

      final response = widget.isFollowers
          ? await ApiService.getFollowers(widget.userId, page: 1, limit: 20)
          : await ApiService.getFollowing(widget.userId, page: 1, limit: 20);

      if (response['success'] == true && mounted) {
        final users = response[widget.isFollowers ? 'followers' : 'following'] as List? ?? [];
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
      final response = widget.isFollowers
          ? await ApiService.getFollowers(widget.userId, page: nextPage, limit: 20)
          : await ApiService.getFollowing(widget.userId, page: nextPage, limit: 20);

      if (response['success'] == true && mounted) {
        final users = response[widget.isFollowers ? 'followers' : 'following'] as List? ?? [];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundOffWhite,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isFollowers ? 'Followers' : 'Following',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.userName,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
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
              widget.isFollowers ? Icons.people_outline : Icons.person_add_outlined,
              size: 64,
              color: AppTheme.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              widget.isFollowers ? 'No followers yet' : 'Not following anyone',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isFollowers 
                  ? 'Start sharing recipes to get followers!'
                  : 'Discover users and start following',
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
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _users.length + (_hasMorePages ? 1 : 0),
        itemBuilder: (context, index) {
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
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final profileImageUrl = _getFullImageUrl(user['profileImage']);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration(elevation: 4),
      child: InkWell(
        onTap: () => _openUserProfile(user),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Profile picture
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryDarkGreen.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.secondaryLightGreen,
                  backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
                  child: profileImageUrl == null
                      ? Text(
                          user['name']?.toString().isNotEmpty == true
                              ? user['name'][0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.surfaceWhite,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user['name'] ?? 'Unknown User',
                      style: const TextStyle(
                        fontSize: 16,
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.restaurant_menu, size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${user['recipesCount']} recipes',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.people, size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${user['followersCount']} followers',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Arrow icon
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppTheme.textSecondary.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

