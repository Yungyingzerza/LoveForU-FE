import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_line_sdk/flutter_line_sdk.dart';
import 'package:image_picker/image_picker.dart';

import 'package:loveforu/services/cookie_http_client.dart';
import 'package:loveforu/services/friend_api_service.dart';
import 'package:loveforu/services/photo_api_service.dart';
import 'package:loveforu/services/user_api_service.dart';
import 'package:loveforu/theme/app_gradients.dart';

import 'camera_capture_screen.dart';
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
  List<FriendListItem> _friends = <FriendListItem>[];
  String? _selectedFriendUserId;
  bool _isAddingFriend = false;

  late final CookieHttpClient _cookieClient;
  late final UserApiService _userApiService;
  late final FriendApiService _friendApiService;
  late final PhotoApiService _photoApiService;
  late final ImagePicker _imagePicker;

  @override
  void initState() {
    super.initState();
    _cookieClient = CookieHttpClient();
    _userApiService = UserApiService(client: _cookieClient);
    _friendApiService = FriendApiService(client: _cookieClient);
    _photoApiService = PhotoApiService(client: _cookieClient);
    _imagePicker = ImagePicker();
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

      final accessToken = result.accessToken.value;
      if (accessToken.isEmpty) {
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
        _selectedFriendUserId = null;
      });

      await _loadPhotos();
      _loadFriends();
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
        _selectedFriendUserId = null;
      });

      await _loadPhotos();
      _loadFriends();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Session expired. Please log in again.';
        _displayName = '';
        _userId = '';
        _pictureUrl = '';
        _photos = <PhotoResponse>[];
        _friends = <FriendListItem>[];
        _selectedFriendUserId = null;
        _isAddingFriend = false;
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
        _friends = <FriendListItem>[];
        _selectedFriendUserId = null;
        _isLoadingPhotos = false;
        _errorMessage = null;
        _isAddingFriend = false;
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
      if (mounted) {
        setState(() {
          _isLoadingPhotos = false;
        });
      }
    }
  }

  Future<void> _loadFriends() async {
    try {
      final friends = await _friendApiService.getFriendships();
      if (!mounted) {
        return;
      }
      setState(() {
        _friends = friends;
        if (_selectedFriendUserId != null &&
            _selectedFriendUserId != _userId &&
            !_friends.any(
              (friend) => friend.friendUserId == _selectedFriendUserId,
            )) {
          _selectedFriendUserId = null;
        }
      });
    } on FriendApiException catch (error) {
      developer.log(
        'Failed to load friends',
        name: 'HomeScreen',
        error: error,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to load friends',
        name: 'HomeScreen',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  List<PhotoResponse> _currentPhotos() {
    if (_selectedFriendUserId == null) {
      return _photos;
    }
    return _photos
        .where((photo) => photo.uploaderId == _selectedFriendUserId)
        .toList();
  }

  String _currentFriendFilterLabel() {
    final String? selectedId = _selectedFriendUserId;
    if (selectedId == null || selectedId.isEmpty) {
      return 'Everyone';
    }
    if (selectedId == _userId) {
      return _displayName.isNotEmpty ? _displayName : 'Just me';
    }
    for (final friend in _friends) {
      if (friend.friendUserId == selectedId) {
        return friend.displayName.isNotEmpty
            ? friend.displayName
            : friend.friendUserId;
      }
    }
    return selectedId;
  }

  Future<void> _promptAddFriend() async {
    String pendingFriendUserId = '';
    final String? friendUserId = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add friend'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'LINE user ID',
              hintText: 'Uxxxxxxxxxxxxxxxxxxxx',
            ),
            onChanged: (value) {
              pendingFriendUserId = value.trim();
            },
            onSubmitted: (value) {
              pendingFriendUserId = value.trim();
              Navigator.of(dialogContext).pop(pendingFriendUserId);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                FocusScope.of(dialogContext).unfocus();
                Navigator.of(dialogContext).pop(pendingFriendUserId);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (friendUserId == null || friendUserId.isEmpty) {
      return;
    }

    await _addFriend(friendUserId);
  }

  Future<void> _addFriend(String friendUserId) async {
    if (_isAddingFriend) {
      return;
    }

    setState(() {
      _isAddingFriend = true;
    });

    try {
      final friendship = await _friendApiService.createFriendship(
        friendUserId: friendUserId,
      );
      final String otherUserId =
          friendship.requesterId == _userId ? friendship.addresseeId : friendship.requesterId;

      String message;
      if (friendship.acceptedFromIncomingRequest || friendship.isAccepted) {
        message = otherUserId.isNotEmpty
            ? 'You and $otherUserId are now friends!'
            : 'Friend request accepted!';
        await _loadPhotos();
        _loadFriends();
      } else if (friendship.isPending) {
        message = otherUserId.isNotEmpty
            ? 'Friend request sent to $otherUserId.'
            : 'Friend request sent.';
      } else {
        message = 'Friendship updated.';
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } on FriendApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to add friend',
        name: 'HomeScreen',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to add friend right now.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAddingFriend = false;
        });
      }
    }
  }

  Future<void> _openUploadScreen({XFile? initialFile}) async {
    final photo = await Navigator.of(context).push<PhotoResponse>(
      MaterialPageRoute(
        builder: (_) => UploadScreen(
          photoApiService: _photoApiService,
          initialFile: initialFile,
          friends: _friends,
        ),
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

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile == null) {
        return;
      }

      await _openUploadScreen(initialFile: pickedFile);
    } on PlatformException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gallery permission denied.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to pick an image.')),
      );
    }
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
    final List<PhotoResponse> visiblePhotos = _currentPhotos();
    final PhotoResponse? latestPhoto =
        visiblePhotos.isNotEmpty ? visiblePhotos.first : null;
    final String friendFilterLabel = _currentFriendFilterLabel();
    final String placeholderMessage =
        _selectedFriendUserId == null || _selectedFriendUserId!.isEmpty
            ? 'Share a moment with friends.'
            : _selectedFriendUserId == _userId
                ? 'You have not shared a photo yet.'
                : 'No photos from $friendFilterLabel yet.';
    final Widget previewWidget = visiblePhotos.isNotEmpty
        ? _PhotoFeedPreview(
            photos: visiblePhotos,
            resolvePhotoUrl: _resolvePhotoUrl,
          )
        : _buildPreviewPlaceholder(message: placeholderMessage);
    final ImageProvider? historyImage = latestPhoto != null
        ? NetworkImage(_resolvePhotoUrl(latestPhoto.imageUrl))
        : null;
    final ImageProvider? avatarImage =
        _pictureUrl.isNotEmpty ? NetworkImage(_pictureUrl) : null;
    final String friendsLabel = 'Viewing: $friendFilterLabel';

    return Column(
      children: [
        Expanded(
          child: CameraCaptureScreen(
            avatarImage: avatarImage,
            friendsLabel: friendsLabel,
            preview: previewWidget,
            historyImage: historyImage,
            onMessages: _showUserMenu,
            onGallery: _pickImageFromGallery,
            onShutter: _isLoadingPhotos ? null : _openUploadScreen,
            onSwitchCamera: () {},
            onHistory: () => _showGallery(context),
            onFriendFilter: _showFriendFilter,
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

  Widget _buildPreviewPlaceholder({String message = 'Capture your first moment'}) {
    return Container(
      color: Colors.white10,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.camera_alt_outlined, color: Colors.white38, size: 48),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  void _showGallery(BuildContext context) {
    final List<PhotoResponse> initialPhotos = _currentPhotos();
    if (initialPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _selectedFriendUserId == null
                ? 'No photos yet.'
                : 'No photos for this filter yet.',
          ),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1F39),
      builder: (modalContext) {
        final List<PhotoResponse> visiblePhotos = _currentPhotos();
        final String filterLabel = _currentFriendFilterLabel();
        final String titleText = filterLabel == 'Everyone'
            ? 'Shared Moments'
            : 'Shared Moments • $filterLabel';
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
                  titleText,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: MediaQuery.of(modalContext).size.height * 0.45,
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: visiblePhotos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, index) {
                      final photo = visiblePhotos[index];
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

  Future<void> _showFriendFilter() async {
    if (_userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login to choose whose photos to view.')),
      );
      return;
    }

    await _loadFriends();

    if (!mounted) {
      return;
    }

    final List<_FriendFilterOption> options = <_FriendFilterOption>[
      const _FriendFilterOption(id: null, label: 'Everyone'),
      if (_userId.isNotEmpty)
        _FriendFilterOption(
          id: _userId,
          label: _displayName.isNotEmpty ? _displayName : 'Just me',
        ),
      ..._friends.map(
        (friend) => _FriendFilterOption(
          id: friend.friendUserId,
          label: friend.displayName.isNotEmpty
              ? friend.displayName
              : friend.friendUserId,
        ),
      ),
    ];

    final String? initialSelection = _selectedFriendUserId;

    final String? selectedId = await showModalBottomSheet<String?>(
      context: context,
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
                const Text(
                  'View photos from',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: options.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final option = options[index];
                      final bool isSelected = option.id == initialSelection ||
                          (option.id == null && initialSelection == null);
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        tileColor:
                            isSelected ? Colors.white12 : Colors.transparent,
                        leading: Icon(
                          option.id == null
                              ? Icons.public
                              : option.id == _userId
                                  ? Icons.person_outline
                                  : Icons.person,
                          color: Colors.white,
                        ),
                        title: Text(
                          option.label,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                        onTap: () => Navigator.of(modalContext).pop(option.id),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) {
      return;
    }
    if (selectedId == initialSelection) {
      return;
    }

    setState(() {
      _selectedFriendUserId = selectedId;
    });
  }

  void _showFriendRequests() {
    if (_userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login to manage friend requests.')),
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
            child: SizedBox(
              height: MediaQuery.of(modalContext).size.height * 0.65,
              child: _FriendshipCenterSheet(
                friendApiService: _friendApiService,
                currentUserId: _userId,
                onFriendshipUpdated: _handleFriendshipUpdated,
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleFriendshipUpdated() {
    _loadFriends();
    _loadPhotos();
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
                leading: const Icon(Icons.people_alt_outlined, color: Colors.white),
                title: const Text('Friends & requests',
                    style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.of(modalContext).pop();
                  _showFriendRequests();
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_add_alt_1, color: Colors.white),
                title: const Text('Add friend', style: TextStyle(color: Colors.white)),
                enabled: !_isAddingFriend,
                onTap: _isAddingFriend
                    ? null
                    : () {
                        Navigator.of(modalContext).pop();
                        _promptAddFriend();
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


enum _FriendshipTab { friends, requests }

class _FriendshipCenterSheet extends StatefulWidget {
  const _FriendshipCenterSheet({
    required this.friendApiService,
    required this.currentUserId,
    required this.onFriendshipUpdated,
  });

  final FriendApiService friendApiService;
  final String currentUserId;
  final VoidCallback onFriendshipUpdated;

  @override
  State<_FriendshipCenterSheet> createState() => _FriendshipCenterSheetState();
}

class _FriendshipCenterSheetState extends State<_FriendshipCenterSheet> {
  _FriendshipTab _activeTab = _FriendshipTab.friends;
  List<FriendListItem> _friends = <FriendListItem>[];
  bool _isLoadingFriends = true;
  String? _friendsError;

  FriendshipPendingDirection _direction = FriendshipPendingDirection.incoming;
  List<FriendshipResponse> _requests = <FriendshipResponse>[];
  bool _isLoadingRequests = false;
  String? _requestsError;
  bool _hasLoadedRequests = false;

  String? _activeFriendshipId;
  bool _isActiveActionAccept = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() {
      _isLoadingFriends = true;
      _friendsError = null;
    });
    try {
      final friends = await widget.friendApiService.getFriendships();
      if (!mounted) {
        return;
      }
      setState(() {
        _friends = friends;
      });
    } on FriendApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _friendsError = error.message;
      });
    } catch (error, stackTrace) {
      developer.log(
        'Failed to load friends',
        name: 'FriendshipCenterSheet',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _friendsError = 'Unable to load friends right now.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFriends = false;
        });
      }
    }
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoadingRequests = true;
      _requestsError = null;
    });
    try {
      final requests = await widget.friendApiService.getPendingFriendships(
        direction: _direction,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _requests = requests;
        _hasLoadedRequests = true;
      });
    } on FriendApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _requestsError = error.message;
        _hasLoadedRequests = true;
      });
    } catch (error, stackTrace) {
      developer.log(
        'Failed to load pending friendships',
        name: 'FriendshipCenterSheet',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _requestsError = 'Unable to load friend requests right now.';
        _hasLoadedRequests = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRequests = false;
        });
      }
    }
  }

  void _onTabSelected(_FriendshipTab tab) {
    if (_activeTab == tab) {
      return;
    }
    setState(() {
      _activeTab = tab;
    });
    if (tab == _FriendshipTab.requests && !_hasLoadedRequests) {
      _loadRequests();
    }
  }

  void _onDirectionSelected(FriendshipPendingDirection direction) {
    if (_direction == direction) {
      return;
    }
    setState(() {
      _direction = direction;
    });
    _loadRequests();
  }

  Future<void> _handleDecision({
    required FriendshipResponse friendship,
    required bool accept,
  }) async {
    setState(() {
      _activeFriendshipId = friendship.id;
      _isActiveActionAccept = accept;
    });

    try {
      final updated = accept
          ? await widget.friendApiService.acceptFriendship(friendship.id)
          : await widget.friendApiService.denyFriendship(friendship.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _requests = _requests
            .where((request) => request.id != updated.id)
            .toList(growable: false);
      });

      final String message = accept
          ? 'Friend request accepted.'
          : 'Friend request declined.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

      if (accept) {
        _loadFriends();
      }
      widget.onFriendshipUpdated();
    } on FriendApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to ${accept ? 'accept' : 'deny'} friendship',
        name: 'FriendshipCenterSheet',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Unable to accept this request right now.'
                : 'Unable to decline this request right now.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _activeFriendshipId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Friends & Requests',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        _buildTabSelector(),
        if (_activeTab == _FriendshipTab.requests) ...[
          const SizedBox(height: 16),
          _buildDirectionSelector(),
        ],
        const SizedBox(height: 16),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildTabSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: _FriendshipTab.values.map((tab) {
        final bool isSelected = tab == _activeTab;
        final String label =
            tab == _FriendshipTab.friends ? 'Friends' : 'Requests';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: ChoiceChip(
            label: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black87 : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            selected: isSelected,
            selectedColor: Colors.white,
            backgroundColor: Colors.white12,
            onSelected: (bool selected) {
              if (!selected) {
                return;
              }
              _onTabSelected(tab);
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDirectionSelector() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: FriendshipPendingDirection.values.map((direction) {
        final bool isSelected = direction == _direction;
        return ChoiceChip(
          label: Text(
            direction.label,
            style: TextStyle(
              color: isSelected ? Colors.black87 : Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          selected: isSelected,
          selectedColor: Colors.white,
          backgroundColor: Colors.white12,
          onSelected: (bool selected) {
            if (!selected || direction == _direction) {
              return;
            }
            _onDirectionSelected(direction);
          },
        );
      }).toList(),
    );
  }

  Widget _buildContent() {
    if (_activeTab == _FriendshipTab.friends) {
      return _buildFriendsContent();
    }
    return _buildRequestsContent();
  }

  Widget _buildFriendsContent() {
    if (_isLoadingFriends) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_friendsError != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _friendsError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _loadFriends,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
            ),
            child: const Text('Try again'),
          ),
        ],
      );
    }

    if (_friends.isEmpty) {
      return const Center(
        child: Text(
          'No friends yet. Send a request to start sharing!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: _friends.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final friend = _friends[index];
        return _FriendListTile(friend: friend);
      },
    );
  }

  Widget _buildRequestsContent() {
    if (_isLoadingRequests) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (_requestsError != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _requestsError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _loadRequests,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
            ),
            child: const Text('Try again'),
          ),
        ],
      );
    }

    if (_requests.isEmpty) {
      return const Center(
        child: Text(
          'No pending requests.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: _requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final friendship = _requests[index];
        return _FriendRequestTile(
          friendship: friendship,
          currentUserId: widget.currentUserId,
          onDecision: _handleDecision,
          isProcessing: _activeFriendshipId == friendship.id,
          processingAccept: _isActiveActionAccept,
        );
      },
    );
  }
}

