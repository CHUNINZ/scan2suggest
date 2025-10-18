import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'services/api_service.dart';
import 'enhanced_scan_results_page.dart';
import 'ingredient_scan_results_page.dart';

class CameraScanPage extends StatefulWidget {
  final String scanType; // 'Food' or 'Ingredient'
  
  const CameraScanPage({super.key, required this.scanType});

  @override
  State<CameraScanPage> createState() => _CameraScanPageState();
}

class _CameraScanPageState extends State<CameraScanPage>
    with TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isScanning = false;
  bool _isAutoScanning = false;
  bool _flashEnabled = false;
  bool _frontCamera = false;
  List<Map<String, dynamic>> _detectedItems = [];
  
  late AnimationController _scanAnimationController;
  late AnimationController _pulseAnimationController;
  late AnimationController _detectionAnimationController;
  late Animation<double> _scanAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _detectionAnimation;

  @override
  void initState() {
    super.initState();
    
    // Scanning line animation
    _scanAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _scanAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scanAnimationController,
      curve: Curves.easeInOut,
    ));

    // Pulse animation for shutter button
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));

    // Detection box animation
    _detectionAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _detectionAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _detectionAnimationController,
      curve: Curves.elasticOut,
    ));
    
    _initializeCamera();
    _startAutoScanning();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _scanAnimationController.dispose();
    _pulseAnimationController.dispose();
    _detectionAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    // Request camera permission
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      _showPermissionDeniedDialog();
      return;
    }

    try {
      // Get available cameras
      _cameras = await availableCameras();
      
      if (_cameras.isEmpty) {
        _showError('No cameras found');
        return;
      }

      // Initialize with back camera by default
      await _setupCamera(_cameras.first);
    } catch (e) {
      _showError('Error initializing camera: $e');
    }
  }

  Future<void> _setupCamera(CameraDescription camera) async {
    if (_controller != null) {
      await _controller!.dispose();
    }

    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      _showError('Error setting up camera: $e');
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text('This app needs camera access to scan food and ingredients. Please grant camera permission in settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showAuthenticationRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Required'),
        content: const Text('You need to be logged in to scan images. Please log in to your account first.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to previous screen
            },
            child: const Text('Go to Login'),
          ),
        ],
      ),
    );
  }

  void _startAutoScanning() {
    // Simulate real-time ingredient detection
    if (widget.scanType == 'Ingredient') {
      Timer.periodic(const Duration(seconds: 3), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (!_isScanning) {
          _simulateRealtimeDetection();
        }
      });
    }
  }

  void _simulateRealtimeDetection() {
    setState(() {
      _isAutoScanning = true;
      _detectedItems = _generateRandomDetections();
    });
    
    _detectionAnimationController.forward();
    
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _isAutoScanning = false;
        });
        _detectionAnimationController.reverse();
      }
    });
  }

  List<Map<String, dynamic>> _generateRandomDetections() {
    final ingredients = [
      {'name': 'Tomatoes', 'confidence': 0.95, 'x': 0.2, 'y': 0.3, 'width': 0.15, 'height': 0.12},
      {'name': 'Onion', 'confidence': 0.88, 'x': 0.6, 'y': 0.4, 'width': 0.12, 'height': 0.10},
      {'name': 'Garlic', 'confidence': 0.92, 'x': 0.4, 'y': 0.6, 'width': 0.08, 'height': 0.06},
      {'name': 'Bell Pepper', 'confidence': 0.85, 'x': 0.1, 'y': 0.7, 'width': 0.18, 'height': 0.15},
      {'name': 'Ginger', 'confidence': 0.78, 'x': 0.7, 'y': 0.2, 'width': 0.10, 'height': 0.08},
    ];
    
    // Return 2-4 random ingredients
    final random = DateTime.now().millisecond;
    final count = 2 + (random % 3);
    ingredients.shuffle();
    return ingredients.take(count).toList();
  }

  void _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      _flashEnabled = !_flashEnabled;
      await _controller!.setFlashMode(
        _flashEnabled ? FlashMode.torch : FlashMode.off,
      );
      setState(() {});
      HapticFeedback.lightImpact();
    } catch (e) {
      _showError('Error toggling flash: $e');
    }
  }

  void _switchCamera() async {
    if (_cameras.length < 2) return;

    final currentIndex = _cameras.indexOf(_controller!.description);
    final nextIndex = (currentIndex + 1) % _cameras.length;
    
    await _setupCamera(_cameras[nextIndex]);
    setState(() {
      _frontCamera = _cameras[nextIndex].lensDirection == CameraLensDirection.front;
    });
    HapticFeedback.lightImpact();
  }

  void _openGallery() async {
    HapticFeedback.lightImpact();
    
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (image != null) {
        // Process the selected image for scanning
        await _processGalleryImage(File(image.path));
      }
    } catch (e) {
      _showError('Error accessing gallery: $e');
    }
  }
  
  Future<void> _processGalleryImage(File imageFile) async {
    setState(() {
      _isScanning = true;
      _detectedItems.clear();
    });

    try {
      print('🔄 Processing gallery image...');
      print('📂 Image path: ${imageFile.path}');
      print('📊 Image size: ${await imageFile.length()} bytes');
      
      // Initialize token first
      await ApiService.initializeToken();
      
      // Test connection to ensure backend is reachable
      final isConnected = await ApiService.testConnection();
      if (!isConnected) {
        throw Exception('Cannot connect to backend server. Check your network connection.');
      }
      
      // Call real AI detection API
      final scanType = widget.scanType.toLowerCase();
      final result = await ApiService.analyzeImage(
        imageFile: imageFile,
        scanType: scanType,
      );

      setState(() {
        _isScanning = false;
      });

      HapticFeedback.heavyImpact();

      // Extract detected item names from API response
      List<String> detectedItems = [];
      if (result['detectedItems'] != null) {
        for (var item in result['detectedItems']) {
          detectedItems.add(item['name'] ?? 'Unknown item');
        }
      }

      // Navigate to results based on scan type
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => widget.scanType.toLowerCase() == 'ingredient'
              ? IngredientScanResultsPage(imageFile: imageFile)
              : EnhancedScanResultsPage(
                  imageFile: imageFile,
                  scanType: widget.scanType,
                ),
        ),
      );
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      
      print('❌ Gallery scan error: $e');
      
      String errorMessage = 'Error scanning image';
      if (e.toString().contains('Network') || e.toString().contains('connect')) {
        errorMessage = 'Network error. Check your connection and try again.';
      } else if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
        errorMessage = 'Authentication required. Please log in to scan images.';
        _showAuthenticationRequiredDialog();
        return;
      }
      
      _showError(errorMessage);
    }
  }

  void _openManualEntry() {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Manual ingredient entry would be implemented here'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _captureImage() {
    if (_isScanning || !_isInitialized) return;
    _performScan();
  }

  void _performScan() async {
    if (!_isInitialized || _controller == null) return;

    setState(() {
      _isScanning = true;
      _detectedItems.clear();
    });

    HapticFeedback.mediumImpact();
    
    try {
      print('🔄 Starting scan process...');
      
      // Initialize token first
      print('🔑 Initializing authentication token...');
      await ApiService.initializeToken();
      
      // Test connection to ensure backend is reachable
      print('🌐 Testing backend connection...');
      final isConnected = await ApiService.testConnection();
      if (!isConnected) {
        print('❌ Backend connection failed');
        throw Exception('Cannot connect to backend server. Check your network connection.');
      }
      print('✅ Backend connection successful');
      
      // Capture image
      print('📸 Capturing image...');
      final image = await _controller!.takePicture();
      final imageFile = File(image.path);
      print('✅ Image captured: ${image.path}');
      print('📊 Image file size: ${await imageFile.length()} bytes');
      
      // Call real AI detection API
      final scanType = widget.scanType.toLowerCase(); // Convert 'Food' to 'food', 'Ingredient' to 'ingredient'
      print('🤖 Calling AI detection API with scanType: $scanType');
      final result = await ApiService.analyzeImage(
        imageFile: imageFile,
        scanType: scanType,
      );
      print('✅ AI detection API call successful');

      setState(() {
        _isScanning = false;
      });

      HapticFeedback.heavyImpact();

      // Extract detected item names from API response
      List<String> detectedItems = [];
      if (result['detectedItems'] != null) {
        detectedItems = (result['detectedItems'] as List)
            .map((item) => item['name'].toString())
            .toList();
      }

      // If no items detected, show appropriate message
      if (detectedItems.isEmpty) {
        detectedItems = ['No ${scanType}s detected. Try adjusting lighting or angle.'];
      }

      // Navigate to results page based on scan type
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => widget.scanType.toLowerCase() == 'ingredient'
              ? IngredientScanResultsPage(imageFile: imageFile)
              : EnhancedScanResultsPage(
                  imageFile: imageFile,
                  scanType: widget.scanType,
                ),
        ),
      );
    } catch (e) {
      setState(() {
        _isScanning = false;
      });
      
      print('❌ Scan error occurred: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Full error details: ${e.toString()}');
      
      // Show more specific error messages
      String errorMessage = 'Error scanning image';
      if (e.toString().contains('Network') || e.toString().contains('connect')) {
        errorMessage = 'Network error. Check your connection and try again.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Scan timed out. Please try again.';
      } else if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
        errorMessage = 'Authentication required. Please log in to scan images.';
      } else if (e.toString().contains('ApiException')) {
        errorMessage = e.toString();
      } else if (e.toString().contains('backend server')) {
        errorMessage = 'Cannot reach server. Check network and try again.';
      } else if (e.toString().contains('SocketException')) {
        errorMessage = 'Network connection failed. Check WiFi and server IP.';
      } else if (e.toString().contains('FormatException')) {
        errorMessage = 'Invalid server response. Check backend configuration.';
      }
      
      print('📱 Showing error to user: $errorMessage');
      _showError(errorMessage);
      
      // Show authentication dialog if needed
      if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
        _showAuthenticationRequiredDialog();
        return;
      }
      
      // For other errors, just show the error message
      // User can try scanning again
    }
  }


  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          CameraPreview(_controller!),
          
          // Real-time detection overlays
          if (widget.scanType == 'Ingredient' && !_isScanning)
            _buildRealtimeDetections(),

          // Scanning overlay
          if (_isScanning) _buildScanningOverlay(),

          // Top-left back button
          _buildBackButton(),

          // Top-right control cluster
          _buildTopRightControls(),

          // Bottom control cluster
          _buildBottomControls(),

          // Status bar overlay
          _buildStatusOverlay(),
        ],
      ),
    );
  }


  Widget _buildGridOverlay() {
    return Positioned.fill(
      child: CustomPaint(
        painter: GridPainter(opacity: 0.2),
      ),
    );
  }

  Widget _buildScanningLine() {
    return AnimatedBuilder(
      animation: _scanAnimation,
      builder: (context, child) {
        return Positioned(
          top: MediaQuery.of(context).size.height * _scanAnimation.value,
          left: 0,
          right: 0,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.green,
                  Colors.green.withOpacity(0.8),
                  Colors.green,
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRealtimeDetections() {
    return AnimatedBuilder(
      animation: _detectionAnimation,
      builder: (context, child) {
        return Stack(
          children: _detectedItems.map((item) {
            final screenWidth = MediaQuery.of(context).size.width;
            final screenHeight = MediaQuery.of(context).size.height;
            
            return Positioned(
              left: screenWidth * item['x'] * _detectionAnimation.value,
              top: screenHeight * item['y'] * _detectionAnimation.value,
              child: Transform.scale(
                scale: _detectionAnimation.value,
                child: Container(
                  width: screenWidth * item['width'],
                  height: screenHeight * item['height'],
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.green,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    children: [
                      // Detection label
                      Positioned(
                        top: -25,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${item['name']} ${(item['confidence'] * 100).toInt()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildScanningOverlay() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black.withOpacity(0.4),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.green,
                  width: 3,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      widget.scanType == 'Food' ? Icons.restaurant : Icons.search,
                      color: Colors.green,
                      size: 40,
                    ),
                  ),
                  Positioned.fill(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      strokeWidth: 3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _isScanning ? 'Analyzing ${widget.scanType.toLowerCase()}...' : 'Processing...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Keep camera steady',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopRightControls() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      right: 16,
      child: Column(
        children: [
          // Flash toggle button
          Container(
            width: 44,
            height: 44,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: _flashEnabled 
                  ? Colors.amber.withOpacity(0.9) 
                  : Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
              border: Border.all(
                color: _flashEnabled ? Colors.amber : Colors.white.withOpacity(0.3)
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: _toggleFlash,
                child: Icon(
                  _flashEnabled ? Icons.flash_on : Icons.flash_off,
                  color: _flashEnabled ? Colors.black : Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          
          // Camera switch button
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: _switchCamera,
                child: const Icon(
                  Icons.flip_camera_ios,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 40,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Gallery button
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: _openGallery,
                child: const Icon(
                  Icons.photo_library,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
          
          // Main capture button with pulse animation
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isScanning ? 1.0 : _pulseAnimation.value,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _isScanning ? Colors.grey[300] : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isScanning ? Colors.grey[400]! : Colors.green,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(40),
                      onTap: _isScanning ? null : _captureImage,
                      child: Icon(
                        _isScanning ? Icons.hourglass_empty : Icons.camera_alt,
                        color: _isScanning ? Colors.grey[600] : Colors.green,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Manual entry button
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: _openManualEntry,
                child: const Icon(
                  Icons.keyboard,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOverlay() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 120,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Text(
            widget.scanType == 'Food'
                ? 'Point camera at prepared food dish'
                : _isAutoScanning 
                    ? 'Real-time detection active'
                    : 'Point camera at ingredients',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// Custom painter for grid overlay
class GridPainter extends CustomPainter {
  final double opacity;
  
  GridPainter({required this.opacity});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..strokeWidth = 1;

    // Draw rule of thirds grid
    final horizontalSpacing = size.height / 3;
    final verticalSpacing = size.width / 3;

    // Horizontal lines
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(0, horizontalSpacing * i),
        Offset(size.width, horizontalSpacing * i),
        paint,
      );
    }

    // Vertical lines
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(verticalSpacing * i, 0),
        Offset(verticalSpacing * i, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

