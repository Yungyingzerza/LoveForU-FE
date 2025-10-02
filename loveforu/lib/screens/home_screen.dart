import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_line_sdk/flutter_line_sdk.dart';

import 'package:loveforu/services/cookie_http_client.dart';
import 'package:loveforu/services/photo_api_service.dart';
import 'package:loveforu/services/user_api_service.dart';
import 'package:loveforu/theme/app_gradients.dart';

import 'upload_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _pictureUrl = '';
  String _displayName = '';
  String _userId = '';
  String? _errorMessage;
  bool _isLoadingPhotos = false;
  bool _isAuthenticating = false;
  bool _isRestoringSession = true;
  List<PhotoResponse> _photos = <PhotoResponse>[];

  late final CookieHttpClient _cookieClient;
  late final UserApiService _userApiService;
  late final PhotoApiService _photoApiService;

  @override
  void initState() {
    super.initState();
    _cookieClient = CookieHttpClient();
    _userApiService = UserApiService(client: _cookieClient);
    _photoApiService = PhotoApiService(client: _cookieClient);
    _restoreSession();
  }

  @override
  void dispose() {
    _cookieClient.close();
    super.dispose();
  }

  Future<void> getProfile() async {
    try {
      final profile = await LineSDK.instance.getProfile();

      if (!mounted) return;
      setState(() {
        _displayName = profile.displayName;
        _userId = profile.userId;
        _pictureUrl = profile.pictureUrl ?? '';
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to refresh profile.';
      });
    }
  }

  Future<void> login() async {
    if (_isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
    });
    try {
      final result = await LineSDK.instance.login();
      if (!mounted) return;
      setState(() {
        _displayName = result.userProfile?.displayName ?? '';
        _userId = result.userProfile?.userId ?? '';
        _pictureUrl = result.userProfile?.pictureUrl ?? '';
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
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  Future<void> _restoreSession() async {
    try {
      final storedToken = await LineSDK.instance.currentAccessToken;
      if (storedToken == null) {
        return;
      }

      final profile = await LineSDK.instance.getProfile();
      if (!mounted) return;
      setState(() {
        _displayName = profile.displayName;
        _userId = profile.userId;
        _pictureUrl = profile.pictureUrl ?? '';
        _errorMessage = null;
      });

      final response = await _userApiService.exchangeLineToken(storedToken.value);
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
        _errorMessage = 'Session expired. Please log in again.';
        _displayName = '';
        _userId = '';
        _pictureUrl = '';
        _photos = <PhotoResponse>[];
      });
      _cookieClient.clearCookies();
    } finally {
      if (mounted) {
        setState(() {
          _isRestoringSession = false;
        });
      }
    }
  }

  Future<void> logout() async {
    try {
      await LineSDK.instance.logout();
      if (!mounted) return;
      setState(() {
        _displayName = '';
        _userId = '';
        _pictureUrl = '';
        _photos = <PhotoResponse>[];
        _isLoadingPhotos = false;
        _errorMessage = null;
      });
      _cookieClient.clearCookies();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Logout failed. Please try again.';
      });
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

  Future<void> _openUploadScreen() async {
    final photo = await Navigator.of(context).push<PhotoResponse>(
      MaterialPageRoute(
        builder: (_) => UploadScreen(photoApiService: _photoApiService),
      ),
    );

    if (photo == null || !mounted) {
      return;
    }

    setState(() {
      _photos = <PhotoResponse>[photo, ..._photos];
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoggedIn = _userId.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: appBackgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'LoveForU',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    if (isLoggedIn)
                      IconButton(
                        onPressed: logout,
                        icon: const Icon(Icons.logout, color: Colors.white),
                        tooltip: 'Logout',
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (isLoggedIn)
                  _UserHeader(
                    pictureUrl: _pictureUrl,
                    displayName: _displayName,
                    userId: _userId,
                    onRefreshProfile: getProfile,
                  )
                else
                  _LoginCallToAction(
                    onLogin: login,
                    isLoading: _isAuthenticating || _isRestoringSession,
                  ),
                const SizedBox(height: 16),
                if (isLoggedIn)
                  ElevatedButton.icon(
                    onPressed: _isLoadingPhotos ? null : _openUploadScreen,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Open Camera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.15),
                      foregroundColor: Colors.white,
                    ),
                  ),
                const SizedBox(height: 16),
                if (_errorMessage != null)
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: !isLoggedIn
                      ? const _LoginPlaceholder()
                      : _isLoadingPhotos
                          ? const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            )
                          : _photos.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No photos yet. Capture your first moment!',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _photos.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                                  itemBuilder: (context, index) {
                                    final photo = _photos[index];
                                    return _PhotoCard(photo: photo);
                                  },
                                ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginCallToAction extends StatelessWidget {
  const _LoginCallToAction({
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

class _LoginPlaceholder extends StatelessWidget {
  const _LoginPlaceholder();

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

class _UserHeader extends StatelessWidget {
  const _UserHeader({
    required this.pictureUrl,
    required this.displayName,
    required this.userId,
    required this.onRefreshProfile,
  });

  final String pictureUrl;
  final String displayName;
  final String userId;
  final VoidCallback onRefreshProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundImage:
              pictureUrl.isNotEmpty ? NetworkImage(pictureUrl) : null,
          backgroundColor: Colors.white24,
          child: pictureUrl.isEmpty
              ? const Icon(Icons.person, color: Colors.white, size: 32)
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName.isNotEmpty ? displayName : 'Anonymous',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                userId,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onRefreshProfile,
          icon: const Icon(Icons.refresh, color: Colors.white),
          tooltip: 'Refresh profile',
        ),
      ],
    );
  }
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({required this.photo});

  final PhotoResponse photo;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolvePhotoUrl(photo.imageUrl);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (photo.imageUrl.isNotEmpty)
              AspectRatio(
                aspectRatio: 3 / 4,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image, color: Colors.white54),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    photo.caption?.isNotEmpty == true
                        ? photo.caption!
                        : 'No caption',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Uploaded: ${photo.createdAt.toLocal()}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
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
