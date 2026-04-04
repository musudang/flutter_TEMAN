import 'package:flutter/material.dart';

class InterestSelectionSheet extends StatefulWidget {
  final List<String> initialInterests;
  final int maxSelections;

  const InterestSelectionSheet({
    super.key,
    this.initialInterests = const [],
    this.maxSelections = 5,
  });

  @override
  State<InterestSelectionSheet> createState() => _InterestSelectionSheetState();
}

class _InterestSelectionSheetState extends State<InterestSelectionSheet> {
  late Set<String> _selectedInterests;

  final List<String> _allInterests = [
    // Lifestyle & Social
    'Foodie', 'Cafe Hopping', 'Brunch', 'Neighborhood Walks',
    'Beer & Chicken',
    'Deep Conversations',
    'Language Exchange',
    'Making Friends',
    'Parties',
    'Drinks',

    // Entertainment & Culture
    'K-Dramas',
    'Movies',
    'Netflix Binging',
    'Art Exhibitions',
    'Theater',
    'Concerts',
    'Festivals',
    'Music', 'K-Pop', '90s Vibe', 'Reading', 'Photography', 'Trying New Things',

    // Activity & Sports
    'Walking',
    'Running',
    'Golf',
    'Hiking',
    'Climbing',
    'CrossFit',
    'Team Sports',
    'Camping',
    'Road Trips', 'Pet Walking', 'Cycling', 'Home Workout',

    // Hobbies & Others
    'PC Gaming',
    'Esports',
    'Escape Rooms',
    'VR Experiences',
    'Shopping',
    'Baking',
    'Investing',
    'Self-Development',

    // MBTI
    'INTJ', 'INTP', 'ENTJ', 'ENTP', 'INFJ', 'INFP', 'ENFJ', 'ENFP',
    'ISTJ', 'ISFJ', 'ESTJ', 'ESFJ', 'ISTP', 'ISFP', 'ESTP', 'ESFP',
  ];

  @override
  void initState() {
    super.initState();
    _selectedInterests = Set<String>.from(widget.initialInterests);
  }

  void _toggleInterest(String interest) {
    setState(() {
      if (_selectedInterests.contains(interest)) {
        _selectedInterests.remove(interest);
      } else {
        if (_selectedInterests.length < widget.maxSelections) {
          _selectedInterests.add(interest);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'You can select up to ${widget.maxSelections} interests.',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 48), // Balance
                const Text(
                  'Interests',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, _selectedInterests.toList());
                  },
                  child: const Text(
                    'Done',
                    style: TextStyle(color: Colors.red, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Sub-header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select interests for your profile.',
                  style: TextStyle(color: Colors.grey),
                ),
                Text(
                  '(${_selectedInterests.length}/${widget.maxSelections})',
                  style: TextStyle(
                    color: _selectedInterests.length == widget.maxSelections
                        ? Colors.red
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          // Interest Chips List
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Wrap(
                spacing: 8.0,
                runSpacing: 12.0,
                children: _allInterests.map((interest) {
                  final isSelected = _selectedInterests.contains(interest);
                  return GestureDetector(
                    onTap: () => _toggleInterest(interest),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? Colors.red : Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        interest,
                        style: TextStyle(
                          color: isSelected ? Colors.red : Colors.grey.shade600,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
