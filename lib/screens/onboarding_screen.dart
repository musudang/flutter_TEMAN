import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/auth_service.dart';
import '../widgets/teman_logo.dart';
import '../widgets/interest_selection_sheet.dart';
import 'main_screen.dart';

// ──────────────────────────────────────────────────────────────────────────────
// OnboardingScreen — drives the entire new-user onboarding flow
// Steps: 0=Rules  1=Name  2=Birthday  3=Gender  4=Welcome
// ──────────────────────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  int _step = 0; // 0..5

  // Collected data
  String _name = '';
  DateTime? _birthday;
  String _gender = '';
  // Optional step 4
  String _bio = '';
  String _instagram = '';
  List<String> _interests = [];

  bool _isSavingExtras = false;

  late AnimationController _pageAnim;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _pageAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fadeAnim = CurvedAnimation(parent: _pageAnim, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.08, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _pageAnim, curve: Curves.easeOut));
    _pageAnim.forward();
  }

  @override
  void dispose() {
    _pageAnim.dispose();
    super.dispose();
  }

  void _nextStep() async {
    await _pageAnim.reverse();
    setState(() => _step++);
    _pageAnim.forward();
  }

  void _prevStep() async {
    if (_step == 0) return;
    await _pageAnim.reverse();
    setState(() => _step--);
    _pageAnim.forward();
  }

  // Save required profile data (called after gender step)
  Future<void> _saveRequiredAndContinue() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final age = _birthday != null ? _calcAge(_birthday!) : null;
    await auth.completeOnboarding(
      name: _name,
      age: age,
      gender: _gender,
      bio: _bio,
      instagram: _instagram,
      interests: _interests,
    );
    if (!mounted) return;
    _nextStep(); // go to step 4 (extras)
  }

  int _calcAge(DateTime birthday) {
    final now = DateTime.now();
    int age = now.year - birthday.year;
    if (now.month < birthday.month ||
        (now.month == birthday.month && now.day < birthday.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: _buildStep(),
              ),
            ),
            if (_isSavingExtras)
              Container(
                color: Colors.white.withValues(alpha: 0.8),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Color(0xFF1E56C8)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _CommunityRulesStep(onAgree: _nextStep);
      case 1:
        return _NameStep(
          onNext: (name) {
            _name = name;
            _nextStep();
          },
          onBack: _prevStep,
        );
      case 2:
        return _BirthdayStep(
          onNext: (birthday) {
            _birthday = birthday;
            _nextStep();
          },
          onBack: _prevStep,
        );
      case 3:
        return _GenderStep(
          onNext: (gender) {
            _gender = gender;
            _saveRequiredAndContinue();
          },
          onBack: _prevStep,
        );
      case 4:
        return _ProfileExtrasStep(
          onNext: (profilePic, bio, instagram, interests) async {
            setState(() => _isSavingExtras = true);
            final auth = Provider.of<AuthService>(context, listen: false);
            final uid = auth.currentUser?.uid;
            String? avatarUrl;

            try {
              if (profilePic != null && uid != null) {
                final ref = FirebaseStorage.instance.ref().child('avatars/$uid.jpg');
                await ref.putFile(profilePic);
                avatarUrl = await ref.getDownloadURL();
              } else {
                avatarUrl = 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_name)}&background=1E56C8&color=fff';
              }

              await auth.completeOnboarding(
                name: _name,
                age: _birthday != null ? _calcAge(_birthday!) : null,
                gender: _gender,
                bio: bio,
                instagram: instagram,
                interests: interests,
                avatarUrl: avatarUrl,
              );

              _bio = bio;
              _instagram = instagram;
              _interests = interests;
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error saving profile: $e')),
                );
              }
            }
            if (mounted) {
              setState(() => _isSavingExtras = false);
              _nextStep();
            }
          },
          onSkip: () async {
            setState(() => _isSavingExtras = true);
            final auth = Provider.of<AuthService>(context, listen: false);
            try {
              String avatarUrl = 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_name)}&background=1E56C8&color=fff';
              await auth.completeOnboarding(
                name: _name,
                age: _birthday != null ? _calcAge(_birthday!) : null,
                gender: _gender,
                bio: '',
                instagram: '',
                interests: [],
                avatarUrl: avatarUrl,
              );
            } catch (e) {
              // Ignore
            }
            if (mounted) {
              setState(() => _isSavingExtras = false);
              _nextStep();
            }
          },
          onBack: _prevStep,
        );
      case 5:
        return _WelcomeStep(
          name: _name,
          onEnter: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MainScreen()),
              (route) => false,
            );
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Step 0 — Community Rules
// ──────────────────────────────────────────────────────────────────────────────
class _CommunityRulesStep extends StatelessWidget {
  final VoidCallback onAgree;
  const _CommunityRulesStep({required this.onAgree});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
                onPressed: () async {
                  final auth = Provider.of<AuthService>(context, listen: false);
                  await auth.signOut();
                },
              ),
              const SizedBox(width: 12),
              const TemanLogoWidget(size: 40),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🤝 Welcome to TEMAN!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 6),
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF4A5568),
                    height: 1.6,
                  ),
                  children: [
                    TextSpan(
                      text: '"Teman" ',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E56C8)),
                    ),
                    TextSpan(text: 'means '),
                    TextSpan(
                      text: '"Friend"',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: ' in Indonesian.\nLet\'s make our life in Korea better, together.'),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Rules list
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: const [
                _RuleCard(
                  emoji: '👤',
                  number: '1',
                  title: 'Be Real, Be You',
                  titleKo: '정직하게 나를 표현하기',
                  description:
                      'Please use your real name, age, and nationality. Trust is the foundation of our community.',
                  descriptionKo:
                      '사진, 나이, 국적을 사실대로 설정해 주세요. 신뢰는 우리 커뮤니티의 기초입니다.',
                ),
                SizedBox(height: 12),
                _RuleCard(
                  emoji: '🚫',
                  number: '2',
                  title: 'Respect, No Harassment',
                  titleKo: '성적인 언행 금지',
                  description:
                      'Zero tolerance for sexual harassment, explicit content, or unsolicited advances. Keep it friendly and safe for everyone.',
                  descriptionKo:
                      '성희롱, 음란물 공유, 원치 않는 성적 접근은 즉시 영구 퇴출 대상입니다. 모두에게 안전하고 건전한 대화 환경을 만들어주세요.',
                ),
                SizedBox(height: 12),
                _RuleCard(
                  emoji: '⌨️',
                  number: '3',
                  title: 'No Spamming or Flooding',
                  titleKo: '도배 및 스팸 금지',
                  description:
                      'Do not post repetitive messages or commercial spam. Quality interactions make our community great.',
                  descriptionKo:
                      '의미 없는 도배나 상업적 스팸 게시물은 금지됩니다. 양질의 정보와 진정성 있는 소통을 나눠주세요.',
                ),
                SizedBox(height: 12),
                _RuleCard(
                  emoji: '🛡️',
                  number: '4',
                  title: 'Safety First',
                  titleKo: '안전이 최우선입니다',
                  description:
                      'Use the \'Accept/Decline\' system for Meetups and be cautious with your private info.',
                  descriptionKo:
                      '모임 참가 승인 기능을 활용하고, 개인 정보 공유에 항상 주의해 주세요.',
                ),
                SizedBox(height: 12),
                _RuleCard(
                  emoji: '🚨',
                  number: '5',
                  title: 'Reporting is Caring',
                  titleKo: '적극적으로 신고해 주세요',
                  description:
                      'If you see something wrong, don\'t hesitate to report it. We take every report seriously.',
                  descriptionKo:
                      '잘못된 언행이나 스팸을 발견하면 망설임 없이 신고해 주세요. 관리팀이 24시간 이내에 조치하겠습니다.',
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),

        // Agree button
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: onAgree,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E56C8),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'I Agree',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }
}


