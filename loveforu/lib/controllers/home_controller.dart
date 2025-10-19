import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_line_sdk/flutter_line_sdk.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:loveforu/services/chat_api_service.dart';
import 'package:loveforu/services/cookie_http_client.dart';
import 'package:loveforu/services/friend_api_service.dart';
import 'package:loveforu/services/photo_api_service.dart';
import 'package:loveforu/services/user_api_service.dart';

class HomeController extends ChangeNotifier {
  HomeController({
    CookieHttpClient? cookieClient,
    ImagePicker? imagePicker,
  })  : _cookieClient = cookieClient ?? CookieHttpClient(),
        _imagePicker = imagePicker ?? ImagePicker() {
    _userApiService = UserApiService(client: _cookieClient);
    _friendApiService = FriendApiService(client: _cookieClient);
    _photoApiService = PhotoApiService(client: _cookieClient);
    _chatApiService = ChatApiService(client: _cookieClient);
  }

  final CookieHttpClient _cookieClient;
  final ImagePicker _imagePicker;
  late final UserApiService _userApiService;
  late final FriendApiService _friendApiService;
  late final PhotoApiService _photoApiService;
  late final ChatApiService _chatApiService;

  bool _disposed = false;
  bool _initialized = false;

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
  PhotoResponse? _activePreviewPhoto;
  bool _isReplyingWithPhoto = false;
  String? _deletingPhotoId;

  ChatApiService get chatApiService => _chatApiService;
  FriendApiService get friendApiService => _friendApiService;
  PhotoApiService get photoApiService => _photoApiService;

  String get pictureUrl => _pictureUrl;
  String get displayName => _displayName;
  String get userId => _userId;
  String? get errorMessage => _errorMessage;
  bool get isLoadingPhotos => _isLoadingPhotos;
  bool get isAuthenticating => _isAuthenticating;
  bool get isRestoringSession => _isRestoringSession;
  List<PhotoResponse> get photos => List.unmodifiable(_photos);
  List<FriendListItem> get friends => List.unmodifiable(_friends);
  String? get selectedFriendUserId => _selectedFriendUserId;
  bool get isAddingFriend => _isAddingFriend;
  PhotoResponse? get activePreviewPhoto => _activePreviewPhoto;
  bool get isReplyingWithPhoto => _isReplyingWithPhoto;
  String? get deletingPhotoId => _deletingPhotoId;

  List<PhotoResponse> get visiblePhotos {
    if (_selectedFriendUserId == null || _selectedFriendUserId!.isEmpty) {
      return List.unmodifiable(_photos);
    }
    final filtered = _photos
        .where((photo) => photo.uploaderId == _selectedFriendUserId)
        .toList(growable: false);
    return filtered;
  }

  String currentFriendFilterLabel() {
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

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    await _restoreSession();
  }

  Future<void> refreshHome() async {
    await Future.wait([
      _loadPhotos(),
      _loadFriends(),
    ]);
  }

  Future<void> login() async {
    if (_isAuthenticating) {
      return;
    }
    _isAuthenticating = true;
    _notify();
    try {
      final result = await LineSDK.instance.login();
      _displayName = result.userProfile?.displayName ?? '';
      _userId = result.userProfile?.userId ?? '';
      _pictureUrl = result.userProfile?.pictureUrl ?? '';
      _errorMessage = null;
      _notify();

      final accessToken = result.accessToken.value;
      if (accessToken.isEmpty) {
        throw Exception('Missing LINE access token');
      }

      final response = await _userApiService.exchangeLineToken(accessToken);
      _displayName = response.displayName.isNotEmpty
          ? response.displayName
          : _displayName;
      _userId = response.id.isNotEmpty ? response.id : _userId;
      _pictureUrl = response.pictureUrl?.isNotEmpty == true
          ? response.pictureUrl!
          : _pictureUrl;
      _selectedFriendUserId = null;
      _notify();

      await _loadPhotos();
      await _loadFriends();
    } on Exception {
      _errorMessage = 'Login failed. Please try again.';
      _notify();
    } finally {
      _isAuthenticating = false;
      _notify();
    }
  }

