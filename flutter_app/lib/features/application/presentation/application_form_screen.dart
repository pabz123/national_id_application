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
    super.key,
  });

  final String token;

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
                _selectedCountryId == null || district.countryId == _selectedCountryId)
            .toList(growable: false);

        return BlocConsumer<ApplicationSubmissionBloc, ApplicationSubmissionState>(
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
            final isLoading = state.status == ApplicationSubmissionStatus.loading;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'New National ID Application',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fullNameCtrl,
                      decoration: const InputDecoration(labelText: 'Full Name *'),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Full name is required.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _dobCtrl,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Date of Birth *',
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
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: const InputDecoration(labelText: 'Gender *'),
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text('Male')),
                        DropdownMenuItem(value: 'female', child: Text('Female')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (value) => setState(() => _selectedGender = value),
                      validator: (value) => value == null ? 'Gender is required.' : null,
                    ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
                    DropdownButtonFormField<DistrictOption>(
                      value: _selectedDistrict,
                      decoration:
                          const InputDecoration(labelText: 'District of Origin *'),
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
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Phone Number *'),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if ((value ?? '').trim().length < 10) {
                          return 'Phone number must be at least 10 digits.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(labelText: 'Email *'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        final text = (value ?? '').trim();
                        if (text.isEmpty || !text.contains('@')) {
                          return 'Enter a valid email.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _existingNinCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Existing NIN (optional)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _pickPhoto,
                      icon: const Icon(Icons.photo),
                      label: Text(
                        _photoFile == null
                            ? 'Upload Passport Photo *'
                            : 'Photo: ${_photoFile!.name}',
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _pickLetter,
                      icon: const Icon(Icons.attach_file),
                      label: Text(
                        _lcLetterFile == null
                            ? 'Upload LC Letter *'
                            : 'LC Letter: ${_lcLetterFile!.name}',
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: isLoading ? null : _submit,
                      child: Text(isLoading ? 'Submitting...' : 'Submit Application'),
                    ),
                    if (state.result != null) ...[
                      const SizedBox(height: 16),
                      Card(
                        child: ListTile(
                          title: const Text('Latest Submission'),
                          subtitle: Text(
                            'Tracking Number: ${state.result!.reference}\n'
                            'Status: ${state.result!.status}',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