class _RuleCard extends StatelessWidget {
  final String emoji;
  final String number;
  final String title;
  final String titleKo;
  final String description;
  final String descriptionKo;

  const _RuleCard({
    required this.emoji,
    required this.number,
    required this.title,
    required this.titleKo,
    required this.description,
    required this.descriptionKo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E7FF), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Number badge + emoji
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E56C8),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(emoji, style: const TextStyle(fontSize: 22)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // English title
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 6),
                // English description
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Step 1 — Name
// ──────────────────────────────────────────────────────────────────────────────
class _NameStep extends StatefulWidget {
  final Function(String name) onNext;
  final VoidCallback onBack;
  const _NameStep({required this.onNext, required this.onBack});

  @override
  State<_NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<_NameStep> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back button
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 0, 0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
            onPressed: widget.onBack,
          ),
        ),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const Text(
                  'What\'s your\nname?',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This is how you\'ll appear on TEMAN.',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your name cannot be changed after saving.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 36),

                // Name input
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300, width: 1.5),
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Enter your name',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Next button
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
          child: _NextButton(
            enabled: _controller.text.trim().isNotEmpty,
            onTap: () {
              final name = _controller.text.trim();
              if (name.isEmpty) return;
              widget.onNext(name);
            },
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Step 2 — Birthday
// ──────────────────────────────────────────────────────────────────────────────
class _BirthdayStep extends StatefulWidget {
  final Function(DateTime birthday) onNext;
  final VoidCallback onBack;
  const _BirthdayStep({required this.onNext, required this.onBack});

  @override
  State<_BirthdayStep> createState() => _BirthdayStepState();
}

class _BirthdayStepState extends State<_BirthdayStep> {
  final _yearCtrl = TextEditingController();
  final _monthCtrl = TextEditingController();
  final _dayCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _yearCtrl.dispose();
    _monthCtrl.dispose();
    _dayCtrl.dispose();
    super.dispose();
  }

  bool get _isComplete =>
      _yearCtrl.text.length == 4 &&
      _monthCtrl.text.isNotEmpty &&
      _dayCtrl.text.isNotEmpty;

  DateTime? get _parsed {
    try {
      final y = int.parse(_yearCtrl.text);
      final m = int.parse(_monthCtrl.text);
      final d = int.parse(_dayCtrl.text);
      return DateTime(y, m, d);
    } catch (_) {
      return null;
    }
  }

  void _validate() {
    final date = _parsed;
    if (date == null) {
      setState(() => _error = 'Please enter a valid date.');
      return;
    }
    final now = DateTime.now();
    final age = now.year - date.year;
    if (date.isAfter(now)) {
      setState(() => _error = 'Date cannot be in the future.');
      return;
    }
    if (age < 18) {
      setState(() => _error = 'You must be at least 18 years old to join TEMAN.');
      return;
    }
    if (age > 100) {
      setState(() => _error = 'Please enter a valid birth year.');
      return;
    }
    setState(() => _error = null);
    widget.onNext(date);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 0, 0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
            onPressed: widget.onBack,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const Text(
                  'When\'s your\nbirthday?',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your age will be shown on your profile, not your birthday.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.5),
                ),
                const SizedBox(height: 40),

                // YYYY / MM / DD inputs
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _DateField(
                      controller: _yearCtrl,
                      hint: 'YYYY',
                      maxLength: 4,
                      flex: 3,
                      onChanged: (_) => setState(() {}),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Text('/',
                          style: TextStyle(
                              fontSize: 22, color: Colors.grey.shade400)),
                    ),
                    _DateField(
                      controller: _monthCtrl,
                      hint: 'MM',
                      maxLength: 2,
                      flex: 2,
                      onChanged: (_) => setState(() {}),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Text('/',
                          style: TextStyle(
                              fontSize: 22, color: Colors.grey.shade400)),
                    ),
                    _DateField(
                      controller: _dayCtrl,
                      hint: 'DD',
                      maxLength: 2,
                      flex: 2,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Colors.red.shade400,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
          child: _NextButton(
            enabled: _isComplete,
            onTap: _validate,
          ),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final int flex;
  final Function(String) onChanged;

  const _DateField({
    required this.controller,
    required this.hint,
    required this.maxLength,
    required this.flex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade300, width: 1.5),
          ),
        ),
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(maxLength),
          ],
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A2E),
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 20,
              fontWeight: FontWeight.w400,
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Step 3 — Gender
// ──────────────────────────────────────────────────────────────────────────────
class _GenderStep extends StatefulWidget {
  final Function(String gender) onNext;
  final VoidCallback onBack;
  const _GenderStep({required this.onNext, required this.onBack});

