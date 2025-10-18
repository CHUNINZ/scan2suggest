import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'camera_scan_page.dart';
import 'app_theme.dart';
import 'services/api_service.dart';
import 'dart:async';

class MainScaffold extends StatefulWidget {
  final Widget body;
  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? appBar;
  final bool showBottomNav;
  final int currentIndex;
  final Function(int)? onNavTap;

  const MainScaffold({
    super.key,
    required this.body,
    required this.title,
    this.actions,
    this.appBar,
    this.showBottomNav = true,
    this.currentIndex = 0,
    this.onNavTap,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold>
    with TickerProviderStateMixin {
  bool _showScanOverlay = false;
  int? _pendingNavIndex;
  late AnimationController _overlayAnimationController;
  late AnimationController _fadeAnimationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  
  // Real-time notification count
  int _unreadNotificationCount = 0;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    
    _overlayAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _overlayAnimationController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 0.6,
    ).animate(CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeOut,
    ));
    
    // Load initial notification count
    _loadNotificationCount();
    
    // Poll for updates every 30 seconds
    _notificationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadNotificationCount();
    });
  }
  
  Future<void> _loadNotificationCount() async {
    try {
      final response = await ApiService.getNotifications(
        page: 1,
        limit: 100,
        unreadOnly: true, // Only get unread notifications
      );
      
      if (response['success'] == true && mounted) {
        final notifications = response['notifications'] as List? ?? [];
        setState(() {
          _unreadNotificationCount = notifications.length;
        });
      }
    } catch (e) {
      // Silently fail - don't disrupt user experience
      print('❌ Failed to load notification count: $e');
    }
  }

  @override
  void dispose() {
    _overlayAnimationController.dispose();
    _fadeAnimationController.dispose();
    _notificationTimer?.cancel();
    super.dispose();
  }

  void _showScanModal() {
    setState(() {
      _showScanOverlay = true;
    });
    _fadeAnimationController.forward();
    _overlayAnimationController.forward();
    HapticFeedback.lightImpact();
  }

  void _hideScanModal() {
    _overlayAnimationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _showScanOverlay = false;
        });
        
        if (_pendingNavIndex != null) {
          final navIndex = _pendingNavIndex!;
          _pendingNavIndex = null;
          
          if (widget.onNavTap != null) {
            widget.onNavTap!(navIndex);
          }
        }
      }
    });
    _fadeAnimationController.reverse();
  }

  void _selectScanOption(String option) {
    _hideScanModal();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CameraScanPage(scanType: option),
          ),
        );
      }
    });
  }

  void _handleNavTap(int index) {
    if (_showScanOverlay && index != 2) {
      _pendingNavIndex = index;
      _hideScanModal();
      return;
    }
    
    if (index == 2) {
      if (_showScanOverlay) {
        _hideScanModal();
      } else {
        _showScanModal();
      }
      return;
    }
    
    if (widget.onNavTap != null) {
      HapticFeedback.lightImpact();
      widget.onNavTap!(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundOffWhite,
      appBar: widget.appBar ??
          AppBar(
            backgroundColor: AppTheme.surfaceWhite,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                _getAppBarIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            actions: widget.actions,
          ),
      body: Stack(
        children: [
          widget.body,
          
          if (_showScanOverlay) ...[
            FadeTransition(
              opacity: _fadeAnimation,
              child: GestureDetector(
                onTap: _hideScanModal,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            
            SlideTransition(
              position: _slideAnimation,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height * 0.45,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceWhite,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.textPrimary.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, -10),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
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
                        
                        Text(
                          'Choose Scan Option',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select what you want to scan',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        Row(
                          children: [
                            Expanded(
                              child: _buildScanOption(
                                'Food',
                                Icons.restaurant,
                                'Scan prepared dishes',
                                AppTheme.primaryDarkGreen,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildScanOption(
                                'Ingredient',
                                Icons.eco,
                                'Scan raw ingredients',
                                Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      
      bottomNavigationBar: widget.showBottomNav
          ? Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceWhite,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.textPrimary.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  height: 75,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildNavItem(0, Icons.home, Icons.home_outlined, 'Home'),
                        _buildNavItem(1, Icons.cloud_upload, Icons.cloud_upload_outlined, 'Upload'),
                        const SizedBox(width: 64), // Space for FAB
                        _unreadNotificationCount > 0
                            ? _buildNavItemWithBadge(3, Icons.notifications, Icons.notifications_none, 'Notifications', _unreadNotificationCount.toString())
                            : _buildNavItem(3, Icons.notifications, Icons.notifications_outlined, 'Notifications'),
                        _buildNavItem(4, Icons.person, Icons.person_outline, 'Profile'),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,
      
      // Enhanced FAB with theme colors
      floatingActionButton: widget.showBottomNav ? Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.surfaceWhite,
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryDarkGreen.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Container(
          width: 64,
          height: 64,
          decoration: AppTheme.primaryGradientDecoration(
            borderRadius: BorderRadius.circular(32),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(32),
              onTap: () => _handleNavTap(2),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.document_scanner,
                    size: 24,
                    color: AppTheme.surfaceWhite,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Scan',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.surfaceWhite,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _getAppBarIcon() {
    switch (widget.currentIndex) {
      case 0:
        return const Icon(Icons.restaurant, color: AppTheme.primaryDarkGreen, size: 28);
      case 2:
        return const Icon(Icons.document_scanner, color: AppTheme.primaryDarkGreen, size: 28);
      case 3:
        return Stack(
          children: [
            const Icon(Icons.notifications, color: AppTheme.primaryDarkGreen, size: 28),
            if (_unreadNotificationCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppTheme.error,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    _unreadNotificationCount > 99 ? '99+' : _unreadNotificationCount.toString(),
                    style: const TextStyle(
                      color: AppTheme.surfaceWhite,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      case 4:
        return const Icon(Icons.person, color: AppTheme.primaryDarkGreen, size: 28);
      default:
        return const Icon(Icons.restaurant, color: AppTheme.primaryDarkGreen, size: 28);
    }
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isSelected = widget.currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _handleNavTap(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? activeIcon : inactiveIcon,
                size: 22,
                color: isSelected ? AppTheme.primaryDarkGreen : AppTheme.textSecondary,
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isSelected ? 11 : 10,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? AppTheme.primaryDarkGreen : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItemWithBadge(int index, IconData activeIcon, IconData inactiveIcon, String label, String badgeText) {
    final isSelected = widget.currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _handleNavTap(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    isSelected ? activeIcon : inactiveIcon,
                    size: 22,
                    color: isSelected ? AppTheme.primaryDarkGreen : AppTheme.textSecondary,
                  ),
                  Positioned(
                    right: -6,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppTheme.error,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          color: AppTheme.surfaceWhite,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isSelected ? 11 : 10,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? AppTheme.primaryDarkGreen : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanOption(String option, IconData icon, String subtitle, Color accentColor) {
    return GestureDetector(
      onTap: () => _selectScanOption(option),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration(elevation: 8).copyWith(
          border: Border.all(
            color: AppTheme.textDisabled,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor.withOpacity(0.8), accentColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: AppTheme.surfaceWhite,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              option,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}