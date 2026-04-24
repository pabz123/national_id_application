// ignore_for_file: deprecated_member_use

import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:national_id_flutter_app/core/theme/app_theme.dart';
import 'package:national_id_flutter_app/core/theme/nid_header.dart';
import 'package:national_id_flutter_app/features/application/bloc/application_submission_bloc.dart';
import 'package:national_id_flutter_app/features/application/data/application_repository.dart';
import 'package:national_id_flutter_app/features/application/data/form_metadata.dart';
import 'package:national_id_flutter_app/features/auth/data/auth_session.dart';

// ── Text formatter: letters, spaces, hyphens and apostrophes only ─────────────
class _LettersOnlyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue next) {
    final filtered =
        next.text.replaceAll(RegExp(r"[^a-zA-Z\s\-']"), '');
    return next.copyWith(
        text: filtered,
        selection:
            TextSelection.collapsed(offset: filtered.length));
  }
}

// ── Text formatter: digits only (for phone numbers) ──────────────────────────
class _DigitsOnlyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue next) {
    // Allow digits and + symbol only
    final filtered = next.text.replaceAll(RegExp(r'[^0-9+]'), '');
    return next.copyWith(
        text: filtered,
        selection:
            TextSelection.collapsed(offset: filtered.length));
  }
}

// ── Country phone code mapping ───────────────────────────────────────────────
const Map<String, Map<String, dynamic>> countryPhoneCodes = {
  'Afghanistan': {'code': '+93', 'pattern': r'^\+93\d{9}$', 'length': 12},
  'Albania': {'code': '+355', 'pattern': r'^\+355\d{8}$', 'length': 12},
  'Algeria': {'code': '+213', 'pattern': r'^\+213\d{9}$', 'length': 13},
  'Angola': {'code': '+244', 'pattern': r'^\+244\d{9}$', 'length': 13},
  'Argentina': {'code': '+54', 'pattern': r'^\+54\d{10}$', 'length': 13},
  'Australia': {'code': '+61', 'pattern': r'^\+61\d{9}$', 'length': 12},
  'Austria': {'code': '+43', 'pattern': r'^\+43\d{9,10}$', 'length': 12},
  'Bangladesh': {'code': '+880', 'pattern': r'^\+880\d{10}$', 'length': 14},
  'Belgium': {'code': '+32', 'pattern': r'^\+32\d{9}$', 'length': 12},
  'Brazil': {'code': '+55', 'pattern': r'^\+55\d{10,11}$', 'length': 13},
  'Canada': {'code': '+1', 'pattern': r'^\+1\d{10}$', 'length': 12},
  'China': {'code': '+86', 'pattern': r'^\+86\d{10,11}$', 'length': 13},
  'Egypt': {'code': '+20', 'pattern': r'^\+20\d{10}$', 'length': 13},
  'Ethiopia': {'code': '+251', 'pattern': r'^\+251\d{9}$', 'length': 13},
  'France': {'code': '+33', 'pattern': r'^\+33\d{9}$', 'length': 12},
  'Germany': {'code': '+49', 'pattern': r'^\+49\d{10,11}$', 'length': 13},
  'Ghana': {'code': '+233', 'pattern': r'^\+233\d{9}$', 'length': 13},
  'Hong Kong': {'code': '+852', 'pattern': r'^\+852\d{8}$', 'length': 12},
  'India': {'code': '+91', 'pattern': r'^\+91\d{10}$', 'length': 12},
  'Indonesia': {'code': '+62', 'pattern': r'^\+62\d{9,10}$', 'length': 12},
  'Iran': {'code': '+98', 'pattern': r'^\+98\d{10}$', 'length': 13},
  'Ireland': {'code': '+353', 'pattern': r'^\+353\d{9}$', 'length': 13},
  'Israel': {'code': '+972', 'pattern': r'^\+972\d{8,9}$', 'length': 12},
  'Italy': {'code': '+39', 'pattern': r'^\+39\d{9,10}$', 'length': 12},
  'Japan': {'code': '+81', 'pattern': r'^\+81\d{9,10}$', 'length': 12},
  'Kenya': {'code': '+254', 'pattern': r'^\+254\d{9}$', 'length': 13},
  'Mexico': {'code': '+52', 'pattern': r'^\+52\d{10}$', 'length': 12},
  'Netherlands': {'code': '+31', 'pattern': r'^\+31\d{9}$', 'length': 12},
  'Nigeria': {'code': '+234', 'pattern': r'^\+234\d{10}$', 'length': 14},
  'Pakistan': {'code': '+92', 'pattern': r'^\+92\d{10}$', 'length': 12},
  'Philippines': {'code': '+63', 'pattern': r'^\+63\d{10}$', 'length': 12},
  'Poland': {'code': '+48', 'pattern': r'^\+48\d{9}$', 'length': 12},
  'Russia': {'code': '+7', 'pattern': r'^\+7\d{10}$', 'length': 12},
  'Saudi Arabia': {'code': '+966', 'pattern': r'^\+966\d{9}$', 'length': 13},
  'Singapore': {'code': '+65', 'pattern': r'^\+65\d{8}$', 'length': 11},
  'South Africa': {'code': '+27', 'pattern': r'^\+27\d{9}$', 'length': 12},
  'South Korea': {'code': '+82', 'pattern': r'^\+82\d{9,10}$', 'length': 12},
  'Spain': {'code': '+34', 'pattern': r'^\+34\d{9}$', 'length': 12},
  'Sweden': {'code': '+46', 'pattern': r'^\+46\d{9}$', 'length': 12},
  'Switzerland': {'code': '+41', 'pattern': r'^\+41\d{9}$', 'length': 12},
  'Thailand': {'code': '+66', 'pattern': r'^\+66\d{9}$', 'length': 12},
  'Turkey': {'code': '+90', 'pattern': r'^\+90\d{10}$', 'length': 12},
  'Uganda': {'code': '+256', 'pattern': r'^\+256\d{9}$', 'length': 13},
  'Ukraine': {'code': '+380', 'pattern': r'^\+380\d{9}$', 'length': 13},
  'United Kingdom': {'code': '+44', 'pattern': r'^\+44\d{10}$', 'length': 12},
  'United States': {'code': '+1', 'pattern': r'^\+1\d{10}$', 'length': 12},
  'Vietnam': {'code': '+84', 'pattern': r'^\+84\d{9}$', 'length': 12},
  'Zimbabwe': {'code': '+263', 'pattern': r'^\+263\d{9}$', 'length': 13},
};

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
  State<ApplicationFormScreen> createState() =>
      _ApplicationFormScreenState();
}

