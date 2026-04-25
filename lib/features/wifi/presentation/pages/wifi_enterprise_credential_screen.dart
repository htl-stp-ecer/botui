import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stpvelox/core/widgets/top_bar.dart';
import 'package:stpvelox/features/wifi/domain/enities/wifi_credentials.dart';

class WifiEnterpriseCredentialScreen extends StatefulWidget {
  final String ssid;

  const WifiEnterpriseCredentialScreen({super.key, required this.ssid});

  @override
  State<WifiEnterpriseCredentialScreen> createState() =>
      _WifiEnterpriseCredentialScreenState();
}

class _WifiEnterpriseCredentialScreenState
    extends State<WifiEnterpriseCredentialScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _caCertController = TextEditingController();
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: createTopBar(context, 'Enterprise Credentials for ${widget.ssid}'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text('Username:'),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            const Text('Password:'),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('CA Certificate (optional):'),
            TextField(
              controller: _caCertController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '/path/to/ca.cert',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final creds = EnterpriseCredentials(
                  username: _usernameController.text,
                  password: _passwordController.text,
                  caCertificatePath: _caCertController.text.isEmpty
                      ? null
                      : _caCertController.text,
                );
                context.pop(creds);
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
