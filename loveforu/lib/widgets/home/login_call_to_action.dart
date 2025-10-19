import 'package:flutter/material.dart';

class LoginCallToAction extends StatelessWidget {
  const LoginCallToAction({
    super.key,
    required this.onLogin,
    required this.isLoading,
  });

  final VoidCallback onLogin;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Welcome! Log in with LINE to share a live photo.',
          style: TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: isLoading ? null : onLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Login with LINE'),
        ),
      ],
    );
  }
}
