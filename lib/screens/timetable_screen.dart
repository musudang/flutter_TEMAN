import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../models/timetable_item_model.dart';
import '../models/user_model.dart' as app_models;

class TimetableColor {
  final String backgroundHex;
  final String textHex;
  final String name;

  const TimetableColor({
    required this.backgroundHex,
    required this.textHex,
    required this.name,
  });
}

const List<TimetableColor> timetableColors = [
  TimetableColor(backgroundHex: '#E8EAF6', textHex: '#283593', name: 'Indigo'),
  TimetableColor(backgroundHex: '#E0F2F1', textHex: '#00695C', name: 'Teal'),
  TimetableColor(backgroundHex: '#FFE0B2', textHex: '#EF6C00', name: 'Orange'),
  TimetableColor(backgroundHex: '#FFEBEE', textHex: '#C62828', name: 'Red'),
  TimetableColor(backgroundHex: '#E8F5E9', textHex: '#2E7D32', name: 'Green'),
  TimetableColor(backgroundHex: '#FFF9C4', textHex: '#F57F17', name: 'Yellow'),
  TimetableColor(backgroundHex: '#F3E5F5', textHex: '#6A1B9A', name: 'Purple'),
  TimetableColor(backgroundHex: '#E1F5FE', textHex: '#0277BD', name: 'Blue'),
];

class TimetableScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final bool isReadOnly;
  final bool embedMode;

  const TimetableScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.isReadOnly = false,
    this.embedMode = false,
  });

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  final double hourHeight = 60.0;
  final double timeColumnWidth = 60.0;
  final int gridStartHour = 9;
  final int gridEndHour = 19; // 9:00 AM to 7:00 PM (19:00)

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xff')));
    } catch (e) {
      return Colors.teal;
    }
  }

  int _timeToMinutes(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length != 2) return 0;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
  }

  String _minutesToTime(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String _getDayName(int day) {
    switch (day) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      default:
        return '';
    }
  }

  bool _checkOverlap(List<TimetableItem> items, List<int> days, String start, String end, {String? excludeId}) {
    final s1 = _timeToMinutes(start);
    final e1 = _timeToMinutes(end);
    for (final item in items) {
      if (item.id == excludeId) continue;
      final commonDays = item.daysOfWeek.toSet().intersection(days.toSet());
      if (commonDays.isNotEmpty) {
        final s2 = _timeToMinutes(item.startTime);
        final e2 = _timeToMinutes(item.endTime);
        if (s1 < e2 && s2 < e1) {
          return true; // Overlap detected
        }
      }
    }
    return false;
  }

  void _showAddEditDialog({TimetableItem? editItem, required List<TimetableItem> allItems}) {
    if (widget.isReadOnly) return;

    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final isEdit = editItem != null;

    final nameController = TextEditingController(text: editItem?.name ?? '');
    final locationController = TextEditingController(text: editItem?.location ?? '');
    final notesController = TextEditingController(text: editItem?.notes ?? '');

    List<int> selectedDays = List<int>.from(editItem?.daysOfWeek ?? [1]);

    TimeOfDay startTime = editItem != null
        ? TimeOfDay(
            hour: int.parse(editItem.startTime.split(':')[0]),
            minute: int.parse(editItem.startTime.split(':')[1]),
          )
        : const TimeOfDay(hour: 9, minute: 0);

    TimeOfDay endTime = editItem != null
        ? TimeOfDay(
            hour: int.parse(editItem.endTime.split(':')[0]),
            minute: int.parse(editItem.endTime.split(':')[1]),
          )
        : const TimeOfDay(hour: 10, minute: 0);

    TimetableColor selectedColor = timetableColors.firstWhere(
      (c) => c.backgroundHex == (editItem?.colorHex ?? timetableColors[0].backgroundHex),
      orElse: () => timetableColors[0],
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String formatTime(TimeOfDay tod) {
              final String hour = tod.hour.toString().padLeft(2, '0');
              final String minute = tod.minute.toString().padLeft(2, '0');
              return "$hour:$minute";
            }

            Future<void> pickStartTime() async {
              final picked = await showTimePicker(
                context: context,
                initialTime: startTime,
              );
              if (picked != null) {
                setDialogState(() {
                  startTime = picked;
                  final startMin = startTime.hour * 60 + startTime.minute;
                  final endMin = endTime.hour * 60 + endTime.minute;
                  if (endMin <= startMin) {
                    endTime = TimeOfDay(
                      hour: (startTime.hour + 1) % 24,
                      minute: startTime.minute,
                    );
                  }
                });
              }
            }

            Future<void> pickEndTime() async {
              final picked = await showTimePicker(
                context: context,
                initialTime: endTime,
              );
              if (picked != null) {
                final startMin = startTime.hour * 60 + startTime.minute;
                final endMin = picked.hour * 60 + picked.minute;
                if (endMin <= startMin) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('End time must be after start time.')),
                    );
                  }
                  return;
                }
                setDialogState(() {
                  endTime = picked;
                });
              }
            }

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEdit ? 'Edit Class' : 'Add New Class',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1F36),
                          ),
                        ),
                        if (isEdit)
                          IconButton(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Class'),
                                  content: const Text('Are you sure you want to delete this class from your timetable?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true && context.mounted) {
                                Navigator.pop(context);
                                await firestoreService.deleteTimetableItem(editItem.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Class deleted.')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Class Name',
                        labelStyle: const TextStyle(color: Colors.teal),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.teal),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationController,
                      decoration: InputDecoration(
                        labelText: 'Classroom / Location',
                        labelStyle: const TextStyle(color: Colors.teal),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.teal),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Days of Week', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(5, (index) {
                        final d = index + 1;
                        final isSelected = selectedDays.contains(d);
                        return ChoiceChip(
                          label: Text(
                            _getDayName(d),
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: Colors.teal,
                          onSelected: (selected) {
                            setDialogState(() {
                              if (selected) {
                                selectedDays.add(d);
                              } else {
                                if (selectedDays.length > 1) {
                                  selectedDays.remove(d);
                                }
                              }
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: pickStartTime,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Start Time', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  Text(
                                    startTime.format(context),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: pickEndTime,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('End Time', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  Text(
                                    endTime.format(context),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Color Theme', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 50,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: timetableColors.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final color = timetableColors[index];
                          final isSelected = selectedColor.backgroundHex == color.backgroundHex;
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedColor = color;
                              });
                            },
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: _parseColor(color.backgroundHex),
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: Colors.teal.shade700, width: 3)
                                    : Border.all(color: Colors.grey.shade300),
                              ),
                              child: isSelected
                                  ? Icon(Icons.check, color: _parseColor(color.textHex), size: 18)
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Notes / Professor',
                        labelStyle: const TextStyle(color: Colors.teal),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.teal),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (nameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a class name.')),
                            );
                            return;
                          }

                          final startStr = formatTime(startTime);
                          final endStr = formatTime(endTime);

                          final hasOverlap = _checkOverlap(
                            allItems,
                            selectedDays,
                            startStr,
                            endStr,
                            excludeId: editItem?.id,
                          );

                          if (hasOverlap) {
                            final proceed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Schedule Conflict'),
                                content: const Text('There is already a class scheduled at this time. Do you want to save anyway?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Save'),
                                  ),
                                ],
                              ),
                            );
                            if (proceed != true) return;
                          }

                          final item = TimetableItem(
                            id: editItem?.id ?? '',
                            name: nameController.text.trim(),
                            location: locationController.text.trim(),
                            notes: notesController.text.trim(),
                            daysOfWeek: selectedDays,
                            startTime: startStr,
                            endTime: endStr,
                            colorHex: selectedColor.backgroundHex,
                          );

                          try {
                            if (isEdit) {
                              await firestoreService.updateTimetableItem(item);
                            } else {
                              await firestoreService.addTimetableItem(item);
                            }

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(isEdit ? 'Class updated.' : 'Class added.')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to save class: $e')),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(isEdit ? 'Save Changes' : 'Add Class'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showReadOnlyDetail(TimetableItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: _parseColor(item.colorHex),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(item.location.isNotEmpty ? item.location : 'No Location', style: const TextStyle(fontSize: 15)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.access_time_outlined, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${item.daysOfWeek.map((d) => _getDayName(d)).join(', ')} / ${item.startTime} - ${item.endTime}',
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),
            if (item.notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(item.notes, style: const TextStyle(fontSize: 14)),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.teal)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);

    return StreamBuilder<List<TimetableItem>>(
      stream: firestoreService.getTimetableStream(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.teal));
        }
        final items = snapshot.data ?? [];

        Widget buildGrid() {
          return LayoutBuilder(
            builder: (context, constraints) {
              final double gridWidth = constraints.maxWidth;
              final double dayWidth = (gridWidth - timeColumnWidth) / 5.0;
              final double totalGridHeight = (gridEndHour - gridStartHour) * hourHeight;

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Container(
                  color: Colors.white,
                  height: totalGridHeight + 40.0,
                  child: Stack(
                    children: [
                      // Background Grid (horizontal hour separators)
                      for (int h = 0; h <= (gridEndHour - gridStartHour); h++) ...[
                        Positioned(
                          top: h * hourHeight,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 1,
                            color: Colors.grey.shade100,
                          ),
                        ),
                        if (h < (gridEndHour - gridStartHour))
                          Positioned(
                            top: h * hourHeight + 6,
                            left: 8,
                            child: Text(
                              _minutesToTime((gridStartHour + h) * 60),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],

                      // Vertical day column separators
                      for (int d = 0; d <= 5; d++)
                        Positioned(
                          top: 0,
                          bottom: totalGridHeight,
                          left: timeColumnWidth + d * dayWidth,
                          child: Container(
                            width: 1,
                            color: Colors.grey.shade100,
                          ),
                        ),

                      // Day Header labels
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 25,
                        child: Container(
                          color: Colors.grey.shade50,
                          child: Row(
                            children: [
                              SizedBox(width: timeColumnWidth),
                              for (int d = 1; d <= 5; d++)
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      _getDayName(d),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      // Draw timetable events (classes)
                      for (final item in items) ...[
                        for (final day in item.daysOfWeek) ...[
                          if (day >= 1 && day <= 5) ...[
                            (() {
                              final startMin = _timeToMinutes(item.startTime);
                              final endMin = _timeToMinutes(item.endTime);
                              final gridStartMin = gridStartHour * 60;
                              final gridEndMin = gridEndHour * 60;

                              if (startMin >= gridEndMin || endMin <= gridStartMin) {
                                return const SizedBox();
                              }

                              final double top = ((startMin - gridStartMin) / 60.0) * hourHeight;
                              final double height = ((endMin - startMin) / 60.0) * hourHeight;
                              final double left = timeColumnWidth + (day - 1) * dayWidth;

                              final color = _parseColor(item.colorHex);
                              final tc = timetableColors.firstWhere(
                                (c) => c.backgroundHex == item.colorHex,
                                orElse: () => timetableColors[0],
                              );
                              final textColor = _parseColor(tc.textHex);

                              return Positioned(
                                top: top + 1,
                                left: left + 2,
                                width: dayWidth - 4,
                                height: height - 2,
                                child: GestureDetector(
                                  onTap: () {
                                    if (widget.isReadOnly) {
                                      _showReadOnlyDetail(item);
                                    } else {
                                      _showAddEditDialog(editItem: item, allItems: items);
                                    }
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: color.withOpacity(0.4),
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        if (item.location.isNotEmpty && height > 35)
                                          Text(
                                            item.location,
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                              color: textColor.withOpacity(0.8),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        if (item.notes.isNotEmpty && height > 55)
                                          Expanded(
                                            child: Text(
                                              item.notes,
                                              style: TextStyle(
                                                fontSize: 8,
                                                color: textColor.withOpacity(0.6),
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            })()
                          ]
                        ]
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        }

        if (widget.embedMode) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (!widget.isReadOnly)
                        Row(
                          children: [
                            const Text(
                              'Share with Followers',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1F36),
                              ),
                            ),
                            const SizedBox(width: 8),
                            StreamBuilder<app_models.User?>(
                              stream: firestoreService.getUserStream(widget.userId),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData || snapshot.data == null) return const SizedBox();
                                final user = snapshot.data!;
                                final isVisible = user.timetableVisibleToFollowers;
                                return Switch(
                                  value: isVisible,
                                  activeThumbColor: Colors.teal,
                                  onChanged: (val) async {
                                    await firestoreService.updateTimetableVisibility(val);
                                  },
                                );
                              },
                            ),
                          ],
                        )
                      else
                        const SizedBox(),
                      if (!widget.isReadOnly)
                        ElevatedButton.icon(
                          onPressed: () => _showAddEditDialog(allItems: items),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Class'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            elevation: 0,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(child: buildGrid()),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(widget.isReadOnly ? '${widget.userName}\'s Timetable' : 'My Timetable'),
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1A1F36),
            elevation: 0,
            actions: [
              if (!widget.isReadOnly)
                StreamBuilder<app_models.User?>(
                  stream: firestoreService.getUserStream(widget.userId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data == null) return const SizedBox();
                    final user = snapshot.data!;
                    final isVisible = user.timetableVisibleToFollowers;
                    return Row(
                      children: [
                        const Text('Share with Followers', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        Switch(
                          value: isVisible,
                          activeThumbColor: Colors.teal,
                          onChanged: (val) async {
                            await firestoreService.updateTimetableVisibility(val);
                          },
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
          body: buildGrid(),
          floatingActionButton: widget.isReadOnly
              ? null
              : FloatingActionButton(
                  onPressed: () => _showAddEditDialog(allItems: items),
                  backgroundColor: Colors.teal,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
        );
      },
    );
  }
}
