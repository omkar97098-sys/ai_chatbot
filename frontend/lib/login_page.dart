import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final VoidCallback onGuestMode;

  const LoginPage({
    super.key,
    required this.onLoginSuccess,
    required this.onGuestMode,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Please enter your email and password.');
      return;
    }

    setState(() => isLoading = true);

    final result = await AuthService.login(
      email: email,
      password: password,
    );

    if (!mounted) return;
    setState(() => isLoading = false);

    if (result['success'] == true) {
      widget.onLoginSuccess();
      return;
    }

    _showMessage(
      result['message']?.toString() ??
          result['detail']?.toString() ??
          'Login failed.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openSignup() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SignupPage(
          onSignupSuccess: widget.onLoginSuccess,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Center(
                        child: Text(
                          'N',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Welcome Back',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Login to continue using NEXA AI.',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'you@example.com',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      onSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: isLoading ? null : _login,
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Login'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: isLoading ? null : _openSignup,
                      child: const Text('Create Account'),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: isLoading ? null : widget.onGuestMode,
                      icon: const Icon(Icons.person_outline),
                      label: const Text('Continue as Guest'),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Guest mode lets you explore NEXA AI without creating an account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
