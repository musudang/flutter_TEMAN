import 'package:flutter/material.dart';
import '../constants/university_constants.dart';

class FeedStateProvider extends ChangeNotifier {
  University? _selectedUniversity;
  
  University? get selectedUniversity => _selectedUniversity;

  void setUniversity(University? uni) {
    if (_selectedUniversity?.id != uni?.id) {
      _selectedUniversity = uni;
      notifyListeners();
    }
  }
}