  Future<void> logout() async {
    try {
      await LineSDK.instance.logout();
    } catch (_) {
      _errorMessage = 'Logout failed. Please try again.';
      _notify();
      return;
    }

    _displayName = '';
    _userId = '';
    _pictureUrl = '';
    _photos = <PhotoResponse>[];
    _friends = <FriendListItem>[];
    _selectedFriendUserId = null;
    _isLoadingPhotos = false;
    _errorMessage = null;
    _isAddingFriend = false;
    _activePreviewPhoto = null;
    _isReplyingWithPhoto = false;
    _cookieClient.clearCookies();
    _notify();
  }

  Future<void> refreshProfile() async {
    try {
      final profile = await LineSDK.instance.getProfile();
      _displayName = profile.displayName;
      _userId = profile.userId;
      _pictureUrl = profile.pictureUrl ?? '';
      _errorMessage = null;
      _notify();
    } catch (_) {
      _errorMessage = 'Failed to refresh profile.';
      _notify();
    }
  }

  void selectFriend(String? friendUserId) {
    _selectedFriendUserId = friendUserId;
    final filtered = visiblePhotos;
    _activePreviewPhoto = filtered.isNotEmpty ? filtered.first : null;
    _notify();
  }

  void updateActivePhoto(PhotoResponse? photo) {
    if (_activePreviewPhoto?.id == photo?.id) {
      return;
    }
    _activePreviewPhoto = photo;
    _notify();
  }

