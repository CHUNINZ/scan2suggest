import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'social_feed_page.dart';
import 'discover_page.dart';
import 'upload_page.dart';
import 'profile_page.dart';
import 'main_scaffold.dart';

class MainNavigationController extends StatefulWidget {
  const MainNavigationController({super.key});

  @override
  State<MainNavigationController> createState() => _MainNavigationControllerState();
}

class _MainNavigationControllerState extends State<MainNavigationController>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  late AnimationController _pageTransitionController;

  // Initialize all pages once to maintain state
  late final List<Widget> _pages = [
    const SocialFeedPage(),      // Index 0 - Social Feed
    const DiscoverPage(),        // Index 1 - Discover
    const UploadPage(),          // Index 2 - Upload (mapped from index 3)
    const ProfilePage(),         // Index 3 - Profile (mapped from index 4)
  ];

  // Page titles for the app bar
  final List<String> _pageTitles = [
    'Social Feed',         // Index 0 - Social Feed
    'Discover',           // Index 1 - Discover
    'Upload Recipe',      // Index 2 - Upload (from nav index 3)
    'Profile',           // Index 3 - Profile (from nav index 4)
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    // Animation controller for page transitions
    _pageTransitionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pageTransitionController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    // Handle scan button (index 2) separately - it's handled in MainScaffold
    if (index == 2) {
      return; // Let MainScaffold handle the scan modal
    }
    
    if (_currentIndex == index) return; // No need to navigate to same page
    
    // Map navigation index to page index (skip scan button at index 2)
    int pageIndex;
    if (index < 2) {
      // Indices 0 and 1 map directly
      pageIndex = index;
    } else {
      // Indices 3 and 4 map to pages 2 and 3 (subtract 1 to account for skipped scan)
      pageIndex = index - 1;
    }
    
    setState(() {
      _currentIndex = index;
    });

    // Haptic feedback for better UX
    HapticFeedback.lightImpact();

    // Animate to the selected page
    _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  // Get the correct title index based on current navigation index
  int _getTitleIndex() {
    if (_currentIndex < 2) {
      return _currentIndex; // Home (0) and Upload (1) map directly
    } else if (_currentIndex == 2) {
      return 0; // Scan shows Home title as fallback
    } else {
      return _currentIndex - 1; // Notification (3->2) and Profile (4->3)
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: _pageTitles[_getTitleIndex()],
      currentIndex: _currentIndex,
      onNavTap: _onItemTapped,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Disable swipe navigation
        children: _pages,
        onPageChanged: (pageIndex) {
          // Map page changes back to navigation index (account for scan button)
          int navIndex;
          if (pageIndex < 2) {
            // Pages 0 and 1 map directly to nav indices 0 and 1
            navIndex = pageIndex;
          } else {
            // Pages 2 and 3 map to nav indices 3 and 4 (add 1 to account for scan at index 2)
            navIndex = pageIndex + 1;
          }
          
          setState(() {
            _currentIndex = navIndex;
          });
        },
      ),
    );
  }
}