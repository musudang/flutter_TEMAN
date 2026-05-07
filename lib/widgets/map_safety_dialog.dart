import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MapSafetyDialog extends StatefulWidget {
  const MapSafetyDialog({super.key});

  @override
  State<MapSafetyDialog> createState() => _MapSafetyDialogState();
}

class _MapSafetyDialogState extends State<MapSafetyDialog> {
  bool _hideForToday = false;

  Future<void> _onConfirm() async {
    if (_hideForToday) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final todayStr = DateTime.now().toIso8601String().split('T')[0];
        await prefs.setString('map_safety_guide_hidden_date', todayStr);
        // Force flush to disk so value is available immediately
        await prefs.reload();
      } catch (e) {
        debugPrint('Error saving map safety dialog preference: $e');
      }
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
                const Icon(Icons.privacy_tip_rounded, color: Colors.blue, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: const Text(
                    'Safety & Privacy Guide for Map',
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
              "Before using the Map feature, please understand how your location is shared.",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _RuleItem(
                      title: '1. Follower-Only Visibility 👀',
                      description:
                          'Only your followers can see your location on the map. Your location is completely hidden from strangers.',
                    ),
                    // ── Emphasized ON/OFF Warning ──
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade300, width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                '2. Location ON/OFF Toggle ⚠️',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.red.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(fontSize: 13, color: Colors.grey[800], height: 1.5),
                              children: [
                                const TextSpan(text: 'When location is '),
                                TextSpan(
                                  text: 'ON',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.red.shade700,
                                    fontSize: 15,
                                    backgroundColor: Colors.red.shade100,
                                  ),
                                ),
                                const TextSpan(
                                  text: ', your real-time location is exposed to all your followers. ',
                                ),
                                const TextSpan(
                                  text: 'They can see exactly where you are.\n\n',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const TextSpan(text: 'When location is '),
                                TextSpan(
                                  text: 'OFF',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.green.shade700,
                                    fontSize: 15,
                                    backgroundColor: Colors.green.shade100,
                                  ),
                                ),
                                const TextSpan(
                                  text: ', you disappear from the map entirely and the map is hidden.',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You can toggle this anytime using the switch in the top-right corner of the map.',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                    const _RuleItem(
                      title: '3. Personal Privacy 🔒',
                      description:
                          'We do not store your historical location data. Only your most recent location is used while sharing is active.',
                    ),
                    const _RuleItem(
                      title: '4. Meet Safely 🤝',
                      description:
                          "If you plan to meet someone you see on the map, please prioritize public places and let a friend know your plans.",
                    ),
                    const Divider(),
                    const Text(
                      'Disclaimer',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'TEMAN provides location sharing for convenience and connection. You are responsible for managing your location visibility and safety.',
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
                child: const Text('I understand!'),
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