  Future<AddFriendResult> addFriend(String friendUserId) async {
    if (_isAddingFriend) {
      return const AddFriendResult(message: 'Friend request already in progress.', success: false);
    }

    _isAddingFriend = true;
    _notify();

    try {
      final friendship = await _friendApiService.createFriendship(
        friendUserId: friendUserId,
      );
      final String otherUserId = friendship.requesterId == _userId
          ? friendship.addresseeId
          : friendship.requesterId;

      String message;
      if (friendship.acceptedFromIncomingRequest || friendship.isAccepted) {
        message = otherUserId.isNotEmpty
            ? 'You and $otherUserId are now friends!'
            : 'Friend request accepted!';
        await _loadPhotos();
        await _loadFriends();
      } else if (friendship.isPending) {
        message = otherUserId.isNotEmpty
            ? 'Friend request sent to $otherUserId.'
            : 'Friend request sent.';
      } else {
        message = 'Friendship updated.';
      }

      return AddFriendResult(message: message, success: true);
    } on FriendApiException catch (error) {
      return AddFriendResult(message: error.message, success: false);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to add friend',
        name: 'HomeController',
        error: error,
        stackTrace: stackTrace,
      );
      return const AddFriendResult(
        message: 'Unable to add friend right now.',
        success: false,
      );
    } finally {
      _isAddingFriend = false;
      _notify();
    }
  }

  Future<DeletePhotoResult> deletePhoto(PhotoResponse photo) async {
    if (_deletingPhotoId != null) {
      return const DeletePhotoResult(message: 'Deletion already in progress.', success: false);
    }

    _deletingPhotoId = photo.id;
    _notify();

    try {
      await _photoApiService.deletePhoto(photo.id);
      _photos = _photos.where((item) => item.id != photo.id).toList();
      final updated = visiblePhotos;
      _activePreviewPhoto = updated.isNotEmpty ? updated.first : null;
      _notify();
      return const DeletePhotoResult(message: 'Photo deleted.', success: true);
    } on PhotoApiException catch (error) {
      return DeletePhotoResult(message: error.message, success: false);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to delete photo',
        name: 'HomeController',
        error: error,
        stackTrace: stackTrace,
      );
      return const DeletePhotoResult(
        message: 'Unable to delete photo right now.',
        success: false,
      );
    } finally {
      _deletingPhotoId = null;
      _notify();
    }
  }

  Future<PhotoReplyResult> replyWithPhoto({
    required PhotoResponse photo,
    required FriendListItem friend,
    required String? messageContent,
  }) async {
    if (_isReplyingWithPhoto) {
      return const PhotoReplyResult(
        message: 'Already sending a photo. Please wait.',
        success: false,
      );
    }
    if (photo.id.isEmpty) {
      return const PhotoReplyResult(
        message: 'Unable to send this photo.',
        success: false,
      );
    }

    _isReplyingWithPhoto = true;
    _notify();

    try {
      await _chatApiService.sendMessage(
        friendshipId: friend.friendshipId,
        content: messageContent?.isNotEmpty == true ? messageContent : null,
        photoId: photo.id,
      );
      final recipient = friend.displayName.isNotEmpty
          ? friend.displayName
          : friend.friendUserId;
      return PhotoReplyResult(
        message: 'Photo sent to $recipient.',
        success: true,
      );
    } on ChatApiException catch (error) {
      return PhotoReplyResult(message: error.message, success: false);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to reply with photo',
        name: 'HomeController',
        error: error,
        stackTrace: stackTrace,
      );
      return const PhotoReplyResult(
        message: 'Unable to send photo right now.',
        success: false,
      );
    } finally {
      _isReplyingWithPhoto = false;
      _notify();
    }
  }

  Future<XFilePickResult> pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      return XFilePickResult(file: pickedFile);
    } on PlatformException catch (_) {
      return const XFilePickResult(
        file: null,
        errorMessage: 'Gallery permission denied.',
      );
    } catch (_) {
      return const XFilePickResult(
        file: null,
        errorMessage: 'Unable to pick an image.',
      );
    }
  }

  Future<void> addUploadedPhoto(PhotoResponse photo) async {
    _photos = <PhotoResponse>[photo, ..._photos];
    _errorMessage = null;
    final updated = visiblePhotos;
    _activePreviewPhoto = updated.isNotEmpty ? updated.first : null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _cookieClient.close();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    _isRestoringSession = true;
    _notify();
    try {
      final storedToken = await LineSDK.instance.currentAccessToken;
      if (storedToken == null) {
        return;
      }

      final profile = await LineSDK.instance.getProfile();
      _displayName = profile.displayName;
      _userId = profile.userId;
      _pictureUrl = profile.pictureUrl ?? '';
      _errorMessage = null;
      _notify();

      final response = await _userApiService.exchangeLineToken(
        storedToken.value,
      );
      _displayName = response.displayName.isNotEmpty
          ? response.displayName
          : _displayName;
      _userId = response.id.isNotEmpty ? response.id : _userId;
      _pictureUrl = response.pictureUrl?.isNotEmpty == true
          ? response.pictureUrl!
          : _pictureUrl;
      _selectedFriendUserId = null;
      _notify();

      await _loadPhotos();
      await _loadFriends();
    } catch (e) {
      _errorMessage = 'Session expired. Please log in again.';
      _displayName = '';
      _userId = '';
      _pictureUrl = '';
      _photos = <PhotoResponse>[];
      _friends = <FriendListItem>[];
      _selectedFriendUserId = null;
      _isAddingFriend = false;
      _cookieClient.clearCookies();
      _notify();
    } finally {
      _isRestoringSession = false;
      _notify();
    }
  }

  Future<void> _loadPhotos() async {
    _isLoadingPhotos = true;
    _notify();
    try {
      final photos = await _photoApiService.getPhotos();
      _photos = photos;
      _errorMessage = null;
      final updated = visiblePhotos;
      _activePreviewPhoto = updated.isNotEmpty ? updated.first : null;
      _notify();
    } catch (_) {
      _errorMessage = 'Failed to load photos. Please try again.';
      _notify();
    } finally {
      _isLoadingPhotos = false;
      _notify();
    }
  }

  Future<void> _loadFriends() async {
    try {
      final friends = await _friendApiService.getFriendships();
      _friends = friends;
      if (_selectedFriendUserId != null &&
          _selectedFriendUserId != _userId &&
          !_friends.any(
            (friend) => friend.friendUserId == _selectedFriendUserId,
          )) {
        _selectedFriendUserId = null;
      }
      _notify();
    } on FriendApiException catch (error) {
      developer.log('Failed to load friends', name: 'HomeController', error: error);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to load friends',
        name: 'HomeController',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _notify() {
    if (_disposed) {
      return;
    }
    notifyListeners();
  }
}

class AddFriendResult {
  const AddFriendResult({required this.message, required this.success});

  final String message;
  final bool success;
}

class DeletePhotoResult {
  const DeletePhotoResult({required this.message, required this.success});

  final String message;
  final bool success;
}

class PhotoReplyResult {
  const PhotoReplyResult({required this.message, required this.success});

  final String message;
  final bool success;
}

class XFilePickResult {
  const XFilePickResult({required this.file, this.errorMessage});

  final XFile? file;
  final String? errorMessage;
}
