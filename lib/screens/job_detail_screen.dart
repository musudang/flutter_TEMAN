import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/job_model.dart';
import '../services/firestore_service.dart';
import 'package:intl/intl.dart';
import 'create_job_screen.dart';
import 'chat_screen.dart';
import '../widgets/report_dialog.dart';

class JobDetailScreen extends StatefulWidget {
  final Job job;

  const JobDetailScreen({super.key, required this.job});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  bool _hasApplied = false;
  bool _checkingStatus = true;

  @override
  void initState() {
    super.initState();
    _checkApplicationStatus();
  }

  Future<void> _checkApplicationStatus() async {
    final fs = Provider.of<FirestoreService>(context, listen: false);
    final applied = await fs.hasAppliedToJob(widget.job.id);
    if (mounted) {
      setState(() {
        _hasApplied = applied;
        _checkingStatus = false;
      });
    }
  }

  void _showApplyBottomSheet() {
    final messageController = TextEditingController(
      text: 'Hi! I\'m interested in the "${widget.job.title}" position.',
    );
    bool isSending = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Apply to "${widget.job.title}"',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Write a message to the employer',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: messageController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Introduce yourself and explain why you\'re a great fit...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.teal, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isSending
                          ? null
                          : () async {
                              final msg = messageController.text.trim();
                              if (msg.isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('Please write a message.')),
                                );
                                return;
                              }
                              setSheetState(() => isSending = true);

                              try {
                                final fs = Provider.of<FirestoreService>(
                                  context,
                                  listen: false,
                                );

                                // Record the application
                                await fs.applyToJob(
                                  jobId: widget.job.id,
                                  jobTitle: widget.job.title,
                                  employerId: widget.job.authorId,
                                  message: msg,
                                );

                                // Open chat with employer
                                final conversationId =
                                    await fs.getOrCreateConversation(widget.job.authorId);

                                if (mounted) {
                                  setState(() => _hasApplied = true);
                                }
                                if (ctx.mounted) Navigator.pop(ctx); // close bottom sheet

                                if (mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        conversationId: conversationId,
                                        chatTitle: widget.job.title,
                                        otherUserId: widget.job.authorId,
                                        initialMessage: msg,
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                setSheetState(() => isSending = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text('$e')),
                                  );
                                }
                              }
                            },
                      icon: isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send),
                      label: Text(isSending ? 'Sending...' : 'Submit Application'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fs = Provider.of<FirestoreService>(context, listen: false);
    final isOwner = fs.currentUserId == widget.job.authorId;
    final job = widget.job;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
        actions: [
          if (isOwner)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateJobScreen(editingJob: job),
                    ),
                  );
                } else if (value == 'delete') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Job?'),
                      content: const Text('This action cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await fs.deleteJob(job.id);
                    if (context.mounted) Navigator.pop(context);
                  }
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit Job')),
                const PopupMenuItem(value: 'delete', child: Text('Delete Job')),
              ],
            ),
          if (!isOwner)
            IconButton(
              icon: const Icon(Icons.flag_outlined, color: Colors.red),
              tooltip: 'Report Job',
              onPressed: () => showReportDialog(context, job.id, 'job'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              job.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Text(job.location, style: const TextStyle(color: Colors.grey)),
                const Spacer(),
                Text(
                  DateFormat('MMM d, yyyy').format(job.postedDate),
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    job.salary,
                    style: const TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    job.jobType,
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Images
            if (job.imageUrls.isNotEmpty) ...[
              SizedBox(
                height: 220,
                child: job.imageUrls.length == 1
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          job.imageUrls.first,
                          width: double.infinity,
                          height: 220,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                        ),
                      )
                    : PageView.builder(
                        itemCount: job.imageUrls.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                job.imageUrls[index],
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (job.imageUrls.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: Text(
                      'Swipe for more (${job.imageUrls.length} photos)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],

            const Divider(),

            // Description
            const Text(
              'Job Description',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              job.description,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),

            const SizedBox(height: 24),

            // Requirements
            const Text(
              'Requirements',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...job.requirements.map(
              (req) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: Colors.teal,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(req)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Divider(),

            // Contact
            const Text(
              'Contact Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.email, color: Colors.grey),
                const SizedBox(width: 8),
                SelectableText(
                  job.contactInfo,
                  style: const TextStyle(fontSize: 16, color: Colors.blue),
                ),
              ],
            ),

            const SizedBox(height: 40),
            // Apply Now button
            if (_checkingStatus)
              const Center(child: CircularProgressIndicator())
            else
              Center(
                child: ElevatedButton.icon(
                  onPressed: isOwner
                      ? null
                      : _hasApplied
                          ? null
                          : _showApplyBottomSheet,
                  icon: Icon(
                    isOwner
                        ? Icons.info_outline
                        : _hasApplied
                            ? Icons.check_circle
                            : Icons.send,
                  ),
                  label: Text(
                    isOwner
                        ? 'This is your post'
                        : _hasApplied
                            ? 'Already Applied'
                            : 'Apply Now',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOwner || _hasApplied
                        ? Colors.grey
                        : Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
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
