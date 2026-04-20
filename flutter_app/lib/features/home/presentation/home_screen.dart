import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:national_id_flutter_app/features/application/presentation/application_form_screen.dart';
import 'package:national_id_flutter_app/features/auth/bloc/auth_bloc.dart';
import 'package:national_id_flutter_app/features/auth/data/auth_session.dart';
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
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ApplicationFormScreen(token: widget.session.token),
      const TrackingScreen(),
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
            child: ListTile(
              title: Text(widget.session.user.name),
              subtitle: Text(widget.session.user.email),
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
