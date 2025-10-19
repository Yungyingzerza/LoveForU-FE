import 'package:flutter/material.dart';

class LoginPlaceholder extends StatelessWidget {
  const LoginPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Login to see shared photos.',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }
}
