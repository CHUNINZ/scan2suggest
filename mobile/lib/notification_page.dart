import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'camera_scan_page.dart';
import 'app_theme.dart';
import 'services/api_service.dart';
import 'models/notification_model.dart';
import 'package:timeago/timeago.dart' as timeago;

// Notification type enum for better type safety
enum NotificationType {
  like,
  comment,
  follow,
  recipe,
  system,
  share,
}

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage>
    with TickerProviderStateMixin {
  final List<String> _filterOptions = ['All', 'Likes', 'Comments', 'Follows', 'Recipes'];
  String _selectedFilter = 'All';
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  // Notifications from backend
  List<NotificationModel> _allNotifications = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentPage = 1;
  bool _hasMoreData = true;
  final ScrollController _scrollController = ScrollController();

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
    
    _scrollController.addListener(_onScroll);
    _loadNotifications();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoading && _hasMoreData) {
        _loadMoreNotifications();
      }
    }
  }

  Future<void> _loadNotifications({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _hasMoreData = true;
        _allNotifications.clear();
      });
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final response = await ApiService.getNotifications(
        page: _currentPage,
        limit: 20,
        unreadOnly: false,
      );

      if (response['success'] == true) {
        final notifications = (response['notifications'] as List)
            .map((json) => NotificationModel.fromJson(json))
            .toList();

        setState(() {
          if (refresh) {
            _allNotifications = notifications;
          } else {
            _allNotifications.addAll(notifications);
          }
          _isLoading = false;
          _hasError = false;
          
          // Check if there's more data
          final pagination = response['pagination'];
          if (pagination != null) {
            _hasMoreData = pagination['page'] < pagination['pages'];
          } else {
            _hasMoreData = notifications.length >= 20;
          }
        });

        _fadeController.forward();
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = response['message'] ?? 'Failed to load notifications';
        });
      }
    } catch (e) {
      print('❌ Error loading notifications: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Network error. Please check your connection.';
      });
    }
  }

  Future<void> _loadMoreNotifications() async {
    setState(() {
      _currentPage++;
    });
    await _loadNotifications();
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      final response = await ApiService.markNotificationAsRead(notificationId);
      if (response['success'] == true) {
        setState(() {
          final index = _allNotifications.indexWhere((n) => n.id == notificationId);
          if (index != -1) {
            // Create a new notification with updated isRead status
            final oldNotif = _allNotifications[index];
            _allNotifications[index] = NotificationModel(
              id: oldNotif.id,
              recipient: oldNotif.recipient,
              sender: oldNotif.sender,
              type: oldNotif.type,
              title: oldNotif.title,
              message: oldNotif.message,
              relatedRecipe: oldNotif.relatedRecipe,
              data: oldNotif.data,
              isRead: true,
              readAt: DateTime.now(),
              isDeleted: oldNotif.isDeleted,
              deletedAt: oldNotif.deletedAt,
              createdAt: oldNotif.createdAt,
            );
          }
        });
      }
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final response = await ApiService.markAllNotificationsAsRead();
      if (response['success'] == true) {
        setState(() {
          _allNotifications = _allNotifications.map((notif) {
            return NotificationModel(
              id: notif.id,
              recipient: notif.recipient,
              sender: notif.sender,
              type: notif.type,
              title: notif.title,
              message: notif.message,
              relatedRecipe: notif.relatedRecipe,
              data: notif.data,
              isRead: true,
              readAt: DateTime.now(),
              isDeleted: notif.isDeleted,
              deletedAt: notif.deletedAt,
              createdAt: notif.createdAt,
            );
          }).toList();
        });
        
        _showSnackBar('All notifications marked as read', isSuccess: true);
      }
    } catch (e) {
      print('❌ Error marking all as read: $e');
      _showSnackBar('Failed to mark all as read', isSuccess: false);
    }
  }

  // Filter notifications based on selected category
  List<NotificationModel> get _filteredNotifications {
    if (_selectedFilter == 'All') {
      return _allNotifications;
    }
    
    String? filterType;
    switch (_selectedFilter) {
      case 'Likes':
        filterType = 'like';
        break;
      case 'Comments':
        filterType = 'comment';
        break;
      case 'Follows':
        filterType = 'follow';
        break;
      case 'Recipes':
        filterType = 'recipe';
        break;
    }
    
    if (filterType != null) {
      return _allNotifications.where((notif) => notif.type == filterType).toList();
    }
    
    return _allNotifications;
  }

  // Group filtered notifications by time period
  Map<String, List<NotificationModel>> get _groupedNotifications {
    final filtered = _filteredNotifications;
    final now = DateTime.now();
    
    final Map<String, List<NotificationModel>> grouped = {
      'New': [],
      'Today': [],
      'This Week': [],
      'Earlier': [],
    };
    
    for (var notif in filtered) {
      final difference = now.difference(notif.createdAt);
      
      if (!notif.isRead) {
        grouped['New']!.add(notif);
      } else if (difference.inHours < 24) {
        grouped['Today']!.add(notif);
      } else if (difference.inDays < 7) {
        grouped['This Week']!.add(notif);
      } else {
        grouped['Earlier']!.add(notif);
      }
    }
    
    // Remove empty sections
    grouped.removeWhere((key, value) => value.isEmpty);
    
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _allNotifications.where((n) => !n.isRead).length;
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundOffWhite,
      body: RefreshIndicator(
        onRefresh: () => _loadNotifications(refresh: true),
        color: AppTheme.primaryDarkGreen,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // App Bar
            SliverAppBar(
              floating: true,
              pinned: true,
              backgroundColor: AppTheme.surfaceWhite,
              elevation: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (unreadCount > 0)
                    Text(
                      '$unreadCount new',
                      style: const TextStyle(
                        color: AppTheme.primaryDarkGreen,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              actions: [
                if (unreadCount > 0)
                  TextButton(
                    onPressed: _markAllAsRead,
                    child: const Text(
                      'Mark all read',
                      style: TextStyle(
                        color: AppTheme.primaryDarkGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            
            // Filter Chips
            SliverToBoxAdapter(
              child: Container(
                color: AppTheme.surfaceWhite,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _filterOptions.map((option) {
                      final isSelected = _selectedFilter == option;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(option),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedFilter = option;
                              });
                              HapticFeedback.selectionClick();
                            }
                          },
                          backgroundColor: AppTheme.backgroundOffWhite,
                          selectedColor: AppTheme.primaryDarkGreen,
                          labelStyle: TextStyle(
                            color: isSelected ? AppTheme.surfaceWhite : AppTheme.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? AppTheme.primaryDarkGreen : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            
            // Content
            if (_isLoading && _allNotifications.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: AppTheme.primaryDarkGreen,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Loading notifications...',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_hasError && _allNotifications.isEmpty)
              SliverFillRemaining(
                child: Center(
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
                        onPressed: () => _loadNotifications(refresh: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryDarkGreen,
                          foregroundColor: AppTheme.surfaceWhite,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_filteredNotifications.isEmpty)
              SliverFillRemaining(
                child: _buildEmptyState(),
              )
            else
              ..._buildNotificationsList(),
            
            // Loading indicator at bottom
            if (_isLoading && _allNotifications.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryDarkGreen,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildNotificationsList() {
    final grouped = _groupedNotifications;
    final List<Widget> slivers = [];
    
    grouped.forEach((period, notifications) {
      // Section header
      slivers.add(
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              period,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ),
      );
      
      // Notifications in this section
      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final notification = notifications[index];
              return FadeTransition(
                opacity: _fadeAnimation,
                child: _buildNotificationCard(notification),
              );
            },
            childCount: notifications.length,
          ),
        ),
      );
    });
    
    return slivers;
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    final iconData = _getIconForType(notification.type);
    final iconColor = _getColorForType(notification.type);
    final timeAgo = timeago.format(notification.createdAt, locale: 'en_short');
    
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        setState(() {
          _allNotifications.removeWhere((n) => n.id == notification.id);
        });
        _showSnackBar('Notification deleted', isSuccess: true);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: notification.isRead 
              ? AppTheme.surfaceWhite 
              : AppTheme.primaryDarkGreen.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: notification.isRead 
                ? AppTheme.textDisabled.withOpacity(0.2)
                : AppTheme.primaryDarkGreen.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              iconData,
              color: iconColor,
              size: 24,
            ),
          ),
          title: Text(
            notification.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                notification.message,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                timeAgo,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary.withOpacity(0.7),
                ),
              ),
            ],
          ),
          trailing: !notification.isRead
              ? Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryDarkGreen,
                    shape: BoxShape.circle,
                  ),
                )
              : null,
          onTap: () {
            if (!notification.isRead) {
              _markAsRead(notification.id);
            }
            HapticFeedback.selectionClick();
            // TODO: Navigate to related content if applicable
          },
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.comment;
      case 'follow':
        return Icons.person_add;
      case 'recipe':
        return Icons.restaurant_menu;
      case 'share':
        return Icons.share;
      default:
        return Icons.notifications;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'like':
        return Colors.red;
      case 'comment':
        return AppTheme.primaryDarkGreen;
      case 'follow':
        return Colors.blue;
      case 'recipe':
        return Colors.orange;
      case 'share':
        return Colors.purple;
      default:
        return AppTheme.textSecondary;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 80,
            color: AppTheme.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _selectedFilter == 'All' 
                ? 'No notifications yet' 
                : 'No $_selectedFilter notifications',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'All'
                ? 'When you get notifications, they\'ll show up here'
                : 'Try selecting a different filter',
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
}
