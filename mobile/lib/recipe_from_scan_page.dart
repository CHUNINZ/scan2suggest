import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';

class RecipeFromScanPage extends StatefulWidget {
  final String foodName;
  final Map<String, dynamic> recipe;
  final String scanId;

  const RecipeFromScanPage({
    super.key,
    required this.foodName,
    required this.recipe,
    required this.scanId,
  });

  @override
  State<RecipeFromScanPage> createState() => _RecipeFromScanPageState();
}

class _RecipeFromScanPageState extends State<RecipeFromScanPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  widget.foodName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 3,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.orange.shade400,
                        Colors.orange.shade600,
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Background pattern
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.1,
                          child: Image.asset(
                            'assets/images/food_pattern.png',
                            repeat: ImageRepeat.repeat,
                          ),
                        ),
                      ),
                      // Recipe info overlay
                      Positioned(
                        bottom: 60,
                        left: 16,
                        right: 16,
                        child: Row(
                          children: [
                            _buildInfoChip(
                              Icons.timer,
                              '${widget.recipe['prepTime'] ?? 30} min',
                            ),
                            const SizedBox(width: 8),
                            _buildInfoChip(
                              Icons.people,
                              '${widget.recipe['servings'] ?? 4} servings',
                            ),
                            const SizedBox(width: 8),
                            _buildInfoChip(
                              Icons.star,
                              widget.recipe['difficulty'] ?? 'Medium',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.shopping_cart),
                    text: 'Ingredients',
                  ),
                  Tab(
                    icon: Icon(Icons.list_alt),
                    text: 'Instructions',
                  ),
                ],
              ),
            ),
            
            // Tab Content
            SliverFillRemaining(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildIngredientsTab(),
                  _buildInstructionsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCookingTimer,
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.timer),
        label: const Text('Start Cooking'),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsTab() {
    final ingredients = widget.recipe['ingredients'] as List<dynamic>? ?? [];
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.shopping_cart, color: Colors.orange.shade600, size: 24),
              const SizedBox(width: 8),
              Text(
                'Ingredients (${ingredients.length})',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Ingredients list
          Expanded(
            child: ingredients.isEmpty
                ? _buildEmptyState(
                    Icons.shopping_cart_outlined,
                    'No ingredients available',
                    'We\'ll generate a basic ingredient list for ${widget.foodName}',
                  )
                : ListView.builder(
                    itemCount: ingredients.length,
                    itemBuilder: (context, index) {
                      final ingredient = ingredients[index];
                      return _buildIngredientItem(ingredient, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientItem(dynamic ingredient, int index) {
    String name;
    String? amount;
    
    if (ingredient is Map<String, dynamic>) {
      name = ingredient['name'] ?? ingredient['ingredient'] ?? 'Unknown ingredient';
      amount = ingredient['amount'] ?? ingredient['measure'];
    } else {
      name = ingredient.toString();
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        shadowColor: Colors.black12,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.lightImpact();
            // Could add functionality to check off ingredients
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Index number
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Ingredient details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      if (amount != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          amount,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Checkbox (for future functionality)
                Icon(
                  Icons.radio_button_unchecked,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionsTab() {
    final instructions = widget.recipe['instructions'] as List<dynamic>? ?? [];
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.list_alt, color: Colors.orange.shade600, size: 24),
              const SizedBox(width: 8),
              Text(
                'Cooking Steps (${instructions.length})',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Instructions list
          Expanded(
            child: instructions.isEmpty
                ? _buildEmptyState(
                    Icons.menu_book_outlined,
                    'No instructions available',
                    'We\'ll generate basic cooking steps for ${widget.foodName}',
                  )
                : ListView.builder(
                    itemCount: instructions.length,
                    itemBuilder: (context, index) {
                      final instruction = instructions[index];
                      return _buildInstructionItem(instruction, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(dynamic instruction, int index) {
    String text;
    
    if (instruction is Map<String, dynamic>) {
      text = instruction['instruction'] ?? instruction['step'] ?? instruction.toString();
    } else {
      text = instruction.toString();
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        shadowColor: Colors.black12,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step number
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade400, Colors.orange.shade600],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Instruction text
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  void _showCookingTimer() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cooking Timer'),
        content: const Text('Would you like to set a cooking timer?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement timer functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Timer feature coming soon!'),
                ),
              );
            },
            child: const Text('Set Timer'),
          ),
        ],
      ),
    );
  }
}
