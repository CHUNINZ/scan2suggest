import 'package:flutter/material.dart';

class FoodConfirmationDialog extends StatefulWidget {
  final List<Map<String, dynamic>> detectedItems;
  final Function(String foodName, bool isCorrect) onConfirm;
  final VoidCallback onCancel;

  const FoodConfirmationDialog({
    super.key,
    required this.detectedItems,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<FoodConfirmationDialog> createState() => _FoodConfirmationDialogState();
}

class _FoodConfirmationDialogState extends State<FoodConfirmationDialog> {
  String? selectedFood;
  bool showManualInput = false;
  final TextEditingController _manualInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-select the highest confidence item
    if (widget.detectedItems.isNotEmpty) {
      selectedFood = widget.detectedItems.first['name'];
    }
  }

  @override
  void dispose() {
    _manualInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.orange.shade50,
              Colors.red.shade50,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.restaurant_menu,
                    color: Colors.orange.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Food Detection',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      Text(
                        'Is this correct?',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Detection Results or Manual Input
            if (!showManualInput) ...[
              Text(
                'We detected:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              
              // Detected items list
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Column(
                    children: widget.detectedItems.map((item) {
                      final isSelected = selectedFood == item['name'];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setState(() {
                                selectedFood = item['name'];
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? Colors.orange.shade100 
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected 
                                      ? Colors.orange.shade300 
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected 
                                        ? Icons.radio_button_checked 
                                        : Icons.radio_button_unchecked,
                                    color: isSelected 
                                        ? Colors.orange.shade600 
                                        : Colors.grey.shade400,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['name'],
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                        Text(
                                          '${(item['confidence'] * 100).toStringAsFixed(1)}% confidence',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Manual input option
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    showManualInput = true;
                  });
                },
                icon: Icon(Icons.edit, color: Colors.orange.shade600),
                label: Text(
                  'None of these? Enter manually',
                  style: TextStyle(color: Colors.orange.shade600),
                ),
              ),
            ] else ...[
              // Manual input form
              Text(
                'Enter the food name:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              
              TextField(
                controller: _manualInputController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g., Chicken Adobo, Lechon, Sinigang...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.orange.shade400, width: 2),
                  ),
                  prefixIcon: Icon(Icons.restaurant, color: Colors.orange.shade600),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              
              const SizedBox(height: 16),
              
              // Back to detection results
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    showManualInput = false;
                    _manualInputController.clear();
                  });
                },
                icon: Icon(Icons.arrow_back, color: Colors.grey.shade600),
                label: Text(
                  'Back to detection results',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: widget.onCancel,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _canConfirm() ? _handleConfirm : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      'Get Recipe',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _canConfirm() {
    if (showManualInput) {
      return _manualInputController.text.trim().isNotEmpty;
    } else {
      return selectedFood != null;
    }
  }

  void _handleConfirm() {
    String foodName;
    bool isCorrect;
    
    if (showManualInput) {
      foodName = _manualInputController.text.trim();
      isCorrect = false; // Manual input means detection was incorrect
    } else {
      foodName = selectedFood!;
      isCorrect = true; // User confirmed the detection
    }
    
    widget.onConfirm(foodName, isCorrect);
  }
}