class _FriendListTile extends StatelessWidget {
  const _FriendListTile({required this.friend});

  final FriendListItem friend;

  @override
  Widget build(BuildContext context) {
    final String displayName =
        friend.displayName.isNotEmpty ? friend.displayName : friend.friendUserId;
    final String subtitle = friend.friendUserId;
    final DateTime acceptedAt =
        (friend.acceptedAt ?? friend.createdAt).toLocal();
    final MaterialLocalizations localizations = MaterialLocalizations.of(context);
    final String acceptedLabel =
        'Friends since: ${localizations.formatMediumDate(acceptedAt)} • ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(acceptedAt))}';
    final String pictureUrl = friend.pictureUrl.isNotEmpty
        ? _resolvePhotoUrl(friend.pictureUrl)
        : '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: pictureUrl.isNotEmpty
              ? Image.network(
                  pictureUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _friendAvatarPlaceholder(),
                )
              : _friendAvatarPlaceholder(),
        ),
        title: Text(
          displayName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              acceptedLabel,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _friendAvatarPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.person_outline, color: Colors.white54),
    );
  }
}

class _FriendFilterOption {
  const _FriendFilterOption({required this.id, required this.label});

  final String? id;
  final String label;
}

class _FriendRequestTile extends StatelessWidget {
  const _FriendRequestTile({
    required this.friendship,
    required this.currentUserId,
    required this.onDecision,
    required this.isProcessing,
    required this.processingAccept,
  });

