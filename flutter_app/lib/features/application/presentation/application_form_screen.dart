// ignore_for_file: deprecated_member_use

import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:national_id_flutter_app/core/theme/app_theme.dart';
import 'package:national_id_flutter_app/core/theme/nid_header.dart';
import 'package:national_id_flutter_app/features/application/bloc/application_submission_bloc.dart';
import 'package:national_id_flutter_app/features/application/data/application_repository.dart';
import 'package:national_id_flutter_app/features/application/data/form_metadata.dart';
import 'package:national_id_flutter_app/features/auth/data/auth_session.dart';

class ApplicationFormScreen extends StatefulWidget {
  const ApplicationFormScreen({
    required this.token,
    required this.session,
    this.latestReference,
    this.onSubmittedReference,
    this.onTrackTap,
    this.onLogout,
    super.key,
  });

  final String token;
  final AuthSession session;
  final String? latestReference;
  final ValueChanged<String>? onSubmittedReference;
  final VoidCallback? onTrackTap;
  final VoidCallback? onLogout;

  @override
  State<ApplicationFormScreen> createState() => _ApplicationFormScreenState();
}

class _ApplicationFormScreenState extends State<ApplicationFormScreen> {
  static const _stepTitles = <String>[
    'Account',
    'Personal Info',
    'Documents',
    'Review',
  ];

  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _existingNinCtrl = TextEditingController();
  final _districtNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  late Future<FormMetadata> _metadataFuture;
  int _currentStep = 0;
  int? _selectedCountryId;
  DistrictOption? _selectedDistrict;
  String? _selectedGender;
  PlatformFile? _photoFile;
  PlatformFile? _lcLetterFile;

