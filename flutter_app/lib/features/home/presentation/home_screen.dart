// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:national_id_flutter_app/core/storage/session_storage.dart';
import 'package:national_id_flutter_app/core/theme/app_theme.dart';
import 'package:national_id_flutter_app/features/application/presentation/application_form_screen.dart';
import 'package:national_id_flutter_app/features/auth/bloc/auth_bloc.dart';
import 'package:national_id_flutter_app/features/auth/data/auth_session.dart';
import 'package:national_id_flutter_app/features/tracking/bloc/tracking_bloc.dart';
import 'package:national_id_flutter_app/features/tracking/presentation/tracking_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.session, super.key});
  final AuthSession session;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _sessionStorage = SessionStorage();
  int _tabIndex = 0;
  String? _latestReference;

  @override
  void initState() {
    super.initState();
    _loadLatestReference();
  }

  Future<void> _loadLatestReference() async {
    final ref = await _sessionStorage.getLastTrackingReference();
    if (!mounted) return;
    setState(() => _latestReference = ref);
  }

  Future<void> _handleNewReference(String reference) async {
    await _sessionStorage.saveLastTrackingReference(reference);
    if (!mounted) return;
    setState(() {
      _latestReference = reference;
      _tabIndex = 1;
    });
  }

  void _openTrackingWithLatestReference() {
    final ref = _latestReference;
    if (ref == null || ref.isEmpty) return;
    context.read<TrackingBloc>().add(TrackingRequested(ref));
    setState(() => _tabIndex = 1);
  }

  void _logout() {
    context.read<AuthBloc>().add(const AuthLogoutRequested());
  }

  @override
  Widget build(BuildContext context) {
    // The two tab pages.
    // NOTE: We do NOT render a Scaffold AppBar here – each page owns its own
    // unified NidHeader so the header changes contextually per tab.
    final pages = [
      ApplicationFormScreen(
        token: widget.session.token,
        session: widget.session,
        latestReference: _latestReference,
        onSubmittedReference: _handleNewReference,
        onTrackTap: _openTrackingWithLatestReference,
        onLogout: _logout,
      ),
      TrackingScreen(
        session: widget.session,
        suggestedReference: _latestReference,
        onTrackTap: _openTrackingWithLatestReference,
        onLogout: _logout,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F5),
      // ── No AppBar – each screen renders its own NidHeader ──
      body: pages[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon:
                Icon(Icons.assignment, color: kAccentGreen),
            label: 'Apply',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon:
                Icon(Icons.search, color: kAccentGreen),
            label: 'Track',
          ),
        ],
      ),
    );
  }
}
