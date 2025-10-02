import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_line_sdk/flutter_line_sdk.dart';
import 'package:image_picker/image_picker.dart';

import 'package:loveforu/services/cookie_http_client.dart';
import 'package:loveforu/services/photo_api_service.dart';
import 'package:loveforu/services/user_api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final channelId = dotenv.env['LINE_CHANNEL_ID'];
  if (channelId == null || channelId.isEmpty) {
    throw Exception('Missing LINE_CHANNEL_ID in .env');
  }
  await LineSDK.instance.setup(channelId);

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
  String? _errorMessage;
  bool _isLoadingPhotos = false;
  bool _isUploadingPhoto = false;
  List<PhotoResponse> _photos = <PhotoResponse>[];

  late final CookieHttpClient _cookieClient;
  late final UserApiService _userApiService;
  late final PhotoApiService _photoApiService;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _cookieClient = CookieHttpClient();
    _userApiService = UserApiService(client: _cookieClient);
    _photoApiService = PhotoApiService(client: _cookieClient);
  }

  @override
  void dispose() {
    _cookieClient.close();
    super.dispose();
  }

  //get profile
  Future<void> getProfile() async {
    try {
      final profile = await LineSDK.instance.getProfile();

      setState(() {
        _displayName = profile.displayName;
        _userId = profile.userId;
        _pictureUrl = profile.pictureUrl ?? "";
        _errorMessage = null;
      });
    } catch (e) {
      // print("Get Profile Failed: $e");
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
        _errorMessage = null;
      });

      final accessToken = result.accessToken?.value;
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Missing LINE access token');
      }

      final response = await _userApiService.exchangeLineToken(accessToken);

      if (!mounted) return;
      setState(() {
        _displayName = response.displayName.isNotEmpty
            ? response.displayName
            : _displayName;
        _userId = response.id.isNotEmpty ? response.id : _userId;
        _pictureUrl = response.pictureUrl?.isNotEmpty == true
            ? response.pictureUrl!
            : _pictureUrl;
      });

      await _loadPhotos();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Login failed. Please try again.';
      });
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
        _photos = <PhotoResponse>[];
        _isLoadingPhotos = false;
        _isUploadingPhoto = false;
        _errorMessage = null;
      });
      _cookieClient.clearCookies();
    } catch (e) {
      // print("Logout Failed: $e");
    }
  }

  Future<void> _loadPhotos() async {
    if (!mounted) return;
    setState(() {
      _isLoadingPhotos = true;
    });
    try {
      final photos = await _photoApiService.getPhotos();
      if (!mounted) return;
      setState(() {
        _photos = photos;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load photos. Please try again.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingPhotos = false;
      });
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) {
        return;
      }

      final caption = await _promptForCaption();
      if (caption == null) {
        return;
      }

      debugPrint('Caption selected: "$caption"');

      if (!mounted) return;
      setState(() {
        _isUploadingPhoto = true;
        _errorMessage = null;
      });

      final photo = await _photoApiService.uploadPhoto(
        image: File(pickedFile.path),
        caption: caption.isEmpty ? null : caption,
      );
      if (!mounted) return;
      setState(() {
        _photos = <PhotoResponse>[photo, ..._photos];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Upload failed. Please try again.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isUploadingPhoto = false;
      });
    }
  }

  Future<String?> _promptForCaption() async {
    String caption = '';
    return showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add a caption'),
          content: TextField(
            decoration: const InputDecoration(
              labelText: 'Caption (optional)',
            ),
            maxLines: 2,
            onChanged: (value) {
              caption = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(''),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(
                caption.trim(),
              ),
              child: const Text('Upload'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_pictureUrl.isNotEmpty) ...[
              Center(
                child: CircleAvatar(
                  backgroundImage: NetworkImage(_pictureUrl),
                  radius: 48,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Display Name: $_displayName',
                textAlign: TextAlign.center,
              ),
              Text(
                'User ID: $_userId',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: getProfile,
                    child: const Text('Refresh Profile'),
                  ),
                  ElevatedButton(
                    onPressed: logout,
                    child: const Text('Logout'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                icon: _isUploadingPhoto
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.file_upload),
                label: Text(
                  _isUploadingPhoto ? 'Uploading...' : 'Upload Photo',
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isLoadingPhotos
                    ? const Center(child: CircularProgressIndicator())
                    : _photos.isEmpty
                        ? const Center(child: Text('No photos yet.'))
                        : ListView.separated(
                            itemCount: _photos.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final photo = _photos[index];
                              return Card(
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (photo.imageUrl.isNotEmpty)
                                      Image.network(
                                        _resolvePhotoUrl(photo.imageUrl),
                                        height: 200,
                                        fit: BoxFit.cover,
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            photo.caption?.isNotEmpty == true
                                                ? photo.caption!
                                                : 'No caption',
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Uploaded: ${photo.createdAt.toLocal()}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ] else ...[
              const Spacer(),
              Center(
                child: ElevatedButton(
                  onPressed: login,
                  child: const Text('Login with LINE'),
                ),
              ),
              const Spacer(),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _resolvePhotoUrl(String url) {
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url;
  }
  final base = dotenv.env['API_BASE_URL'];
  if (base == null || base.isEmpty) {
    return url;
  }
  return '$base$url';
}
