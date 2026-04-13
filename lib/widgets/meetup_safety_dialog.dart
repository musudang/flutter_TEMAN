import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MeetupSafetyDialog extends StatefulWidget {
  const MeetupSafetyDialog({super.key});

  @override
  State<MeetupSafetyDialog> createState() => _MeetupSafetyDialogState();
}

class _MeetupSafetyDialogState extends State<MeetupSafetyDialog> {
  bool _hideForToday = false;

  void _onConfirm() async {
    if (_hideForToday) {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month}-${today.day}';
      await prefs.setString('meetup_safety_guide_hidden_date', todayStr);
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: const Text(
                    'Safety Guide for Your First Meetup!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              "Before you connect with a new 'Teman', please read these safety tips.",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _RuleItem(
                      title: '1. Meet in Public Places 📍',
                      description:
                          'Always choose a bright, open, and public location for your first meeting, such as a cafe, park, or restaurant. Avoid private or isolated spaces.',
                    ),
                    _RuleItem(
                      title: '2. Verify Their Profile 👤',
                      description:
                          "Check the host's and participants' profiles, including their Instagram links, before joining.",
                    ),
                    _RuleItem(
                      title: '3. Share Your Plans 📱',
                      description:
                          'Tell a friend or roommate about your meetup location and expected return time.',
                    ),
                    _RuleItem(
                      title: '4. No-Show & Etiquette 🤝',
                      description:
                          "Respect everyone’s time. If you cannot attend, use the 'Leave' function at least 1 hour in advance. Frequent no-shows may result in a ban.",
                    ),
                    _RuleItem(
                      title: '5. Report Suspicious Activity 🚨',
                      description:
                          'If a user requests money, promotes illegal services, or makes you feel uncomfortable, report them immediately to the Admin.',
                    ),
                    Divider(),
                    Text(
                      'Disclaimer',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'TEMAN provides a platform for connection but is not responsible for any disputes or accidents occurring during offline meetings. Please prioritize your safety at all times.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: _hideForToday,
                    onChanged: (val) {
                      setState(() {
                        _hideForToday = val ?? false;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Do not show again for today',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('I understand and will stay safe!'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  final String title;
  final String description;

  const _RuleItem({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(fontSize: 13, color: Colors.grey[800]),
          ),
        ],
      ),
    );
  }
}
