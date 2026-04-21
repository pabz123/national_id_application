import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:national_id_flutter_app/features/auth/bloc/auth_bloc.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  final _loginFormKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();

  final _loginEmailCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();

  final _signupNameCtrl = TextEditingController();
  final _signupEmailCtrl = TextEditingController();
  final _signupPhoneCtrl = TextEditingController();
  final _signupPasswordCtrl = TextEditingController();

  @override
  void dispose() {
    _loginEmailCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _signupNameCtrl.dispose();
    _signupEmailCtrl.dispose();
    _signupPhoneCtrl.dispose();
    _signupPasswordCtrl.dispose();
    super.dispose();
  }

  void _submitLogin(BuildContext context) {
    if (!_loginFormKey.currentState!.validate()) {
      return;
    }
    context.read<AuthBloc>().add(AuthLoginSubmitted(
          email: _loginEmailCtrl.text,
          password: _loginPasswordCtrl.text,
        ));
  }

  void _submitSignup(BuildContext context) {
    if (!_signupFormKey.currentState!.validate()) {
      return;
    }
    context.read<AuthBloc>().add(AuthSignupSubmitted(
          name: _signupNameCtrl.text,
          email: _signupEmailCtrl.text,
          phone: _signupPhoneCtrl.text,
          password: _signupPasswordCtrl.text,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) => previous.message != current.message,
      listener: (context, state) {
        if (state.message == null || state.message!.isEmpty) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.message!)),
        );
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('National ID Services'),
            elevation: 0,
          ),
          body: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              final isLoading = state.status == AuthStatus.loading;
              return SafeArea(
                child: Column(
                  children: [
                    if (isLoading) const LinearProgressIndicator(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 600),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFAFCFB),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFDEE8E2),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.verified_user, size: 28, color: Color(0xFF0C3D28)),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Secure access for National ID application and tracking',
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (state.message != null && state.message!.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEE4E4),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFE8B4B4)),
                                    ),
                                    child: Text(
                                      state.message!,
                                      style: const TextStyle(
                                        color: Color(0xFFC31C1C),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 24),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFFE8EFE8)),
                                  ),
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: const Color(0xFFE8EFE8),
                                              ),
                                            ),
                                          ),
                                          child: const TabBar(
                                            tabs: [
                                              Padding(
                                                padding: EdgeInsets.symmetric(vertical: 12),
                                                child: Text('Login'),
                                              ),
                                              Padding(
                                                padding: EdgeInsets.symmetric(vertical: 12),
                                                child: Text('Signup'),
                                              ),
                                            ],
                                            indicatorColor: Color(0xFF0C3D28),
                                            labelColor: Color(0xFF0C3D28),
                                            unselectedLabelColor: Color(0xFF999999),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        height: 320,
                                        child: TabBarView(
                                          children: [
                                            _buildLoginTab(context, isLoading),
                                            _buildSignupTab(context, isLoading),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoginTab(BuildContext context, bool isLoading) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _loginFormKey,
        child: Column(
          children: [
            TextFormField(
              controller: _loginEmailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
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
              controller: _loginPasswordCtrl,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              validator: (value) {
                if ((value ?? '').isEmpty) {
                  return 'Password is required.';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : () => _submitLogin(context),
                child: Text(isLoading ? 'Please wait...' : 'Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignupTab(BuildContext context, bool isLoading) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _signupFormKey,
        child: Column(
          children: [
            TextFormField(
              controller: _signupNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Name is required.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _signupEmailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
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
              controller: _signupPhoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.length < 10) {
                  return 'Phone number must be at least 10 digits.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _signupPasswordCtrl,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              validator: (value) {
                if ((value ?? '').length < 6) {
                  return 'Password must be at least 6 characters.';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Use a fresh email and phone when testing signup.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : () => _submitSignup(context),
                child: Text(isLoading ? 'Please wait...' : 'Create Account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
