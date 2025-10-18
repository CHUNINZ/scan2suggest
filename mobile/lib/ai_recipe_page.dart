import 'package:flutter/material.dart';
import 'dart:io';
import 'app_theme.dart';

class AIRecipePage extends StatefulWidget {
  final String foodName;
  final Map<String, dynamic> aiRecipe;
  final File? imageFile;

  const AIRecipePage({
    super.key,
    required this.foodName,
    required this.aiRecipe,
    this.imageFile,
  });

  @override
  State<AIRecipePage> createState() => _AIRecipePageState();
}

class _AIRecipePageState extends State<AIRecipePage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _extractRecipeText() {
    try {
      if (widget.aiRecipe.containsKey('candidates') && widget.aiRecipe['candidates'] is List) {
        final candidates = widget.aiRecipe['candidates'] as List;
        if (candidates.isNotEmpty) {
          final firstCandidate = candidates[0];
          if (firstCandidate['content'] != null && 
              firstCandidate['content']['parts'] != null &&
              firstCandidate['content']['parts'] is List) {
            final parts = firstCandidate['content']['parts'] as List;
            if (parts.isNotEmpty && parts[0]['text'] != null) {
              return parts[0]['text'] as String;
            }
          }
        }
      }
    } catch (e) {
      print('Error extracting recipe text: $e');
    }
    return '';
  }

  List<String> _extractIngredients(String recipeText) {
    final List<String> ingredients = [];
    
    final ingredientsMatch = RegExp(
      r'Ingredients?[:\s]*\n([\s\S]*?)(?=\n\s*Instructions?|\n\s*Steps?|\n\s*Directions?|$)',
      caseSensitive: false,
    ).firstMatch(recipeText);
    
    if (ingredientsMatch != null) {
      final ingredientsSection = ingredientsMatch.group(1) ?? '';
      final lines = ingredientsSection.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty && 
            (trimmed.startsWith('-') || 
             trimmed.startsWith('*') || 
             trimmed.startsWith('•') ||
             RegExp(r'^\d+\.?\s').hasMatch(trimmed))) {
          ingredients.add(trimmed.replaceFirst(RegExp(r'^[-*•\d.)\s]+'), '').trim());
        }
      }
    }
    
    return ingredients;
  }

  List<String> _extractInstructions(String recipeText) {
    final List<String> instructions = [];
    
    final instructionsMatch = RegExp(
      r'Instructions?[:\s]*\n([\s\S]*?)$',
      caseSensitive: false,
    ).firstMatch(recipeText);
    
    if (instructionsMatch != null) {
      final instructionsSection = instructionsMatch.group(1) ?? '';
      final lines = instructionsSection.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty && 
            (trimmed.startsWith('-') || 
             trimmed.startsWith('*') || 
             trimmed.startsWith('•') ||
             RegExp(r'^\d+\.?\s').hasMatch(trimmed))) {
          instructions.add(trimmed.replaceFirst(RegExp(r'^[-*•\d.)\s]+'), '').trim());
        }
      }
    }
    
    return instructions;
  }

  @override
  Widget build(BuildContext context) {
    final recipeText = _extractRecipeText();
    final ingredients = _extractIngredients(recipeText);
    final instructions = _extractInstructions(recipeText);

    return Scaffold(
      backgroundColor: AppTheme.backgroundOffWhite,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Enhanced App Bar with parallax effect
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            elevation: 0,
            backgroundColor: AppTheme.primaryDarkGreen,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.foodName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 3,
                        color: Colors.black45,
                      ),
                    ],
                  ),
                ),
              ),
              background: widget.imageFile != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          widget.imageFile!,
                          fit: BoxFit.cover,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.3),
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                          ),
                        ),
                        // Subtle overlay pattern
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.primaryDarkGreen.withOpacity(0.2),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.restaurant,
                          size: 100,
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ),
            ),
          ),

          // Content with fade and slide animation
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    
                    // Recipe Stats Card
                    if (ingredients.isNotEmpty && instructions.isNotEmpty)
                      _buildStatsCard(ingredients.length, instructions.length),
                    
                    // Ingredients Section
                    if (ingredients.isNotEmpty)
                      _buildIngredientsSection(ingredients),
                    
                    // Instructions Section
                    if (instructions.isNotEmpty)
                      _buildInstructionsSection(instructions),
                    
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(int ingredientsCount, int stepsCount) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryDarkGreen.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.shopping_basket_outlined,
            value: '$ingredientsCount',
            label: 'Ingredients',
            color: AppTheme.primaryDarkGreen,
          ),
          Container(
            height: 40,
            width: 1,
            color: AppTheme.textDisabled,
          ),
          _buildStatItem(
            icon: Icons.restaurant_menu_outlined,
            value: '$stepsCount',
            label: 'Steps',
            color: AppTheme.secondaryLightGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientsSection(List<String> ingredients) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryDarkGreen.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shopping_basket,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ingredients',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Everything you need',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Ingredients List
          ...ingredients.asMap().entries.map((entry) {
            return _buildIngredientItem(entry.value, entry.key);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildIngredientItem(String ingredient, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(20 * (1 - value), 0),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.backgroundOffWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.secondaryLightGreen.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      ingredient,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInstructionsSection(List<String> instructions) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryDarkGreen.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.secondaryLightGreen,
                      AppTheme.primaryDarkGreen,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructions',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Follow these steps',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Instructions List
          ...instructions.asMap().entries.map((entry) {
            return _buildInstructionStep(
              entry.value,
              entry.key + 1,
              entry.key,
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String instruction, int stepNumber, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 500 + (index * 60)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(30 * (1 - value), 0),
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step Number Circle
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryDarkGreen.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '$stepNumber',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Step Content
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundOffWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.secondaryLightGreen.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        instruction,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
