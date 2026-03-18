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
  
  // Gemini curated list of interests matching the requested style
  final List<String> _allInterests = [
    // Lifestyle / Social
    '맛집 탐방', '카페 투어', '인스타그래머블 카페', '커피 한 잔', '브런치', '동네 산책', 
    '한강에서 치맥', '솔직한 대화', '심심할 때 수다', '언어 교환', '친구 사귀기', '파티', '술 한 잔',
    
    // Hobbies / Culture
    '한국 드라마', '영화', '넷플릭스 정주행', '전시회 관람', '연극', '콘서트', '페스티벌',
    '음악 감상', 'K-Pop', '90년대 바이브', '독서', '만화카페', '사진', '종이접기', '새로운 것 도전하기',
    
    // Activity / Sports
    '산책', '러닝', '골프', '등산', '클라이밍', '크로스핏', '스포츠', '캠핑', 
    '근교 드라이브', '반려동물과 산책', '자전거', '홈트레이닝',
    
    // Entertainment / Others
    'PC방', 'e스포츠', '방탈출 카페', 'VR 체험', '쇼핑', '베이킹', '재테크', '자기계발',
    
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
              content: Text('You can select up to ${widget.maxSelections} interests.'),
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
                  child: const Text('Done', style: TextStyle(color: Colors.red, fontSize: 16)),
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
                const Text('Select interests for your profile.', style: TextStyle(color: Colors.grey)),
                Text(
                  '(${_selectedInterests.length}/${widget.maxSelections})',
                  style: TextStyle(
                    color: _selectedInterests.length == widget.maxSelections ? Colors.red : Colors.grey,
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
