// ignore_for_file: deprecated_member_use

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _existingNinCtrl = TextEditingController();
  final _districtNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  late Future<FormMetadata> _metadataFuture;
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

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_photoFile == null || _lcLetterFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both photo and LC letter files.'),
        ),
      );
      return;
    }

    context.read<ApplicationSubmissionBloc>().add(
          ApplicationSubmitRequested(
            token: widget.token,
            request: ApplicationFormRequest(
              fullName: _fullNameCtrl.text,
              dateOfBirth: _dobCtrl.text,
              gender: _selectedGender!,
              nationalityId: _selectedCountryId!,
              districtName: _districtNameCtrl.text,
              districtId: _selectedDistrict?.id,
              phone: _phoneCtrl.text,
              email: _emailCtrl.text,
              existingNin: _existingNinCtrl.text,
              photoFile: _photoFile!,
              lcLetterFile: _lcLetterFile!,
            ),
          ),
        );
  }

  String _fileLabel(String title, PlatformFile? file) {
    if (file == null) {
      return '$title *';
    }
    final name = file.name;
    final shortName = name.length > 28 ? '${name.substring(0, 25)}...' : name;
    return '$title: $shortName';
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
              final reference = state.result!.reference;
              widget.onSubmittedReference?.call(reference);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Submitted. Tracking Number: $reference'),
                ),
              );
            }
          },
          builder: (context, state) {
            final isLoading =
                state.status == ApplicationSubmissionStatus.loading;
            return LayoutBuilder(
              builder: (context, constraints) {
                final maxContentWidth =
                    constraints.maxWidth > 1000 ? 1000.0 : constraints.maxWidth;
                final useTwoColumns = maxContentWidth >= 760;
                final fieldWidth = useTwoColumns
                    ? (maxContentWidth - 12) / 2
                    : maxContentWidth;

                Widget fieldBox(Widget child, {bool fullWidth = false}) =>
                    SizedBox(
                      width: (!useTwoColumns || fullWidth)
                          ? maxContentWidth
                          : fieldWidth,
                      child: child,
                    );

                return Align(
                  alignment: Alignment.topCenter,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: Form(
                        key: _formKey,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'New National ID Application',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Fill all required fields marked with *',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (state.result != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE5F3EA),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: const Color(0xFFBDD9C9)),
                                    ),
                                    child: Text(
                                      'Latest Tracking Number: ${state.result!.reference}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    fieldBox(
                                      TextFormField(
                                        controller: _fullNameCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Full Name *',
                                          prefixIcon:
                                              Icon(Icons.person_outline),
                                        ),
                                        validator: (value) {
                                          if ((value ?? '').trim().isEmpty) {
                                            return 'Full name is required.';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    fieldBox(
                                      TextFormField(
                                        controller: _dobCtrl,
                                        readOnly: true,
                                        decoration: InputDecoration(
                                          labelText: 'Date of Birth *',
                                          prefixIcon:
                                              const Icon(Icons.cake_outlined),
                                          suffixIcon: IconButton(
                                            icon: const Icon(
                                                Icons.calendar_month),
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
                                    ),
                                    fieldBox(
                                      DropdownButtonFormField<String>(
                                        value: _selectedGender,
                                        decoration: const InputDecoration(
                                          labelText: 'Gender *',
                                          prefixIcon: Icon(Icons.wc_outlined),
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                              value: 'male',
                                              child: Text('Male')),
                                          DropdownMenuItem(
                                              value: 'female',
                                              child: Text('Female')),
                                          DropdownMenuItem(
                                              value: 'other',
                                              child: Text('Other')),
                                        ],
                                        onChanged: (value) => setState(
                                            () => _selectedGender = value),
                                        validator: (value) => value == null
                                            ? 'Gender is required.'
                                            : null,
                                      ),
                                    ),
                                    fieldBox(
                                      DropdownButtonFormField<int>(
                                        value: _selectedCountryId,
                                        decoration: const InputDecoration(
                                          labelText: 'Nationality *',
                                          prefixIcon:
                                              Icon(Icons.public_outlined),
                                        ),
                                        items: metadata.countries
                                            .map(
                                              (country) =>
                                                  DropdownMenuItem<int>(
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
                                        validator: (value) => value == null
                                            ? 'Nationality is required.'
                                            : null,
                                      ),
                                    ),
                                    fieldBox(
                                      DropdownButtonFormField<DistrictOption>(
                                        value: _selectedDistrict,
                                        decoration: const InputDecoration(
                                          labelText: 'District of Origin *',
                                          prefixIcon:
                                              Icon(Icons.location_on_outlined),
                                        ),
                                        items: filteredDistricts
                                            .map(
                                              (district) => DropdownMenuItem<
                                                  DistrictOption>(
                                                value: district,
                                                child: Text(district.name),
                                              ),
                                            )
                                            .toList(growable: false),
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedDistrict = value;
                                            _districtNameCtrl.text =
                                                value?.name ?? '';
                                          });
                                        },
                                        validator: (value) => value == null
                                            ? 'District is required.'
                                            : null,
                                      ),
                                    ),
                                    fieldBox(
                                      TextFormField(
                                        controller: _phoneCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Phone Number *',
                                          prefixIcon:
                                              Icon(Icons.phone_outlined),
                                        ),
                                        keyboardType: TextInputType.phone,
                                        validator: (value) {
                                          if ((value ?? '').trim().length <
                                              10) {
                                            return 'Phone number must be at least 10 digits.';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    fieldBox(
                                      TextFormField(
                                        controller: _emailCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Email *',
                                          prefixIcon:
                                              Icon(Icons.email_outlined),
                                        ),
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        validator: (value) {
                                          final text = (value ?? '').trim();
                                          if (text.isEmpty ||
                                              !text.contains('@')) {
                                            return 'Enter a valid email.';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    fieldBox(
                                      TextFormField(
                                        controller: _existingNinCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Existing NIN (optional)',
                                          prefixIcon:
                                              Icon(Icons.badge_outlined),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Required Attachments',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    fieldBox(
                                      OutlinedButton.icon(
                                        onPressed: _pickPhoto,
                                        icon: const Icon(Icons.photo_outlined),
                                        label: Text(
                                          _fileLabel(
                                              'Passport Photo', _photoFile),
                                        ),
                                      ),
                                    ),
                                    fieldBox(
                                      OutlinedButton.icon(
                                        onPressed: _pickLetter,
                                        icon: const Icon(Icons.attach_file),
                                        label: Text(
                                          _fileLabel(
                                              'LC Letter', _lcLetterFile),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                fieldBox(
                                  ElevatedButton.icon(
                                    onPressed: isLoading ? null : _submit,
                                    icon: const Icon(Icons.send_outlined),
                                    label: Text(
                                      isLoading
                                          ? 'Submitting...'
                                          : 'Submit Application',
                                    ),
                                  ),
                                  fullWidth: true,
                                ),
                              ],
                            ),
                          ),
                        ),
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