  @override
  void initState() {
    super.initState();
    _metadataFuture =
        context.read<ApplicationRepository>().fetchMetadata();
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _dobCtrl.dispose();
    _existingNinCtrl.dispose();
    _districtNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // ── helpers ─────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null) return;
    _dobCtrl.text =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickPhoto() async {
    final result =
        await FilePicker.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return;
    setState(() => _photoFile = result.files.single);
  }

  Future<void> _pickLetter() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _lcLetterFile = result.files.single);
  }

  bool _isValidEmail(String text) =>
      text.contains('@') && text.contains('.');

  int? _firstInvalidStep() {
    if (_fullNameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        !_isValidEmail(_emailCtrl.text.trim()) ||
        _phoneCtrl.text.trim().length < 10) return 0;
    if (_dobCtrl.text.trim().isEmpty ||
        _selectedGender == null ||
        _selectedCountryId == null ||
        _selectedDistrict == null) return 1;
    if (_photoFile == null || _lcLetterFile == null) return 2;
    return null;
  }

  bool _validateCurrentStep() {
    if (_currentStep == 2) {
      if (_photoFile != null && _lcLetterFile != null) return true;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Please upload both passport photo and LC letter.')));
      return false;
    }
    final valid = _formKey.currentState?.validate() ?? true;
    if (!valid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Please complete required fields before continuing.')));
    }
    return valid;
  }

  void _onContinue(ApplicationSubmissionState state) {
    if (_currentStep < _stepTitles.length - 1) {
      if (_validateCurrentStep()) setState(() => _currentStep++);
      return;
    }
    if (state.status != ApplicationSubmissionStatus.loading) _submit();
  }

  void _submit() {
    final invalid = _firstInvalidStep();
    if (invalid != null) {
      setState(() => _currentStep = invalid);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Please complete all required steps before submission.')));
      return;
    }
    context.read<ApplicationSubmissionBloc>().add(
          ApplicationSubmitRequested(
            token: widget.token,
            request: ApplicationFormRequest(
              fullName: _fullNameCtrl.text.trim(),
              dateOfBirth: _dobCtrl.text.trim(),
              gender: _selectedGender!,
              nationalityId: _selectedCountryId!,
              districtName: _districtNameCtrl.text.trim(),
              districtId: _selectedDistrict?.id,
              phone: _phoneCtrl.text.trim(),
              email: _emailCtrl.text.trim(),
              existingNin: _existingNinCtrl.text.trim(),
              photoFile: _photoFile!,
              lcLetterFile: _lcLetterFile!,
            ),
          ),
        );
  }

  // ── UI builders ──────────────────────────────────────────────────────────

  Widget _buildStepIndicator() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: [
          for (var i = 0; i < _stepTitles.length; i++) ...[
            _StepNode(
              index: i,
              title: _stepTitles[i],
              isDone: i < _currentStep,
              isActive: i == _currentStep,
            ),
            if (i < _stepTitles.length - 1)
              Expanded(
                child: Container(
                  height: 1,
                  color: i < _currentStep
                      ? kAccentGreen
                      : const Color(0xFFD6E4DC),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(ApplicationSubmissionState state) {
    final progress = (_currentStep + 1) / _stepTitles.length;
    final isLoading =
        state.status == ApplicationSubmissionStatus.loading;
    final isFinal = _currentStep == _stepTitles.length - 1;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: kBorderGreen)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Step ${_currentStep + 1} of ${_stepTitles.length} — '
                  '${_stepTitles[_currentStep]}',
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: const Color(0xFFD6E4DC),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(kAccentGreen),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: _currentStep == 0 || isLoading
                ? null
                : () => setState(() => _currentStep--),
            child: const Text('Back'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed:
                isLoading ? null : () => _onContinue(state),
            icon: Icon(isFinal ? Icons.send_outlined : Icons.arrow_forward),
            label: Text(
              isFinal
                  ? (isLoading ? 'Submitting…' : 'Submit')
                  : 'Continue',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard({
    required String title,
    required String hint,
    required IconData icon,
    required PlatformFile? file,
    required VoidCallback onTap,
  }) {
    final done = file != null;
    return Material(
      color: done ? kLightGreen : const Color(0xFFFAFCFB),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: done ? kAccentGreen : const Color(0xFFCAD8D0),
              width: done ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: done ? kAccentGreen : const Color(0xFFCAD8D0)),
                ),
                child: Icon(icon,
                    color: done ? kAccentGreen : Colors.black45),
              ),
              const SizedBox(height: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              if (done) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDF3E6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    file.name.length > 24
                        ? '${file.name.substring(0, 21)}…'
                        : file.name,
                    style: const TextStyle(
                        fontSize: 10,
                        color: kBrandGreen,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Tap to replace',
                    style: TextStyle(fontSize: 11, color: Colors.black38)),
              ] else
                Text(hint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.black38)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepBody({
    required FormMetadata metadata,
    required List<DistrictOption> filteredDistricts,
    required ApplicationSubmissionState state,
    required double contentWidth,
  }) {
    final twoCols = contentWidth >= 600;

    Widget grid(List<Widget> children) {
      final cols = twoCols ? 2 : 1;
      final gap = 12.0;
      final itemW = cols == 1
          ? contentWidth
          : (contentWidth - gap) / 2;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: children
            .map((c) => SizedBox(width: itemW, child: c))
            .toList(),
      );
    }

    switch (_currentStep) {
      case 0:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const NidSectionLabel('Account details'),
          TextFormField(
            controller: _fullNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Full legal name *',
              prefixIcon:
                  Icon(Icons.person_outline, color: kAccentGreen),
            ),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Full name is required.' : null,
          ),
          const SizedBox(height: 14),
          const NidSectionLabel('Contact information'),
          grid([
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email address *',
                prefixIcon:
                    Icon(Icons.email_outlined, color: kAccentGreen),
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                return t.isEmpty || !_isValidEmail(t)
                    ? 'Enter a valid email.'
                    : null;
              },
            ),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number *',
                prefixIcon:
                    Icon(Icons.phone_outlined, color: kAccentGreen),
              ),
              validator: (v) => (v ?? '').trim().length < 10
                  ? 'Phone must be at least 10 digits.'
                  : null,
            ),
            TextFormField(
              controller: _existingNinCtrl,
              decoration: const InputDecoration(
                labelText: 'Existing NIN (optional)',
                prefixIcon:
                    Icon(Icons.badge_outlined, color: kAccentGreen),
              ),
            ),
          ]),
        ]);

      case 1:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const NidSectionLabel('Personal details'),
          grid([
            TextFormField(
              controller: _dobCtrl,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Date of birth *',
                prefixIcon: const Icon(Icons.cake_outlined,
                    color: kAccentGreen),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_month,
                      color: kAccentGreen),
                  onPressed: _pickDate,
                ),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Date of birth is required.' : null,
            ),
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: const InputDecoration(
                labelText: 'Gender *',
                prefixIcon:
                    Icon(Icons.wc_outlined, color: kAccentGreen),
              ),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) =>
                  setState(() => _selectedGender = v),
              validator: (v) =>
                  v == null ? 'Gender is required.' : null,
            ),
            DropdownButtonFormField<int>(
              value: _selectedCountryId,
              decoration: const InputDecoration(
                labelText: 'Nationality *',
                prefixIcon:
                    Icon(Icons.public_outlined, color: kAccentGreen),
              ),
              items: metadata.countries
                  .map((c) => DropdownMenuItem<int>(
                      value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _selectedCountryId = v;
                  _selectedDistrict = null;
                  _districtNameCtrl.clear();
                });
              },
              validator: (v) =>
                  v == null ? 'Nationality is required.' : null,
            ),
            DropdownButtonFormField<DistrictOption>(
              value: _selectedDistrict,
              decoration: const InputDecoration(
                labelText: 'District of origin *',
                prefixIcon:
                    Icon(Icons.location_on_outlined, color: kAccentGreen),
              ),
              items: filteredDistricts
                  .map((d) => DropdownMenuItem<DistrictOption>(
                      value: d, child: Text(d.name)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _selectedDistrict = v;
                  _districtNameCtrl.text = v?.name ?? '';
                });
              },
              validator: (v) =>
                  v == null ? 'District is required.' : null,
            ),
          ]),
        ]);

      case 2:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const NidSectionLabel('Required attachments'),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: twoCols
                    ? (contentWidth - 12) / 2
                    : contentWidth,
                child: _buildUploadCard(
                  title: 'Passport photo',
                  hint: 'JPG or PNG, clear front face',
                  icon: Icons.badge_outlined,
                  file: _photoFile,
                  onTap: _pickPhoto,
                ),
              ),
              SizedBox(
                width: twoCols
                    ? (contentWidth - 12) / 2
                    : contentWidth,
                child: _buildUploadCard(
                  title: 'LC letter',
                  hint: 'PDF, JPG, PNG, DOC or DOCX',
                  icon: Icons.description_outlined,
                  file: _lcLetterFile,
                  onTap: _pickLetter,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const NidInfoBanner(
              'Ensure files are readable and match your entered details.'),
        ]);

      case 3:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const NidSectionLabel('Review & submit'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorderGreen),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _reviewRow('Full name', _fullNameCtrl.text),
                _reviewRow('Email', _emailCtrl.text),
                _reviewRow('Phone', _phoneCtrl.text),
                _reviewRow('Date of birth', _dobCtrl.text),
                _reviewRow('Gender', _selectedGender ?? '-'),
                _reviewRow(
                  'Nationality',
                  metadata.countries
                          .where((c) => c.id == _selectedCountryId)
                          .map((c) => c.name)
                          .firstOrNull ??
                      '-',
                ),
                _reviewRow('District', _selectedDistrict?.name ?? '-'),
                _reviewRow('Photo', _photoFile?.name ?? 'Not uploaded'),
                _reviewRow(
                    'LC letter', _lcLetterFile?.name ?? 'Not uploaded'),
              ],
            ),
          ),
          if (state.result != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kLightGreen,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBDD9C9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Application submitted successfully!',
                    style: TextStyle(
                      color: kBrandGreen,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tracking number: ${state.result!.reference}',
                    style: const TextStyle(
                      color: kBrandGreen,
                      fontSize: 13,
                      fontFamily: 'monospace',
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ]);

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.black45, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FormMetadata>(
      future: _metadataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Failed to load form data.\n${snapshot.error ?? ''}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final metadata = snapshot.data!;
        final filteredDistricts = metadata.districts
            .where((d) =>
                _selectedCountryId == null ||
                d.countryId == _selectedCountryId)
            .toList();

        return BlocConsumer<ApplicationSubmissionBloc,
            ApplicationSubmissionState>(
          listenWhen: (prev, curr) => prev.status != curr.status,
          listener: (context, state) {
            if (state.status == ApplicationSubmissionStatus.failure &&
                state.message != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.message!)));
            }
            if (state.status == ApplicationSubmissionStatus.success &&
                state.result != null) {
              widget.onSubmittedReference
                  ?.call(state.result!.reference);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      'Submitted. Reference: ${state.result!.reference}')));
            }
          },
          builder: (context, state) {
            return LayoutBuilder(builder: (context, constraints) {
              final maxW = math.min(constraints.maxWidth, 900.0);
              final bodyW = maxW - 40;

              return Column(
                children: [
                  // ── UNIFIED HEADER with user strip ──────────────────
                  NidHeader(
                    title: 'New National ID Application',
                    subtitle:
                        'Complete all required fields. Your information is encrypted and protected.',
                    userName: widget.session.user.name,
                    userEmail: widget.session.user.email,
                    latestReference: widget.latestReference,
                    onTrackTap: widget.onTrackTap,
                    onLogout: widget.onLogout,
                  ),
                  // ── Step indicator ───────────────────────────────────
                  _buildStepIndicator(),
                  // ── Scrollable form body ─────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: constraints.maxWidth > 600 ? 20 : 16,
                        vertical: 20,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxW),
                          child: Form(
                            key: _formKey,
                            child: _buildStepBody(
                              metadata: metadata,
                              filteredDistricts: filteredDistricts,
                              state: state,
                              contentWidth: bodyW,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // ── Footer with progress + buttons ───────────────────
                  _buildFooter(state),
                ],
              );
            });
          },
        );
      },
    );
  }
}

// ── Step node widget ─────────────────────────────────────────────────────────

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.index,
    required this.title,
    required this.isDone,
    required this.isActive,
  });

  final int index;
  final String title;
  final bool isDone;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final bgColor = isDone
        ? kBrandGreen
        : isActive
            ? kAccentGreen
            : Colors.white;
    final borderColor = isDone || isActive
        ? bgColor
        : const Color(0xFFCAD8D0);
    final textColor =
        isDone || isActive ? Colors.white : Colors.black38;
    final labelColor = isActive ? kAccentGreen : Colors.black38;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor),
          ),
          child: Text(
            isDone ? '✓' : '${index + 1}',
            style: TextStyle(
                color: textColor, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            color: labelColor,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
