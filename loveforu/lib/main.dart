import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_line_sdk/flutter_line_sdk.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final channelId = dotenv.env['LINE_CHANNEL_ID'];
  if (channelId == null || channelId.isEmpty) {
    throw Exception('Missing LINE_CHANNEL_ID in .env');
  }
  await LineSDK.instance.setup(channelId);
  print('LineSDK Prepared');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Line SDK Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MyHomePage(title: 'Flutter Line SDK Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  const MyHomePage({super.key, required this.title});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _pictureUrl = "";
  String _displayName = "";
  String _userId = "";

  //get profile
  Future<void> getProfile() async {
    try {
      final profile = await LineSDK.instance.getProfile();
      print(
        "User Profile: ${profile?.displayName}, ${profile?.userId}, ${profile?.pictureUrl}",
      );
      setState(() {
        _displayName = profile?.displayName ?? "";
        _userId = profile?.userId ?? "";
        _pictureUrl = profile?.pictureUrl ?? "";
      });
    } catch (e) {
      print("Get Profile Failed: $e");
    }
  }

  //login
  Future<void> login() async {
    try {
      final result = await LineSDK.instance.login();
      setState(() {
        _displayName = result.userProfile?.displayName ?? "";
        _userId = result.userProfile?.userId ?? "";
        _pictureUrl = result.userProfile?.pictureUrl ?? "";
      });
    } catch (e) {
      print("Login Failed: $e");
    }
  }

  //logout
  Future<void> logout() async {
    try {
      await LineSDK.instance.logout();
      setState(() {
        _displayName = "";
        _userId = "";
        _pictureUrl = "";
      });
    } catch (e) {
      print("Logout Failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (_pictureUrl.isNotEmpty) ...[
              Image.network(_pictureUrl, width: 100, height: 100),
              Text('Display Name: $_displayName'),
              Text('User ID: $_userId'),
              ElevatedButton(
                onPressed: getProfile,
                child: const Text('Get Profile'),
              ),
              ElevatedButton(
                onPressed: logout,
                child: const Text('Logout from LINE'),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: login,
                child: const Text('Login with LINE'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
