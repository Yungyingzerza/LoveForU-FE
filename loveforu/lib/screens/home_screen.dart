import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_line_sdk/flutter_line_sdk.dart';

import 'package:loveforu/services/cookie_http_client.dart';
import 'package:loveforu/services/photo_api_service.dart';
import 'package:loveforu/services/user_api_service.dart';
import 'package:loveforu/theme/app_gradients.dart';

import 'puppy_cam_screen.dart';
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
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: isLoggedIn
                ? _buildLoggedInLayout(context)
                : _buildLoggedOutLayout(context),
          ),
        ),
      ),
    );
  }

  Widget _buildLoggedInLayout(BuildContext context) {
    final PhotoResponse? latestPhoto =
        _photos.isNotEmpty ? _photos.first : null;
    final Widget previewWidget = latestPhoto != null
        ? Image.network(
            _resolvePhotoUrl(latestPhoto.imageUrl),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildPreviewPlaceholder(),
          )
        : _buildPreviewPlaceholder();
    final ImageProvider? historyImage = latestPhoto != null
        ? NetworkImage(_resolvePhotoUrl(latestPhoto.imageUrl))
        : null;
    final ImageProvider? avatarImage =
        _pictureUrl.isNotEmpty ? NetworkImage(_pictureUrl) : null;
    final int rawCount = _photos.length;
    final int cappedCount = rawCount > 999 ? 999 : rawCount;
    final String friendsLabel =
        '$cappedCount Friend${cappedCount == 1 ? '' : 's'}';

    return Column(
      children: [
        Expanded(
          child: PuppyCamScreen(
            avatarImage: avatarImage,
            friendsLabel: friendsLabel,
            preview: previewWidget,
            historyImage: historyImage,
            onMessages: _showUserMenu,
            onGallery: () => _showGallery(context),
            onShutter: _isLoadingPhotos ? null : _openUploadScreen,
            onSwitchCamera: () {},
            onHistory: () => _showGallery(context),
          ),
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
      ],
    );
  }

  Widget _buildLoggedOutLayout(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LoginCallToAction(
          onLogin: login,
          isLoading: _isAuthenticating || _isRestoringSession,
        ),
        const SizedBox(height: 32),
        const _LoginPlaceholder(),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
      ],
    );
  }

  Widget _buildPreviewPlaceholder() {
    return Container(
      color: Colors.white10,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.camera_alt_outlined, color: Colors.white38, size: 48),
          SizedBox(height: 12),
          Text(
            'Capture your first moment',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  void _showGallery(BuildContext context) {
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No photos yet.')),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1F39),
      builder: (modalContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Shared Moments',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: MediaQuery.of(modalContext).size.height * 0.45,
                  child: ListView.separated(
                    itemCount: _photos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, index) {
                      final photo = _photos[index];
                      return _PhotoListTile(photo: photo);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUserMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0F1F39),
      builder: (modalContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.white24,
                  backgroundImage:
                      _pictureUrl.isNotEmpty ? NetworkImage(_pictureUrl) : null,
                  child: _pictureUrl.isEmpty
                      ? const Icon(Icons.person_outline, color: Colors.white)
                      : null,
                ),
                title: Text(
                  _displayName.isNotEmpty ? _displayName : 'Anonymous',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _userId,
                  style: const TextStyle(color: Colors.white54),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.refresh, color: Colors.white),
                title: const Text('Refresh profile', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(modalContext).pop();
                  getProfile();
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.of(modalContext).pop();
                  logout();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
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

class _PhotoListTile extends StatelessWidget {
  const _PhotoListTile({required this.photo});

  final PhotoResponse photo;

  @override
  Widget build(BuildContext context) {
    final String imageUrl = _resolvePhotoUrl(photo.imageUrl);
    final String caption =
        photo.caption?.isNotEmpty == true ? photo.caption! : 'No caption';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            imageUrl,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 56,
              height: 56,
              color: Colors.white12,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image, color: Colors.white54),
            ),
          ),
        ),
        title: Text(
          caption,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'Uploaded: ${photo.createdAt.toLocal()}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
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
