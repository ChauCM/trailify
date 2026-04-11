import 'package:flutter/material.dart';
import '../trailify.dart';
import 'trailify_dashboard_screen.dart';
import 'trailify_theme_wrapper.dart';

class TrailifyAuthScreen extends StatefulWidget {
  const TrailifyAuthScreen({Key? key}) : super(key: key);

  @override
  State<TrailifyAuthScreen> createState() => _TrailifyAuthScreenState();
}

class _TrailifyAuthScreenState extends State<TrailifyAuthScreen> {
  static bool _isLoggedIn = false;

  bool get _noPassword =>
      Trailify.instance.password == null || Trailify.instance.ignorePassword;

  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn || _noPassword) {
      return const TrailifyDashboardScreen();
    }

    return TrailifyThemeWrapper(
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: const BackButton(),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: TextField(
            autofocus: true,
            controller: _controller,
            onSubmitted: (_) => _onSubmit(),
            decoration: const InputDecoration(
              filled: true,
              labelText: 'Password',
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              border: UnderlineInputBorder(),
              floatingLabelBehavior: FloatingLabelBehavior.auto,
            ),
          ),
        ),
        floatingActionButtonLocation:
            FloatingActionButtonLocation.centerFloat,
        floatingActionButton: FloatingActionButton.large(
          onPressed: _onSubmit,
          child: const Icon(Icons.login),
        ),
      ),
    );
  }

  void _onSubmit() {
    if (Trailify.instance.password == _controller.text) {
      _goToDashboard();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wrong password')),
      );
    }
  }

  void _goToDashboard() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const TrailifyDashboardScreen(),
        settings: const RouteSettings(name: '/trailify_dashboard'),
      ),
    );
    _isLoggedIn = true;
  }
}