  final FriendshipResponse friendship;
  final String currentUserId;
  final Future<void> Function({
    required FriendshipResponse friendship,
    required bool accept,
  }) onDecision;
  final bool isProcessing;
  final bool processingAccept;

  @override
  Widget build(BuildContext context) {
    final bool isIncoming = friendship.isAddressee(currentUserId);
    final String otherUserId = friendship.isRequester(currentUserId)
        ? friendship.addresseeId
        : friendship.requesterId;
    final String headline =
        isIncoming ? 'Request from $otherUserId' : 'Awaiting $otherUserId';
    final String subtitle = isIncoming
        ? 'You can accept or decline this request.'
        : 'Pending response from $otherUserId.';
    final DateTime createdAtLocal = friendship.createdAt.toLocal();
    final MaterialLocalizations localizations = MaterialLocalizations.of(context);
    final String requestedLabel =
        'Requested at: ${localizations.formatMediumDate(createdAtLocal)} • ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(createdAtLocal))}';

    final bool showActions = isIncoming && friendship.isPending;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headline,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            requestedLabel,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          if (showActions) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isProcessing
                        ? null
                        : () => onDecision(
                              friendship: friendship,
                              accept: false,
                            ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: isProcessing && !processingAccept
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isProcessing
                        ? null
                        : () => onDecision(
                              friendship: friendship,
                              accept: true,
                            ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: isProcessing && processingAccept
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PhotoFeedPreview extends StatefulWidget {
  const _PhotoFeedPreview({
    required this.photos,
    required this.resolvePhotoUrl,
  });

  final List<PhotoResponse> photos;
  final String Function(String url) resolvePhotoUrl;

  @override
  State<_PhotoFeedPreview> createState() => _PhotoFeedPreviewState();
}

class _PhotoFeedPreviewState extends State<_PhotoFeedPreview> {
  late final PageController _controller;
  int _currentIndex = 0;
  String? _lastFirstPhotoId;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _lastFirstPhotoId =
        widget.photos.isNotEmpty ? widget.photos.first.id : null;
  }

  @override
  void didUpdateWidget(covariant _PhotoFeedPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.photos.isEmpty) {
      _lastFirstPhotoId = null;
      if (_currentIndex != 0) {
        _currentIndex = 0;
        _scheduleUiUpdate();
      }
      return;
    }

    final String? newFirstId =
        widget.photos.isNotEmpty ? widget.photos.first.id : null;
    if (newFirstId != null && newFirstId != _lastFirstPhotoId) {
      _lastFirstPhotoId = newFirstId;
      if (_controller.hasClients) {
        _controller.jumpToPage(0);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_controller.hasClients) {
            return;
          }
          _controller.jumpToPage(0);
        });
      }
      if (_currentIndex != 0) {
        _currentIndex = 0;
        _scheduleUiUpdate();
      }
      return;
    }

