// ignore_for_file: deprecated_member_use

import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:national_id_flutter_app/features/application/bloc/application_submission_bloc.dart';
import 'package:national_id_flutter_app/features/application/data/application_repository.dart';
import 'package:national_id_flutter_app/features/application/data/form_metadata.dart';

class ApplicationFormScreen extends StatefulWidget {
  const ApplicationFormScreen({
    required this.token,
    this.onSubmittedReference,
    super.key,
  });

  final String token;
  final ValueChanged<String>? onSubmittedReference;

  @override
  State<ApplicationFormScreen> createState() => _ApplicationFormScreenState();
}

class _ApplicationFormScreenState extends State<ApplicationFormScreen> {
  static const _brandGreen = Color(0xFF0C3D28);
  static const _accentGreen = Color(0xFF1A6B44);
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
    _metadataFuture = context.read<ApplicationRepository>().fetchMetadata();
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null) {
      return;
    }
    _dobCtrl.text =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    setState(() {
      _photoFile = result.files.single;
    });
  }

  Future<void> _pickLetter() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    setState(() {
      _lcLetterFile = result.files.single;
    });
  }

  bool _isValidEmail(String text) {
    return text.contains('@') && text.contains('.');
  }

  int? _firstInvalidStep() {
    if (_fullNameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        !_isValidEmail(_emailCtrl.text.trim()) ||
        _phoneCtrl.text.trim().length < 10) {
      return 0;
    }
    if (_dobCtrl.text.trim().isEmpty ||
        _selectedGender == null ||
        _selectedCountryId == null ||
        _selectedDistrict == null) {
      return 1;
    }
    if (_photoFile == null || _lcLetterFile == null) {
      return 2;
    }
    return null;
  }

  bool _validateStep() {
    if (_currentStep == 2) {
      if (_photoFile != null && _lcLetterFile != null) {
        return true;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload both passport photo and LC letter.'),
        ),
      );
      return false;
    }
    final isValid = _formKey.currentState?.validate() ?? true;
    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete required fields before continuing.'),
        ),
      );
    }
    return isValid;
  }

  void _onContinue(ApplicationSubmissionState state) {
    if (_currentStep < _stepTitles.length - 1) {
      if (_validateStep()) {
        setState(() {
          _currentStep += 1;
        });
      }
      return;
    }
    if (state.status != ApplicationSubmissionStatus.loading) {
      _submit();
    }
  }

  void _submit() {
    final invalidStep = _firstInvalidStep();
    if (invalidStep != null) {
      setState(() {
        _currentStep = invalidStep;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please complete all required steps before submission.'),
        ),
      );
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

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: const TextStyle(
              color: _accentGreen,
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Divider(height: 1, color: Color(0xFFD6E4DC)),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveGrid({
    required int columns,
    required List<Widget> children,
    required double maxWidth,
  }) {
    final safeColumns = math.max(1, columns);
    final gap = 12.0;
    final itemWidth = safeColumns == 1
        ? maxWidth
        : (maxWidth - ((safeColumns - 1) * gap)) / safeColumns;
    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: children
          .map((child) => SizedBox(width: itemWidth, child: child))
          .toList(growable: false),
    );
  }

  Widget _buildUploadCard({
    required String title,
    required String hint,
    required IconData icon,
    required PlatformFile? file,
    required VoidCallback onTap,
  }) {
    final isDone = file != null;
    final color = isDone ? _accentGreen : const Color(0xFF9BB5A8);
    return Material(
      color: isDone ? const Color(0xFFF0FAF4) : const Color(0xFFFAFCFB),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: color,
            radius: 12,
            dashWidth: 7,
            dashSpace: 5,
            solid: isDone,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: isDone ? _accentGreen : color),
                  ),
                  child: Icon(icon,
                      color: isDone ? _accentGreen : Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                if (isDone) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDF3E6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _brandGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Tap to replace',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ] else
                  Text(
                    hint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
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
    final twoCols = contentWidth >= 700;
    final threeCols = contentWidth >= 860;

    switch (_currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel('Account details'),
            TextFormField(
              controller: _fullNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full legal name *',
                hintText: 'As on birth certificate',
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Full name is required.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _buildSectionLabel('Contact & location'),
            _buildResponsiveGrid(
              columns: threeCols ? 3 : 1,
              maxWidth: contentWidth,
              children: [
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                      const InputDecoration(labelText: 'Email address *'),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty || !_isValidEmail(text)) {
                      return 'Enter a valid email.';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(labelText: 'Phone number *'),
                  validator: (value) {
                    if ((value ?? '').trim().length < 10) {
                      return 'Phone number must be at least 10 digits.';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _existingNinCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Existing NIN (optional)'),
                ),
              ],
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel('Personal details'),
            _buildResponsiveGrid(
              columns: twoCols ? 2 : 1,
              maxWidth: contentWidth,
              children: [
                TextFormField(
                  controller: _dobCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Date of birth *',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_month),
                      onPressed: _pickDate,
                    ),
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Date of birth is required.';
                    }
                    return null;
                  },
                ),
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(labelText: 'Gender *'),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) => setState(() => _selectedGender = value),
                  validator: (value) =>
                      value == null ? 'Gender is required.' : null,
                ),
                DropdownButtonFormField<int>(
                  value: _selectedCountryId,
                  decoration: const InputDecoration(labelText: 'Nationality *'),
                  items: metadata.countries
                      .map(
                        (country) => DropdownMenuItem<int>(
                          value: country.id,
                          child: Text(country.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    setState(() {
                      _selectedCountryId = value;
                      _selectedDistrict = null;
                      _districtNameCtrl.clear();
                    });
                  },
                  validator: (value) =>
                      value == null ? 'Nationality is required.' : null,
                ),
                DropdownButtonFormField<DistrictOption>(
                  value: _selectedDistrict,
                  decoration:
                      const InputDecoration(labelText: 'District of origin *'),
                  items: filteredDistricts
                      .map(
                        (district) => DropdownMenuItem<DistrictOption>(
                          value: district,
                          child: Text(district.name),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    setState(() {
                      _selectedDistrict = value;
                      _districtNameCtrl.text = value?.name ?? '';
                    });
                  },
                  validator: (value) =>
                      value == null ? 'District is required.' : null,
                ),
              ],
            ),
          ],
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel('Required attachments'),
            _buildResponsiveGrid(
              columns: twoCols ? 2 : 1,
              maxWidth: contentWidth,
              children: [
                _buildUploadCard(
                  title: 'Passport photo',
                  hint: 'JPG or PNG, clear front face',
                  icon: Icons.badge_outlined,
                  file: _photoFile,
                  onTap: _pickPhoto,
                ),
                _buildUploadCard(
                  title: 'LC letter',
                  hint: 'PDF, JPG, PNG, DOC, DOCX',
                  icon: Icons.description_outlined,
                  file: _lcLetterFile,
                  onTap: _pickLetter,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FAF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFC0E8D4)),
              ),
              child: const Text(
                'Ensure files are readable and match your entered details before continuing.',
                style: TextStyle(fontSize: 12, color: _accentGreen),
              ),
            ),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel('Review & submit'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD6E4DC)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Full name: ${_fullNameCtrl.text.trim()}'),
                  Text('Email: ${_emailCtrl.text.trim()}'),
                  Text('Phone: ${_phoneCtrl.text.trim()}'),
                  Text('Date of birth: ${_dobCtrl.text.trim()}'),
                  Text('Gender: ${_selectedGender ?? '-'}'),
                  Text(
                    'Nationality: ${metadata.countries.where((c) => c.id == _selectedCountryId).map((c) => c.name).firstOrNull ?? '-'}',
                  ),
                  Text('District: ${_selectedDistrict?.name ?? '-'}'),
                  Text(
                    'Passport photo: ${_photoFile?.name ?? 'Not uploaded'}',
                  ),
                  Text('LC letter: ${_lcLetterFile?.name ?? 'Not uploaded'}'),
                ],
              ),
            ),
            if (state.result != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F3EA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBDD9C9)),
                ),
                child: Text(
                  'Submitted successfully. Tracking Number: ${state.result!.reference}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildWizardHeader() {
    return Container(
      color: _brandGreen,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Stack(
        children: [
          Positioned(
            right: -38,
            top: -35,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.05),
                  width: 28,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Color(0xFFC8E8D5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Republic of Uganda',
                          style: TextStyle(
                            color: Color(0xFF9BD0B5),
                            fontSize: 12,
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'National Identification & Registration Authority',
                          style: TextStyle(
                            color: Color(0xFFC8E8D5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'New National ID Application',
                style: GoogleFonts.dmSerifDisplay(
                  color: Colors.white,
                  fontSize: 27,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Complete all required fields. Your information is encrypted and protected.',
                style: TextStyle(color: Color(0xFFC8E8D5), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      color: const Color(0xFFFAFCFB),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                  color:
                      i < _currentStep ? _accentGreen : const Color(0xFFD6E4DC),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(ApplicationSubmissionState state) {
    final progress = (_currentStep + 1) / _stepTitles.length;
    final isLoading = state.status == ApplicationSubmissionStatus.loading;
    final isFinalStep = _currentStep == _stepTitles.length - 1;

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFD6E4DC))),
        color: Color(0xFFFAFCFB),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Step ${_currentStep + 1} of ${_stepTitles.length} — ${_stepTitles[_currentStep]}',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    value: progress,
                    backgroundColor: const Color(0xFFD6E4DC),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(_accentGreen),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: _currentStep == 0 || isLoading
                ? null
                : () {
                    setState(() {
                      _currentStep -= 1;
                    });
                  },
            child: const Text('Back'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: isLoading ? null : () => _onContinue(state),
            style: ElevatedButton.styleFrom(backgroundColor: _brandGreen),
            icon: Icon(isFinalStep ? Icons.send : Icons.arrow_forward),
            label: Text(
              isFinalStep
                  ? (isLoading ? 'Submitting...' : 'Submit')
                  : 'Continue',
            ),
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
                'Failed to load countries/districts.\n${snapshot.error ?? ''}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final metadata = snapshot.data!;
        final filteredDistricts = metadata.districts
            .where((district) =>
                _selectedCountryId == null ||
                district.countryId == _selectedCountryId)
            .toList(growable: false);

        return BlocConsumer<ApplicationSubmissionBloc,
            ApplicationSubmissionState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            if (state.status == ApplicationSubmissionStatus.failure &&
                state.message != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message!)),
              );
            }
            if (state.status == ApplicationSubmissionStatus.success &&
                state.result != null) {
              widget.onSubmittedReference?.call(state.result!.reference);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Submitted. Tracking Number: ${state.result!.reference}',
                  ),
                ),
              );
            }
          },
          builder: (context, state) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final shellWidth =
                    math.min(constraints.maxWidth, 920.0).toDouble();
                final bodyWidth = shellWidth - 40;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: shellWidth),
                    child: Container(
                      margin: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFD6E4DC)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          _buildWizardHeader(),
                          _buildStepIndicator(),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Form(
                                key: _formKey,
                                child: _buildStepBody(
                                  metadata: metadata,
                                  filteredDistricts: filteredDistricts,
                                  state: state,
                                  contentWidth: bodyWidth,
                                ),
                              ),
                            ),
                          ),
                          _buildFooter(state),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

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
        ? const Color(0xFF0C3D28)
        : isActive
            ? const Color(0xFF1A6B44)
            : Colors.white;
    final borderColor = isDone || isActive ? bgColor : const Color(0xFFCAD8D0);
    final textColor = isDone || isActive
        ? Colors.white
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final labelColor = isActive
        ? const Color(0xFF1A6B44)
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor),
          ),
          child: Text(
            isDone ? '✓' : '${index + 1}',
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: labelColor,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.dashWidth,
    required this.dashSpace,
    required this.solid,
  });

  final Color color;
  final double radius;
  final double dashWidth;
  final double dashSpace;
  final bool solid;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rRect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    if (solid) {
      canvas.drawRRect(rRect, paint);
      return;
    }

    final path = Path()..addRRect(rRect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace ||
        oldDelegate.solid != solid;
  }
}
