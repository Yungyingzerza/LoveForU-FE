import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:loveforu/services/friend_api_service.dart';
import 'package:loveforu/services/photo_api_service.dart';
import 'package:loveforu/theme/app_gradients.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({
    super.key,
    required this.photoApiService,
    this.initialFile,
    this.friends = const <FriendListItem>[],
  });

  final PhotoApiService photoApiService;
  final XFile? initialFile;
  final List<FriendListItem> friends;

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  CameraController? _cameraController;
  Future<void>? _initializationFuture;
  XFile? _capturedFile;
  bool _isCapturing = false;
  bool _isUploading = false;
  String? _errorMessage;
  bool _shareWithEveryone = true;
  final Set<String> _selectedFriendIds = <String>{};
  final TextEditingController _captionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final preselectedFile = widget.initialFile;
    if (preselectedFile != null) {
      _capturedFile = preselectedFile;
    } else {
      _setupCamera();
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _setupCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No camera available on this device.';
        });
        return;
      }

      CameraDescription selected = cameras.first;
      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.front) {
          selected = camera;
          break;
        }
      }

      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _cameraController = controller;
      final initialization = controller.initialize();
      setState(() {
        _initializationFuture = initialization;
        _errorMessage = null;
      });
      await initialization;
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to start the camera. Please check permissions.';
      });
    }
  }

  Future<void> _capturePhoto() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (_isCapturing) return;

    setState(() {
      _isCapturing = true;
      _errorMessage = null;
    });

    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      setState(() {
        _capturedFile = file;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to capture photo. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> _uploadPhoto() async {
    final captured = _capturedFile;
    if (captured == null || _isUploading) {
      return;
    }

    List<String>? friendIds;
    if (!_shareWithEveryone) {
      friendIds = _selectedFriendIds.toList()..sort();
      if (friendIds.isEmpty) {
        setState(() {
          _errorMessage = 'Select at least one friend to share with.';
        });
        return;
      }
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      final caption = _captionController.text.trim();
      final response = await widget.photoApiService.uploadPhoto(
        image: File(captured.path),
        caption: caption.isEmpty ? null : caption,
        friendIds: friendIds,
      );
      if (!mounted) return;
      Navigator.of(context).pop(response);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Upload failed. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _retake() {
    setState(() {
      _capturedFile = null;
      _captionController.clear();
      _errorMessage = null;
      _shareWithEveryone = true;
      _selectedFriendIds.clear();
    });
    if (_cameraController == null) {
      _setupCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Upload', style: TextStyle(color: Colors.white)),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: appBackgroundGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _buildPreview(),
                  ),
                ),
                const SizedBox(height: 16),
                if (_capturedFile != null) ...[
                  TextField(
                    controller: _captionController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Add a caption (optional)',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  _buildShareSection(),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isUploading
                            ? null
                            : _capturedFile != null
                                ? _retake
                                : () => Navigator.of(context).maybePop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(_capturedFile != null ? 'Retake' : 'Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isUploading
                            ? null
                            : _capturedFile != null
                                ? _uploadPhoto
                                : _capturePhoto,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isUploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_capturedFile != null ? 'Upload' : 'Capture'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShareSection() {
    final List<FriendListItem> friends = widget.friends;
    if (friends.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'No accepted friends yet. Uploads stay private until someone is accepted.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final List<FriendListItem> sortedFriends =
        List<FriendListItem>.from(friends)
          ..sort((a, b) {
            final String aName =
                a.displayName.isNotEmpty ? a.displayName : a.friendUserId;
            final String bName =
                b.displayName.isNotEmpty ? b.displayName : b.friendUserId;
            return aName.toLowerCase().compareTo(bName.toLowerCase());
          });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Share with all accepted friends',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              Switch(
                value: _shareWithEveryone,
                onChanged: _isUploading
                    ? null
                    : (value) {
                        setState(() {
                          _shareWithEveryone = value;
                          if (value) {
                            _selectedFriendIds.clear();
                          }
                          _errorMessage = null;
                        });
                      },
                activeThumbColor: Colors.lightBlueAccent,
                inactiveThumbColor: Colors.white60,
                inactiveTrackColor: Colors.white30,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _shareWithEveryone
              ? 'All accepted friends will see this photo.'
              : 'Choose at least one friend to receive this photo.',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        if (!_shareWithEveryone) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sortedFriends.map((friend) {
              final String userId = friend.friendUserId;
              final bool isSelected = _selectedFriendIds.contains(userId);
              final String label =
                  friend.displayName.isNotEmpty ? friend.displayName : userId;
              return FilterChip(
                label: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                selected: isSelected,
                onSelected: _isUploading
                    ? null
                    : (selected) {
                        setState(() {
                          if (selected) {
                            _selectedFriendIds.add(userId);
                          } else {
                            _selectedFriendIds.remove(userId);
                          }
                          _errorMessage = null;
                        });
                      },
                backgroundColor: Colors.white12,
                selectedColor: Colors.white,
                checkmarkColor: Colors.black87,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              );
            }).toList(),
          ),
          if (_selectedFriendIds.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Select at least one friend.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildPreview() {
    if (_capturedFile != null) {
      return Image.file(
        File(_capturedFile!.path),
        fit: BoxFit.cover,
      );
    }

    final future = _initializationFuture;
    final controller = _cameraController;

    if (future == null || controller == null) {
      if (_errorMessage != null) {
        return _buildErrorPlaceholder();
      }
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return FutureBuilder<void>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && controller.value.isInitialized) {
          return Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(controller),
              if (_isCapturing)
                Container(
                  color: Colors.black26,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          );
        } else if (snapshot.hasError) {
          return _buildErrorPlaceholder();
        } else {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
      },
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: Colors.black26,
      child: Center(
        child: Text(
          _errorMessage ?? 'Camera preview not available.',
          style: const TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