  @override
  State<_GenderStep> createState() => _GenderStepState();
}

class _GenderStepState extends State<_GenderStep> {
  String? _selected;
  bool _showOnProfile = true;
  static const Color _temanBlue = Color(0xFF1E56C8);

  final _options = ['Male', 'Female', 'Non-binary', 'Prefer not to say'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 0, 0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
            onPressed: widget.onBack,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const Text(
                  'What\'s your\ngender?',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select all that apply. TEMAN uses this to personalize your experience.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),

                // Gender options
                ..._options.map((option) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _GenderOption(
                    label: option,
                    selected: _selected == option,
                    onTap: () => setState(() => _selected = option),
                  ),
                )),

                const SizedBox(height: 16),
                // Show on profile toggle
                GestureDetector(
                  onTap: () => setState(() => _showOnProfile = !_showOnProfile),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _showOnProfile ? _temanBlue : Colors.transparent,
                          border: Border.all(
                            color: _showOnProfile ? _temanBlue : Colors.grey.shade400,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: _showOnProfile
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 14)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Show gender on my profile',
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
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
          child: _NextButton(
            enabled: _selected != null,
            label: 'Finish',
            onTap: () {
              if (_selected == null) return;
              widget.onNext(_selected!);
            },
          ),
        ),
      ],
    );
  }
}

