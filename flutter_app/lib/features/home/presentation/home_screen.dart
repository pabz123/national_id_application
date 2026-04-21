import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:national_id_flutter_app/core/storage/session_storage.dart';
import 'package:national_id_flutter_app/features/application/presentation/application_form_screen.dart';
import 'package:national_id_flutter_app/features/auth/bloc/auth_bloc.dart';
import 'package:national_id_flutter_app/features/auth/data/auth_session.dart';
import 'package:national_id_flutter_app/features/tracking/bloc/tracking_bloc.dart';
import 'package:national_id_flutter_app/features/tracking/presentation/tracking_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.session,
    super.key,
  });

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
    final savedReference = await _sessionStorage.getLastTrackingReference();
    if (!mounted) {
      return;
    }
    setState(() {
      _latestReference = savedReference;
    });
  }

  Future<void> _handleNewReference(String reference) async {
    await _sessionStorage.saveLastTrackingReference(reference);
    if (!mounted) {
      return;
    }
    setState(() {
      _latestReference = reference;
      _tabIndex = 1;
    });
  }

  void _openTrackingWithLatestReference() {
    final reference = _latestReference;
    if (reference == null || reference.isEmpty) {
      return;
    }
    context.read<TrackingBloc>().add(TrackingRequested(reference));
    setState(() {
      _tabIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ApplicationFormScreen(
        token: widget.session.token,
        onSubmittedReference: _handleNewReference,
      ),
      TrackingScreen(suggestedReference: _latestReference),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('National ID Mobile'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              context.read<AuthBloc>().add(const AuthLogoutRequested());
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.session.user.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.session.user.email,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF666666),
                  ),
                ),
                if (_latestReference != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFCFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDEE8E2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.confirmation_number_outlined,
                            size: 18, color: Color(0xFF0C3D28)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Latest Tracking',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF666666),
                                ),
                              ),
                              Text(
                                _latestReference ?? '',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _openTrackingWithLatestReference,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: const Text('Track'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8EFE8)),
          Expanded(child: pages[_tabIndex]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        backgroundColor: Colors.white,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.assignment),
            label: 'Apply',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Track',
          ),
        ],
        onDestinationSelected: (index) {
          setState(() {
            _tabIndex = index;
          });
        },
      ),
    );
  }
}
