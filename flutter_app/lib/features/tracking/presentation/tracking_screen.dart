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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Track Application',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (widget.suggestedReference != null &&
                  widget.suggestedReference!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.confirmation_number_outlined),
                    title: Text(widget.suggestedReference!),
                    subtitle: const Text('Latest tracking number'),
                    trailing: TextButton(
                      onPressed: () {
                        _referenceCtrl.text = widget.suggestedReference!;
                      },
                      child: const Text('Use'),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _referenceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tracking Number',
                  hintText: 'e.g. NID/2026/0001',
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: isLoading ? null : _track,
                child: Text(isLoading ? 'Checking...' : 'Check Status'),
              ),
              if (application != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reference: ${application.reference}'),
                        Text('Applicant: ${application.fullName}'),
                        Text('Current Status: ${application.statusLabel}'),
                        if (application.statusCode == 'rejected' &&
                            application.rejectionReason.isNotEmpty)
                          Text('Reason: ${application.rejectionReason}'),
                      ],
                    ),
                  ),
                ),
                if (application.decisionReason.isNotEmpty ||
                    application.nextStepRecommendation.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Card(
                    color: application.statusCode == 'rejected'
                        ? Theme.of(context).colorScheme.errorContainer
                        : Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            application.statusCode == 'rejected'
                                ? 'Why it was rejected'
                                : 'Decision Details',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (application.decisionReason.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(application.decisionReason),
                          ],
                          if (application
                              .nextStepRecommendation.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            const Text(
                              'What to do next',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(application.nextStepRecommendation),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                ...application.timeline.map(_buildTimelineTile),
              ],
            ],
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
}
