import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:national_id_flutter_app/features/tracking/bloc/tracking_bloc.dart';
import 'package:national_id_flutter_app/features/tracking/data/tracking_repository.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({
    this.suggestedReference,
    super.key,
  });

  final String? suggestedReference;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final _referenceCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final suggested = widget.suggestedReference;
    if (suggested != null && suggested.isNotEmpty) {
      _referenceCtrl.text = suggested;
    }
  }

  @override
  void didUpdateWidget(covariant TrackingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.suggestedReference != oldWidget.suggestedReference &&
        widget.suggestedReference != null &&
        widget.suggestedReference!.isNotEmpty) {
      _referenceCtrl.text = widget.suggestedReference!;
    }
  }

  @override
  void dispose() {
    _referenceCtrl.dispose();
    super.dispose();
  }

  void _track() {
    context.read<TrackingBloc>().add(TrackingRequested(_referenceCtrl.text));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TrackingBloc, TrackingState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == TrackingStatus.failure,
      listener: (context, state) {
        if (state.message == null) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.message!)),
        );
      },
      builder: (context, state) {
        final isLoading = state.status == TrackingStatus.loading;
        final application = state.application;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 700,
              minHeight: MediaQuery.of(context).size.height - 250,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Track Application',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0C3D28),
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.suggestedReference != null &&
                    widget.suggestedReference!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFCFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDEE8E2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.confirmation_number_outlined,
                            size: 20, color: Color(0xFF0C3D28)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Latest tracking',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF666666),
                                ),
                              ),
                              Text(
                                widget.suggestedReference!,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            _referenceCtrl.text = widget.suggestedReference!;
                          },
                          child: const Text('Use'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _referenceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tracking Number',
                    hintText: 'e.g. NID/2026/0001',
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: isLoading ? null : _track,
                  child: Text(isLoading ? 'Checking...' : 'Check Status'),
                ),
                if (application != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDEE8E2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Application Details',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailRow('Reference', application.reference),
                        _buildDetailRow('Applicant', application.fullName),
                        _buildDetailRow(
                          'Status',
                          application.statusLabel,
                          statusCode: application.statusCode,
                        ),
                        if (application.statusCode == 'rejected' &&
                            application.rejectionReason.isNotEmpty) ...[
                          _buildDetailRow('Reason', application.rejectionReason),
                        ],
                      ],
                    ),
                  ),
                  if (application.decisionReason.isNotEmpty ||
                      application.nextStepRecommendation.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: application.statusCode == 'rejected'
                            ? const Color(0xFFFEE4E4)
                            : const Color(0xFFE8F5E8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: application.statusCode == 'rejected'
                              ? const Color(0xFFE8B4B4)
                              : const Color(0xFFB4E8B4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            application.statusCode == 'rejected'
                                ? 'Why it was rejected'
                                : 'Decision Details',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: application.statusCode == 'rejected'
                                  ? const Color(0xFFC31C1C)
                                  : const Color(0xFF1B7E1B),
                            ),
                          ),
                          if (application.decisionReason.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              application.decisionReason,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                          if (application
                              .nextStepRecommendation.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Next Steps:',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    application.nextStepRecommendation,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimelineTile(TrackingStage stage) {
    final color = stage.completed ? Colors.green : Colors.grey;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        stage.completed ? Icons.check_circle : Icons.radio_button_unchecked,
        color: color,
      ),
      title: Text(stage.label),
      subtitle: Text(stage.code),
    );
  }

  Widget _buildDetailRow(String label, String value, {String? statusCode}) {
    Color textColor = const Color(0xFF333333);
    if (statusCode != null) {
      if (statusCode == 'rejected') {
        textColor = const Color(0xFFC31C1C);
      } else if (statusCode == 'approved') {
        textColor = const Color(0xFF1B7E1B);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF666666),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