class _ApplicationFormScreenState
    extends State<ApplicationFormScreen> {
  static const _stepTitles = ['Account', 'Personal', 'Documents', 'Review'];

  final _formKey = GlobalKey<FormState>();

  // Step 0
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _existingNinCtrl = TextEditingController();

  // Step 1
  final _dobCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _nextOfKinNameCtrl = TextEditingController();
  final _nextOfKinPhoneCtrl = TextEditingController();

  late Future<FormMetadata> _metadataFuture;
  int _currentStep = 0;
  int? _selectedCountryId;
  String? _selectedCountryName;
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
    for (final c in [
      _fullNameCtrl,
      _emailCtrl,
      _phoneCtrl,
      _existingNinCtrl,
      _dobCtrl,
      _districtCtrl,
      _nextOfKinNameCtrl,
      _nextOfKinPhoneCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final now = DateTime.now();
    DateTime initial;
    try {
      if (_dobCtrl.text.isNotEmpty) {
        final parts = _dobCtrl.text.split('-');
        initial = DateTime(int.parse(parts[0]), int.parse(parts[1]),
            int.parse(parts[2]));
      } else {
        initial = DateTime(now.year - 18, now.month, now.day);
      }
    } catch (_) {
      initial = DateTime(now.year - 18, now.month, now.day);
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'SELECT DATE OF BIRTH',
    );
    if (picked == null) return;
    _dobCtrl.text =
        '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
    setState(() {});
  }

  bool _isValidDate(String text) {
    try {
      final parts = text.split('-');
      if (parts.length != 3) return false;
      final d = DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      return !d.isAfter(DateTime.now()) &&
          DateTime.now().difference(d).inDays < 120 * 365;
    } catch (_) {
      return false;
    }
  }

  bool _isValidEmail(String t) =>
      RegExp(r'^[\w.+-]+@[\w-]+\.[\w.]+$').hasMatch(t);

  Future<void> _pickPhoto() async {
    final r = await FilePicker.pickFiles(
        type: FileType.image, withData: true);
    if (r == null || r.files.isEmpty) return;
    setState(() => _photoFile = r.files.single);
  }

  Future<void> _pickLetter() async {
    final r = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'
      ],
      withData: true,
    );
    if (r == null || r.files.isEmpty) return;
    setState(() => _lcLetterFile = r.files.single);
  }

  int? _firstInvalidStep() {
     final t = _fullNameCtrl.text.trim();
    if (t.isEmpty || t.split(' ').length < 2) return 0;
    final e = _emailCtrl.text.trim();
    if (e.isEmpty || !_isValidEmail(e)) return 0;
    if (_phoneCtrl.text.trim().length < 10) return 0;
    if (!_isValidDate(_dobCtrl.text.trim())) return 1;
    if (_selectedGender == null) return 1;
    if (_selectedCountryId == null) return 1;
    if (_districtCtrl.text.trim().isEmpty) return 1;
    if (_nextOfKinNameCtrl.text.trim().isEmpty) return 1;
    if (_nextOfKinPhoneCtrl.text.trim().length < 10) return 1;
    if (_photoFile == null || _lcLetterFile == null) return 2;
    return null;
  }

  bool _validateCurrentStep() {
    if (_currentStep == 2) {
      if (_photoFile != null && _lcLetterFile != null) return true;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Upload both passport photo and LC letter.')));
      return false;
    }
    final ok = _formKey.currentState?.validate() ?? true;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Complete required fields first.')));
    }
    return ok;
  }

  void _onContinue(ApplicationSubmissionState state) {
    if (_currentStep < _stepTitles.length - 1) {
      if (_validateCurrentStep()) setState(() => _currentStep++);
      return;
    }
    if (state.status != ApplicationSubmissionStatus.loading) {
      _submit();
    }
  }

  void _submit() {
    final inv = _firstInvalidStep();
    if (inv != null) {
      setState(() => _currentStep = inv);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Complete all steps before submitting.')));
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
              districtName: _districtCtrl.text.trim(),
              districtId: null,
              phone: _phoneCtrl.text.trim(),
              email: _emailCtrl.text.trim(),
              existingNin: _existingNinCtrl.text.trim(),
              nextOfKinName: _nextOfKinNameCtrl.text.trim(),
              nextOfKinPhone: _nextOfKinPhoneCtrl.text.trim(),
              photoFile: _photoFile!,
              lcLetterFile: _lcLetterFile!,
            ),
          ),
        );
  }

  // ── Autocomplete builders ─────────────────────────────────────────────────

  Widget _nationalityField(List<CountryOption> countries) {
    return Autocomplete<CountryOption>(
      initialValue: _selectedCountryName != null
          ? TextEditingValue(text: _selectedCountryName!)
          : TextEditingValue.empty,
      displayStringForOption: (c) => c.name,
      optionsBuilder: (tv) => tv.text.isEmpty
          ? countries
          : countries.where((c) => c.name
              .toLowerCase()
              .contains(tv.text.toLowerCase())),
      onSelected: (opt) => setState(() {
        _selectedCountryId = opt.id;
        _selectedCountryName = opt.name;
        _districtCtrl.clear();
      }),
      fieldViewBuilder: (ctx, ctrl, focus, submit) =>
          TextFormField(
        controller: ctrl,
        focusNode: focus,
        decoration: const InputDecoration(
          labelText: 'Nationality *',
          prefixIcon:
              Icon(Icons.public_outlined, color: kAccentGreen),
        ),
        validator: (_) => _selectedCountryId == null
            ? 'Nationality is required.'
            : null,
      ),
      optionsViewBuilder: (ctx, onSel, opts) => _dropdownOptions(
          opts.map((e) => e).toList(),
          (o) => onSel(o as CountryOption),
          (o) => (o as CountryOption).name),
    );
  }

  Widget _districtField() {
    return TextFormField(
      controller: _districtCtrl,
      enabled: _selectedCountryId != null,
      decoration: InputDecoration(
        labelText: 'District of origin *',
        hintText: _selectedCountryId == null
            ? 'Select nationality first'
            : null,
        prefixIcon: const Icon(Icons.location_on_outlined,
            color: kAccentGreen),
      ),
      validator: (_) => _districtCtrl.text.trim().isEmpty
          ? 'District is required.'
          : null,
    );
  }

  Widget _dropdownOptions(List<dynamic> opts,
      void Function(dynamic) onSelect, String Function(dynamic) label) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: opts.length,
            itemBuilder: (_, i) => InkWell(
              onTap: () => onSelect(opts[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Text(label(opts[i]),
                    style: const TextStyle(fontSize: 14)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Upload card ───────────────────────────────────────────────────────────

  Widget _uploadCard({
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
              color:
                  done ? kAccentGreen : const Color(0xFFCAD8D0),
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
                      color: done
                          ? kAccentGreen
                          : const Color(0xFFCAD8D0)),
                ),
                child: Icon(icon,
                    color:
                        done ? kAccentGreen : Colors.black45),
              ),
              const SizedBox(height: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
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
                    style: TextStyle(
                        fontSize: 11, color: Colors.black38)),
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

  // ── Step body ─────────────────────────────────────────────────────────────

  Widget _reviewRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 130,
                child: Text(label,
                    style: const TextStyle(
                        color: Colors.black45, fontSize: 13))),
            Expanded(
                child: Text(value.isEmpty ? '—' : value,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500))),
          ],
        ),
      );

  Widget _buildStep(
      FormMetadata metadata,
      ApplicationSubmissionState state,
      double maxW) {
    final twoCols = maxW >= 560;
    final itemW = twoCols ? (maxW - 12) / 2 : maxW;

    Widget row(List<Widget> children) => Wrap(
          spacing: 12,
          runSpacing: 12,
          children: children
              .map((c) => SizedBox(width: itemW, child: c))
              .toList(),
        );

    switch (_currentStep) {
      // ── 0: Account ────────────────────────────────────────────────────────
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NidSectionLabel('Identity'),
            TextFormField(
              controller: _fullNameCtrl,
              inputFormatters: [_LettersOnlyFormatter()],
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full legal name *',
                prefixIcon: Icon(Icons.person_outline,
                    color: kAccentGreen),
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'Full name is required.';
                if (!RegExp(r'^[a-zA-Z]').hasMatch(t)) {
                  return 'Name must start with a letter.';
                }
                if (t.split(RegExp(r'\s+')).length < 2) {
                  return 'Please enter first and last name.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            const NidSectionLabel('Contact'),
            row([
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  prefixIcon: Icon(Icons.email_outlined,
                      color: kAccentGreen),
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
                inputFormatters: [_DigitsOnlyFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Phone *',
                  prefixIcon: Icon(Icons.phone_outlined,
                      color: kAccentGreen),
                  helperText: 'Enter your phone number',
                ),
                validator: (v) {
                  final phone = (v ?? '').trim();
                  if (phone.isEmpty) return 'Phone is required.';
                  if (phone.length < 10) {
                     return 'Phone must be at least 10 digits.';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _existingNinCtrl,
                decoration: const InputDecoration(
                  labelText: 'Existing NIN (optional)',
                  prefixIcon: Icon(Icons.badge_outlined,
                      color: kAccentGreen),
                ),
              ),
            ]),
          ],
        );

      // ── 1: Personal ───────────────────────────────────────────────────────
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NidSectionLabel('Personal details'),
            row([
              // DOB – tap to open calendar, also shows text
              TextFormField(
                controller: _dobCtrl,
                readOnly: true,
                onTap: _pickDate,
                decoration: const InputDecoration(
                  labelText: 'Date of birth *',
                  prefixIcon: Icon(Icons.cake_outlined,
                      color: kAccentGreen),
                  suffixIcon: Icon(Icons.calendar_month,
                      color: kAccentGreen),
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Date of birth required.';
                  if (!_isValidDate(t)) {
                    return 'Invalid date of birth.';
                  }
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: const InputDecoration(
                  labelText: 'Gender *',
                  prefixIcon: Icon(Icons.wc_outlined,
                      color: kAccentGreen),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'male', child: Text('Male')),
                  DropdownMenuItem(
                      value: 'female', child: Text('Female')),
                  DropdownMenuItem(
                      value: 'other', child: Text('Other')),
                ],
                onChanged: (v) =>
                    setState(() => _selectedGender = v),
                validator: (v) =>
                    v == null ? 'Gender is required.' : null,
              ),
            ]),
            const SizedBox(height: 12),
            // Nationality autocomplete – full width
            _nationalityField(metadata.countries),
            const SizedBox(height: 12),
            // District field (free-form text) – full width
            _districtField(),
            const SizedBox(height: 14),
            const NidSectionLabel('Next of kin'),
            row([
              TextFormField(
                controller: _nextOfKinNameCtrl,
                inputFormatters: [_LettersOnlyFormatter()],
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full name *',
                  prefixIcon: Icon(Icons.people_outline,
                      color: kAccentGreen),
                ),
                validator: (v) {
                  final name = (v ?? '').trim();
                  if (name.isEmpty) return 'Next of kin name required.';
                  if (name.split(RegExp(r'\s+')).length < 2) {
                    return 'Provide first and last name.';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _nextOfKinPhoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [_DigitsOnlyFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Phone number *',
                  prefixIcon: Icon(Icons.phone_in_talk_outlined,
                      color: kAccentGreen),
                  helperText: 'Enter phone number (10+ digits)',
                ),
                validator: (v) {
                  final phone = (v ?? '').trim();
                  if (phone.isEmpty) return 'Phone is required.';
                  if (phone.length < 10) {
                    return 'Phone must be at least 10 digits.';
                  }
                  return null;
                },
              ),
            ]),
          ],
        );

      // ── 2: Documents ──────────────────────────────────────────────────────
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NidSectionLabel('Attachments'),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: twoCols ? itemW : maxW,
                  child: _uploadCard(
                    title: 'Passport photo',
                    hint: 'JPG / PNG – clear face photo',
                    icon: Icons.badge_outlined,
                    file: _photoFile,
                    onTap: _pickPhoto,
                  ),
                ),
                SizedBox(
                  width: twoCols ? itemW : maxW,
                  child: _uploadCard(
                    title: 'LC letter',
                    hint: 'PDF / JPG / PNG / DOC',
                    icon: Icons.description_outlined,
                    file: _lcLetterFile,
                    onTap: _pickLetter,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const NidInfoBanner(
                'Files must be clear and readable. '
                'LC letter must be signed and stamped by your local council.'),
          ],
        );

      // ── 3: Review ─────────────────────────────────────────────────────────
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const NidSectionLabel('Review before submitting'),
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
                  _reviewRow('Existing NIN', _existingNinCtrl.text),
                  _reviewRow('Date of birth', _dobCtrl.text),
                  _reviewRow('Gender', _selectedGender ?? '—'),
                  _reviewRow('Nationality', _selectedCountryName ?? '—'),
                  _reviewRow('District', _districtCtrl.text),
                  _reviewRow('Next of kin', _nextOfKinNameCtrl.text),
                  _reviewRow(
                      'Next of kin tel.', _nextOfKinPhoneCtrl.text),
                  _reviewRow(
                      'Photo', _photoFile?.name ?? '✗ Not uploaded'),
                  _reviewRow('LC letter',
                      _lcLetterFile?.name ?? '✗ Not uploaded'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const NidInfoBanner(
                'Once submitted you cannot edit this application. '
                'Check everything carefully before clicking Submit.'),
            if (state.result != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kLightGreen,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFBDD9C9)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.check_circle,
                            color: kAccentGreen, size: 18),
                        SizedBox(width: 6),
                        Text('Application submitted!',
                            style: TextStyle(
                              color: kBrandGreen,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            )),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tracking number: ${state.result!.reference}',
                      style: const TextStyle(
                        color: kBrandGreen,
                        fontSize: 13,
                        fontFamily: 'monospace',
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Save this number to track your application status.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  // ── Step & footer bar ─────────────────────────────────────────────────────

  Widget _stepBar() => Container(
        color: Colors.white,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

  Widget _footer(ApplicationSubmissionState state) {
    final isLoading =
        state.status == ApplicationSubmissionStatus.loading;
    final isFinal = _currentStep == _stepTitles.length - 1;
    // Disable submit if already succeeded
    final alreadyDone =
        state.status == ApplicationSubmissionStatus.success;

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
                  'Step ${_currentStep + 1}/${_stepTitles.length} — '
                  '${_stepTitles[_currentStep]}',
                  style: const TextStyle(
                      fontSize: 11, color: Colors.black45),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value:
                        (_currentStep + 1) / _stepTitles.length,
                    minHeight: 4,
                    backgroundColor: const Color(0xFFD6E4DC),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(
                            kAccentGreen),
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
            onPressed: (isLoading || alreadyDone)
                ? null
                : () => _onContinue(state),
            icon: Icon(isFinal
                ? Icons.send_outlined
                : Icons.arrow_forward),
            label: Text(isFinal
                ? (isLoading ? 'Submitting…' : 'Submit')
                : 'Continue'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FormMetadata>(
      future: _metadataFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError || !snap.hasData) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off,
                      size: 48, color: Colors.black38),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load form.\n${snap.error ?? ''}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {
                      _metadataFuture = context
                          .read<ApplicationRepository>()
                          .fetchMetadata();
                    }),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final metadata = snap.data!;

        return BlocConsumer<ApplicationSubmissionBloc,
            ApplicationSubmissionState>(
          listenWhen: (p, c) => p.status != c.status,
          listener: (ctx, state) {
            if (state.status == ApplicationSubmissionStatus.failure &&
                state.message != null) {
              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                content: Text(state.message!),
                backgroundColor: Colors.red.shade700,
              ));
            }
            if (state.status == ApplicationSubmissionStatus.success &&
                state.result != null) {
              widget.onSubmittedReference
                  ?.call(state.result!.reference);
              // Move to review step to show success card
              if (_currentStep < 3) {
                setState(() => _currentStep = 3);
              }
            }
          },
          builder: (ctx, state) {
            return LayoutBuilder(builder: (_, constraints) {
              final maxW = math.min(constraints.maxWidth, 900.0);

              return Column(
                children: [
                  NidHeader(
                    title: 'New ID Application',
                    subtitle:
                        'Complete all fields. Data is encrypted & secure.',
                    userName: widget.session.user.name,
                    userEmail: widget.session.user.email,
                    latestReference: widget.latestReference,
                    onTrackTap: widget.onTrackTap,
                    onLogout: widget.onLogout,
                  ),
                  _stepBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal:
                            constraints.maxWidth > 600 ? 20 : 16,
                        vertical: 20,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(maxWidth: maxW),
                          child: Form(
                            key: _formKey,
                            child: _buildStep(
                                metadata, state, maxW - 40),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _footer(state),
                ],
              );
            });
          },
        );
      },
    );
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode(
      {required this.index,
      required this.title,
      required this.isDone,
      required this.isActive});
  final int index;
  final String title;
  final bool isDone;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final bg = isDone
        ? kBrandGreen
        : isActive
            ? kAccentGreen
            : Colors.white;
    final border =
        isDone || isActive ? bg : const Color(0xFFCAD8D0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(color: border)),
          child: Text(isDone ? '✓' : '${index + 1}',
              style: TextStyle(
                  color: isDone || isActive
                      ? Colors.white
                      : Colors.black38,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 4),
        Text(title,
            style: TextStyle(
                fontSize: 11,
                color: isActive ? kAccentGreen : Colors.black38,
                fontWeight: isActive
                    ? FontWeight.w600
                    : FontWeight.w400)),
      ],
    );
  }
}