    if (_currentIndex >= widget.photos.length) {
      final int newIndex = widget.photos.length - 1;
      if (newIndex < 0) {
        return;
      }
      if (_controller.hasClients) {
        _controller.jumpToPage(newIndex);
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_controller.hasClients) {
            return;
          }
          _controller.jumpToPage(newIndex);
        });
      }
      if (_currentIndex != newIndex) {
        _currentIndex = newIndex;
        _scheduleUiUpdate();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return const SizedBox.shrink();
    }

    final int safeIndex =
        _currentIndex.clamp(0, widget.photos.length - 1);

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          scrollDirection: Axis.vertical,
          physics: const BouncingScrollPhysics(),
          itemCount: widget.photos.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          itemBuilder: (_, index) {
            final photo = widget.photos[index];
            final String imageUrl = widget.resolvePhotoUrl(photo.imageUrl);
            return Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.white10,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.broken_image,
                  color: Colors.white70,
                  size: 48,
                ),
              ),
            );
          },
        ),
        Positioned(
          top: 16,
          right: 16,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                '${safeIndex + 1}/${widget.photos.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildCaptionOverlay(widget.photos[safeIndex]),
        ),
      ],
    );
  }

  Widget _buildCaptionOverlay(PhotoResponse photo) {
    final String caption =
        photo.caption?.trim().isNotEmpty == true ? photo.caption!.trim() : 'No caption';
    final String uploader = photo.uploaderDisplayName.isNotEmpty
        ? photo.uploaderDisplayName
        : (photo.uploaderId.isNotEmpty ? photo.uploaderId : 'Unknown uploader');
    final DateTime localTime = photo.createdAt.toLocal();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black87],
          stops: [0.0, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            caption,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$uploader • $localTime',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  void _scheduleUiUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
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
    final String uploader = photo.uploaderDisplayName.isNotEmpty
        ? photo.uploaderDisplayName
        : (photo.uploaderId.isNotEmpty ? photo.uploaderId : 'Unknown');
    final DateTime uploadedAt = photo.createdAt.toLocal();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
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
          '$uploader • $uploadedAt',
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
