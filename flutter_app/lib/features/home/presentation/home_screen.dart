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
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.session.user.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(widget.session.user.email),
                  if (_latestReference != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCAD8D0)),
                      ),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Icon(Icons.confirmation_number_outlined,
                              size: 18),
                          Text(
                            'Latest Tracking: $_latestReference',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          TextButton.icon(
                            onPressed: _openTrackingWithLatestReference,
                            icon: const Icon(Icons.search),
                            label: const Text('Track now'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(child: pages[_tabIndex]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
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