class _GenderOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GenderOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const Color _temanBlue = Color(0xFF1E56C8);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF4FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _temanBlue : Colors.grey.shade300,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? _temanBlue : const Color(0xFF1A1A2E),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Step 4 — Profile Extras (Optional: Bio, Instagram, Interests)
// ──────────────────────────────────────────────────────────────────────────────
class _ProfileExtrasStep extends StatefulWidget {
  final Function(File? profilePic, String bio, String instagram, List<String> interests) onNext;
  final VoidCallback onSkip;
  final VoidCallback onBack;
  const _ProfileExtrasStep({
    required this.onNext,
    required this.onSkip,
    required this.onBack,
  });

  @override
  State<_ProfileExtrasStep> createState() => _ProfileExtrasStepState();
}

class _ProfileExtrasStepState extends State<_ProfileExtrasStep> {
  final _bioController = TextEditingController();
  final _instagramController = TextEditingController();
  List<String> _selectedInterests = [];
  File? _profileImage;

  @override
  void dispose() {
    _bioController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _profileImage = File(pickedFile.path));
    }
  }

  void _openInterestSheet() async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => InterestSelectionSheet(
        initialInterests: _selectedInterests,
      ),
    );

    if (result != null) {
      setState(() => _selectedInterests = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with back + skip
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
                onPressed: widget.onBack,
              ),
              TextButton(
                onPressed: widget.onSkip,
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: Color(0xFF1E56C8),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                // Optional badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF4FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFBDD1FF)),
                  ),
                  child: const Text(
                    'Optional',
                    style: TextStyle(
                      color: Color(0xFF1E56C8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tell us about\nyourself 🙂',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'These help others get to know you. You can always update this later in your profile.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.5),
                ),
                const SizedBox(height: 32),
                
                // Profile Picture
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                          child: _profileImage == null
                              ? Icon(Icons.person, size: 50, color: Colors.grey.shade500)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E56C8),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            padding: const EdgeInsets.all(6),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Bio
                const Text(
                  'Bio',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: TextField(
                    controller: _bioController,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Write a short intro about yourself...',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Instagram
                const Text(
                  'Instagram ID',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: TextField(
                    controller: _instagramController,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.alternate_email, color: Colors.grey.shade400, size: 18),
                      hintText: 'your_instagram_id',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Interests
                const Text(
                  'Interests',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _openInterestSheet,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: _selectedInterests.isEmpty
                        ? Row(
                            children: [
                              Icon(Icons.emoji_emotions_outlined, color: Colors.grey.shade400, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Tap to select interests...',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                              ),
                            ],
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _selectedInterests
                                .map((i) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF4FF),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: const Color(0xFFBDD1FF)),
                                      ),
                                      child: Text(
                                        i,
                                        style: const TextStyle(
                                          color: Color(0xFF1E56C8),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),

        // Done button
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
          child: _NextButton(
            enabled: true,
            label: 'Done',
            onTap: () => widget.onNext(
              _profileImage,
              _bioController.text.trim(),
              _instagramController.text.trim(),
              _selectedInterests,
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Step 5 — Welcome!
// ──────────────────────────────────────────────────────────────────────────────
class _WelcomeStep extends StatefulWidget {
  final String name;
  final VoidCallback onEnter;
  const _WelcomeStep({required this.name, required this.onEnter});


  @override
  State<_WelcomeStep> createState() => _WelcomeStepState();
}

class _WelcomeStepState extends State<_WelcomeStep>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 2),

        FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              children: [
                // Big logo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E56C8), Color(0xFF38BDF8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E56C8).withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.people_alt,
                      color: Colors.white, size: 52),
                ),
                const SizedBox(height: 32),

                Text(
                  'Welcome to\nTEMAN, ${widget.name}! 🎉',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Your profile is all set.\nConnect, discover, and explore with your new community!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade500,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const Spacer(flex: 2),

        // Enter button
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: widget.onEnter,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E56C8),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                shadowColor: const Color(0xFF1E56C8).withValues(alpha: 0.4),
              ),
              child: const Text(
                'Let\'s Go! 🚀',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Shared — Next / Finish button
// ──────────────────────────────────────────────────────────────────────────────
class _NextButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  final String label;

  const _NextButton({
    required this.enabled,
    required this.onTap,
    this.label = 'Continue',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              enabled ? const Color(0xFF1E56C8) : Colors.grey.shade200,
          foregroundColor: enabled ? Colors.white : Colors.grey.shade500,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
