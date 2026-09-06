import 'package:flutter/material.dart';

import 'auth_service.dart';

class SignupPage extends StatefulWidget {
  final VoidCallback onSignupSuccess;

  const SignupPage({
    super.key,
    required this.onSignupSuccess,
  });

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showMessage('Please fill in all fields.');
      return;
    }

    if (password.length < 8) {
      _showMessage('Password must contain at least 8 characters.');
      return;
    }

    if (password != confirmPassword) {
      _showMessage('Passwords do not match.');
      return;
    }

    setState(() => isLoading = true);

    final signupResult = await AuthService.signup(
      name: name,
      email: email,
      password: password,
    );

    if (!mounted) return;

    if (signupResult['success'] != true) {
      setState(() => isLoading = false);
      _showMessage(
        signupResult['message']?.toString() ??
            signupResult['detail']?.toString() ??
            'Could not create account.',
      );
      return;
    }

    // Automatically login after successful registration.
    final loginResult = await AuthService.login(
      email: email,
      password: password,
    );

    if (!mounted) return;
    setState(() => isLoading = false);

    if (loginResult['success'] == true) {
      Navigator.of(context).pop();
      widget.onSignupSuccess();
      return;
    }

    _showMessage(
      'Account created. Please go back and login.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
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
                    Icon(
                      Icons.person_add_alt_1,
                      size: 58,
                      color: scheme.primary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Join NEXA AI',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Create your account to get started.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 26),
                    TextField(
                      controller: nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        helperText: 'At least 8 characters',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
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
                    const SizedBox(height: 16),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirmPassword,
                      onSubmitted: (_) => _signup(),
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              obscureConfirmPassword =
                                  !obscureConfirmPassword;
                            });
                          },
                          icon: Icon(
                            obscureConfirmPassword
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
                        onPressed: isLoading ? null : _signup,
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Create Account'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Back to Login'),
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
