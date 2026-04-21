// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:national_id_flutter_app/core/theme/app_theme.dart';
import 'package:national_id_flutter_app/core/theme/nid_header.dart';
import 'package:national_id_flutter_app/features/auth/data/auth_session.dart';
import 'package:national_id_flutter_app/features/tracking/bloc/tracking_bloc.dart';
import 'package:national_id_flutter_app/features/tracking/data/tracking_repository.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({
    required this.session,
    this.suggestedReference,
    this.onTrackTap,
    this.onLogout,
    super.key,
  });

  final AuthSession session;
  final String? suggestedReference;
  final VoidCallback? onTrackTap;
  final VoidCallback? onLogout;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final _referenceCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final s = widget.suggestedReference;
    if (s != null && s.isNotEmpty) _referenceCtrl.text = s;
  }

  @override
  void didUpdateWidget(covariant TrackingScreen old) {
    super.didUpdateWidget(old);
    if (widget.suggestedReference != old.suggestedReference &&
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
    context
        .read<TrackingBloc>()
        .add(TrackingRequested(_referenceCtrl.text));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TrackingBloc, TrackingState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status &&
          curr.status == TrackingStatus.failure,
      listener: (context, state) {
        if (state.message != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.message!)));
        }
      },
      builder: (context, state) {
        final isLoading = state.status == TrackingStatus.loading;
        final app = state.application;

        return Column(
          children: [
            // ── UNIFIED HEADER with user strip ──────────────────────────
            NidHeader(
              title: 'Track Application',
              subtitle:
                  'Enter your tracking number to check your application status.',
              userName: widget.session.user.name,
              userEmail: widget.session.user.email,
              latestReference: widget.suggestedReference,
              onTrackTap: widget.onTrackTap,
              onLogout: widget.onLogout,
            ),
            // ── Loading indicator ────────────────────────────────────────
            if (isLoading)
              const LinearProgressIndicator(
                backgroundColor: kLightGreen,
                color: kAccentGreen,
                minHeight: 3,
              ),
            // ── Scrollable content ───────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Quick-use suggestion card
                        if (widget.suggestedReference != null &&
                            widget.suggestedReference!.isNotEmpty) ...[
                          _buildSuggestionCard(),
                          const SizedBox(height: 14),
                        ],
                        // Search input
                        TextField(
                          controller: _referenceCtrl,
                          decoration: InputDecoration(
                            labelText: 'Tracking number',
                            hintText: 'e.g. NID/2026/0001',
                            prefixIcon: const Icon(
                                Icons.confirmation_number_outlined,
                                color: kAccentGreen),
                            suffixIcon: isLoading
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: kAccentGreen),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: isLoading ? null : _track,
                          icon: const Icon(Icons.search),
                          label: Text(
                              isLoading ? 'Checking…' : 'Check Status'),
                        ),
                        // Results
                        if (app != null) ...[
                          const SizedBox(height: 20),
                          _buildResultCard(context, app),
                          if (app.decisionReason.isNotEmpty ||
                              app.nextStepRecommendation.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildDecisionCard(context, app),
                          ],
                          const SizedBox(height: 12),
                          _buildTimeline(app),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSuggestionCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kLightGreen,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC0E8D4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.confirmation_number_outlined,
              size: 18, color: kBrandGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Latest tracking',
                    style: TextStyle(fontSize: 11, color: kMintText)),
                Text(
                  widget.suggestedReference!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kBrandGreen,
                    fontFamily: 'monospace',
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () =>
                _referenceCtrl.text = widget.suggestedReference!,
            style: TextButton.styleFrom(foregroundColor: kAccentGreen),
            child: const Text('Use'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(
      BuildContext context, TrackingApplication app) {
    Color statusColor;
    IconData statusIcon;
    if (app.statusCode == 'approved') {
      statusColor = kAccentGreen;
      statusIcon = Icons.check_circle_outline;
    } else if (app.statusCode == 'rejected') {
      statusColor = const Color(0xFFC31C1C);
      statusIcon = Icons.cancel_outlined;
    } else {
      statusColor = const Color(0xFFB07D1A);
      statusIcon = Icons.schedule_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Application details',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.black45,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text(app.reference,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          color: kBrandGreen,
                          letterSpacing: 0.4,
                        )),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 5),
                    Text(app.statusLabel,
                        style: TextStyle(
                            fontSize: 12,
                            color: statusColor,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: kBorderGreen),
          _detailRow('Applicant', app.fullName),
          if (app.statusCode == 'rejected' &&
              app.rejectionReason.isNotEmpty)
            _detailRow('Rejection reason', app.rejectionReason,
                valueColor: const Color(0xFFC31C1C)),
        ],
      ),
    );
  }

  Widget _buildDecisionCard(
      BuildContext context, TrackingApplication app) {
    final isRejected = app.statusCode == 'rejected';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRejected
            ? const Color(0xFFFEE4E4)
            : const Color(0xFFEAF5F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRejected
              ? const Color(0xFFE8B4B4)
              : const Color(0xFFB4D9C9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRejected ? 'Why it was rejected' : 'Decision details',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isRejected
                  ? const Color(0xFFC31C1C)
                  : kBrandGreen,
              fontSize: 13,
            ),
          ),
          if (app.decisionReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(app.decisionReason,
                style: const TextStyle(fontSize: 13, height: 1.5)),
          ],
          if (app.nextStepRecommendation.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Next steps',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(app.nextStepRecommendation,
                      style: const TextStyle(fontSize: 13, height: 1.5)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeline(TrackingApplication app) {
    if (app.timeline.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NidSectionLabel('Application timeline'),
          ...app.timeline.map((stage) {
            final done = stage.completed;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    done
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: done ? kAccentGreen : Colors.black26,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stage.label,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: done
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: done
                                  ? Colors.black87
                                  : Colors.black38)),
                      Text(stage.code,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black38)),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(
                    color: Colors.black45, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
