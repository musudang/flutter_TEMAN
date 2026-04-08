import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class ReportDialog extends StatefulWidget {
  final String contentId;
  final String contentType; // 'post', 'meetup', 'job', 'marketplace'

  const ReportDialog({
    super.key,
    required this.contentId,
    this.contentType = 'post',
  });

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  final List<String> _reasons = [
    'Group rule violation',
    'Irrelevant content',
    'Fake news',
    'Conflict between members',
    'Spam',
    'Harassment',
    'Hate speech',
    'Nudity or sexual content',
    'Violence',
    'Other',
  ];

  String? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  String get _titleLabel {
    switch (widget.contentType) {
      case 'meetup':
        return 'Report Meetup';
      case 'job':
        return 'Report Job';
      case 'marketplace':
        return 'Report Item';
      default:
        return 'Report Post';
    }
  }

  String get _descriptionLabel {
    switch (widget.contentType) {
      case 'meetup':
        return 'Report this meetup to administrators.\nPlease tell us what is wrong with this meetup. We will not tell the host that you reported it.';
      case 'job':
        return 'Report this job posting to administrators.\nPlease tell us what is wrong with this listing. We will not tell the author that you reported it.';
      case 'marketplace':
        return 'Report this marketplace item to administrators.\nPlease tell us what is wrong with this listing. We will not tell the seller that you reported it.';
      default:
        return 'Report this post to administrators.\nPlease tell us what is wrong with this post. We will not tell the author that you reported it.';
    }
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a reason for reporting.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await FirestoreService().reportPost(
        widget.contentId,
        reason: _selectedReason!,
        details: _detailsController.text.trim(),
        type: widget.contentType,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred while reporting: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _titleLabel,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 24,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _descriptionLabel,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: RadioGroup<String>(
                  groupValue: _selectedReason,
                  onChanged: (value) {
                    setState(() {
                      _selectedReason = value;
                    });
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ..._reasons.map((reason) {
                        return RadioListTile<String>(
                          title: Text(
                            reason,
                            style: const TextStyle(fontSize: 15),
                          ),
                          value: reason,
                          contentPadding: EdgeInsets.zero,
                          activeColor: Colors.red,
                        );
                      }),
                      if (_selectedReason == 'Other' ||
                          _selectedReason != null) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _detailsController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Details (optional)',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 13,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.red),
                            ),
                            contentPadding: const EdgeInsets.all(12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  disabledBackgroundColor: Colors.red[200],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Submit Report',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showReportPostDialog(BuildContext context, String postId) {
  showDialog(
    context: context,
    builder: (context) => ReportDialog(contentId: postId, contentType: 'post'),
  );
}

void showReportDialog(BuildContext context, String contentId, String contentType) {
  showDialog(
    context: context,
    builder: (context) => ReportDialog(contentId: contentId, contentType: contentType),
  );
}
