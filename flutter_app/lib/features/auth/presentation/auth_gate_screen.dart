// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:national_id_flutter_app/core/theme/app_theme.dart';
import 'package:national_id_flutter_app/core/theme/nid_header.dart';
import 'package:national_id_flutter_app/features/auth/bloc/auth_bloc.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _loginFormKey = GlobalKey<FormState>();
  final _signupFormKey = GlobalKey<FormState>();

  final _loginEmailCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();
  final _signupNameCtrl = TextEditingController();
  final _signupEmailCtrl = TextEditingController();
  final _signupPhoneCtrl = TextEditingController();
  final _signupPasswordCtrl = TextEditingController();

  bool _loginPasswordVisible = false;
  bool _signupPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _signupNameCtrl.dispose();
    _signupEmailCtrl.dispose();
    _signupPhoneCtrl.dispose();
    _signupPasswordCtrl.dispose();
    super.dispose();
  }

  void _submitLogin(BuildContext context) {
    if (!_loginFormKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(AuthLoginSubmitted(
          email: _loginEmailCtrl.text,
          password: _loginPasswordCtrl.text,
        ));
  }

  void _submitSignup(BuildContext context) {
    if (!_signupFormKey.currentState!.validate()) return;
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
      listenWhen: (prev, curr) => prev.message != curr.message,
      listener: (context, state) {
        if (state.message != null && state.message!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message!)),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8F5),
        body: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final isLoading = state.status == AuthStatus.loading;
            return SafeArea(
              child: Column(
                children: [
                  // ── Unified green header (no user strip on auth screen) ──
                  NidHeader(
                    title: 'Secure Access Portal',
                    subtitle:
                        'Sign in or create an account to apply for your National ID.',
                  ),
                  // ── Loading bar ──────────────────────────────────────────
                  if (isLoading)
                    const LinearProgressIndicator(
                      backgroundColor: kLightGreen,
                      color: kAccentGreen,
                      minHeight: 3,
                    ),
                  // ── Content area ─────────────────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxWidth: 520),
                          child: Column(
                            children: [
                              const SizedBox(height: 4),
                              // Error message
                              if (state.message != null &&
                                  state.message!.isNotEmpty)
                                NidInfoBanner(
                                  state.message!,
                                  isError: true,
                                ),
                              // Card with tabs
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  border:
                                      Border.all(color: kBorderGreen),
                                ),
                                child: Column(
                                  children: [
                                    // Tab bar
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 14, 16, 0),
                                      child: TabBar(
                                        controller: _tabController,
                                        indicatorColor: kBrandGreen,
                                        labelColor: kBrandGreen,
                                        unselectedLabelColor:
                                            Colors.black45,
                                        labelStyle: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                        unselectedLabelStyle:
                                            const TextStyle(
                                          fontWeight: FontWeight.w400,
                                          fontSize: 14,
                                        ),
                                        indicatorSize:
                                            TabBarIndicatorSize.label,
                                        tabs: const [
                                          Tab(text: 'Login'),
                                          Tab(text: 'Create Account'),
                                        ],
                                      ),
                                    ),
                                    const Divider(
                                        height: 1,
                                        color: kBorderGreen),
                                    SizedBox(
                                      // dynamic height – enough for both tabs
                                      height: _tabController.index == 0
                                          ? 270
                                          : 380,
                                      child: TabBarView(
                                        controller: _tabController,
                                        children: [
                                          _buildLoginTab(
                                              context, isLoading),
                                          _buildSignupTab(
                                              context, isLoading),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Footer note
                              Text(
                                'Your data is protected under Uganda\'s '
                                'Data Protection and Privacy Act.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.black38,
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
    );
  }

  Widget _buildLoginTab(BuildContext context, bool isLoading) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _loginFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _loginEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon:
                    Icon(Icons.email_outlined, color: kAccentGreen),
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty || !t.contains('@')) {
                  return 'Enter a valid email.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _loginPasswordCtrl,
              obscureText: !_loginPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon:
                    const Icon(Icons.lock_outline, color: kAccentGreen),
                suffixIcon: IconButton(
                  icon: Icon(
                    _loginPasswordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.black38,
                  ),
                  onPressed: () => setState(
                      () => _loginPasswordVisible = !_loginPasswordVisible),
                ),
              ),
              validator: (v) =>
                  (v ?? '').isEmpty ? 'Password is required.' : null,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed:
                  isLoading ? null : () => _submitLogin(context),
              child: Text(isLoading ? 'Signing in…' : 'Sign In'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignupTab(BuildContext context, bool isLoading) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _signupFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _signupNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon:
                    Icon(Icons.person_outline, color: kAccentGreen),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Name is required.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _signupEmailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon:
                    Icon(Icons.email_outlined, color: kAccentGreen),
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty || !t.contains('@')) {
                  return 'Enter a valid email.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _signupPhoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                prefixIcon:
                    Icon(Icons.phone_outlined, color: kAccentGreen),
              ),
              validator: (v) {
                if ((v ?? '').trim().length < 10) {
                  return 'Phone must be at least 10 digits.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _signupPasswordCtrl,
              obscureText: !_signupPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon:
                    const Icon(Icons.lock_outline, color: kAccentGreen),
                suffixIcon: IconButton(
                  icon: Icon(
                    _signupPasswordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.black38,
                  ),
                  onPressed: () => setState(
                      () => _signupPasswordVisible =
                          !_signupPasswordVisible),
                ),
              ),
              validator: (v) {
                if ((v ?? '').length < 6) {
                  return 'Password must be at least 6 characters.';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed:
                  isLoading ? null : () => _submitSignup(context),
              child: Text(
                  isLoading ? 'Creating account…' : 'Create Account'),
            ),
            const SizedBox(height: 8),
            Text(
              'Use a fresh email and phone when testing signup.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.black38),
            ),
          ],
        ),
      ),
    );
  }
}
