// TEST TOOL ONLY — generates Firebase ID tokens for backend testing. Not part of the production app.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'clearance_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const TokenTestApp());
}

class TokenTestApp extends StatelessWidget {
  const TokenTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIS Login Test',
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  String? _error;
  User? _user;
  String? _idToken;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final token = await cred.user?.getIdToken();
      setState(() {
        _user = cred.user;
        _idToken = token;
      });
    } on FirebaseAuthException catch (e) {
      setState(() => _error = '${e.code}: ${e.message}');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    setState(() {
      _user = null;
      _idToken = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SIS Login Test')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _user == null ? _buildLoginForm() : _buildTokenView(),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(labelText: 'Email'),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          decoration: const InputDecoration(labelText: 'Password'),
          obscureText: true,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _loading ? null : _login,
          child: _loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Log In'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
      ],
    );
  }

  Widget _buildTokenView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Logged in as: ${_user!.email}'),
        const SizedBox(height: 16),
        const Text('ID Token:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            child: SelectableText(
              _idToken ?? '(no token)',
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () {
            if (_idToken != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClearanceManagementScreen(idToken: _idToken!),
                ),
              );
            }
          },
          icon: const Icon(Icons.verified_user),
          label: const Text('Open Clearance Manager', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () {
            if (_idToken != null) {
              Clipboard.setData(ClipboardData(text: _idToken!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Token copied to clipboard')),
              );
            }
          },
          child: const Text('Copy Token'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _logout,
          child: const Text('Log Out'),
        ),
      ],
    );
  }
}
