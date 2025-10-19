import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:loveforu/controllers/upload_controller.dart';
import 'package:loveforu/services/friend_api_service.dart';
import 'package:loveforu/services/photo_api_service.dart';
import 'package:loveforu/widgets/common/app_gradient_scaffold.dart';

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
  late final UploadController _controller;

  @override
  void initState() {
    super.initState();
    _controller = UploadController(
      photoApiService: widget.photoApiService,
      initialFile: widget.initialFile,
      friends: widget.friends,
    );
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return AppGradientScaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text('Upload', style: TextStyle(color: Colors.white)),
          ),
          padding: const EdgeInsets.all(20),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: _buildPreview(),
                ),
              ),
              const SizedBox(height: 16),
              if (_controller.capturedFile != null) ...[
                TextField(
                  controller: _controller.captionController,
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
              if (_controller.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _controller.errorMessage!,
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _controller.isUploading
                          ? null
                          : _controller.capturedFile != null
                              ? _controller.reset
                              : () => Navigator.of(context).maybePop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(_controller.capturedFile != null ? 'Retake' : 'Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _controller.isUploading
                          ? null
                          : _controller.capturedFile != null
                              ? _handleUpload
                              : () => _controller.capturePhoto(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _controller.isUploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_controller.capturedFile != null ? 'Upload' : 'Capture'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPreview() {
    final captured = _controller.capturedFile;
    if (captured != null) {
      return Image.file(
        File(captured.path),
        fit: BoxFit.cover,
      );
    }

    final future = _controller.initializationFuture;
    final cameraController = _controller.cameraController;

    if (future == null || cameraController == null) {
      if (_controller.errorMessage != null) {
        return _buildErrorPlaceholder();
      }
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return FutureBuilder<void>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            cameraController.value.isInitialized) {
          return Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(cameraController),
              if (_controller.isCapturing)
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
          _controller.errorMessage ?? 'Camera preview not available.',
          style: const TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildShareSection() {
    final List<FriendListItem> friends = _controller.friends;
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

    final List<FriendListItem> sortedFriends = List<FriendListItem>.from(friends)
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
                value: _controller.shareWithEveryone,
                onChanged: _controller.isUploading
                    ? null
                    : (value) => _controller.toggleShareWithEveryone(value),
                activeThumbColor: Colors.lightBlueAccent,
                inactiveThumbColor: Colors.white60,
                inactiveTrackColor: Colors.white30,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _controller.shareWithEveryone
              ? 'All accepted friends will see this photo.'
              : 'Choose at least one friend to receive this photo.',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        if (!_controller.shareWithEveryone) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sortedFriends.map((friend) {
              final String userId = friend.friendUserId;
              final bool isSelected =
                  _controller.selectedFriendIds.contains(userId);
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
                onSelected: _controller.isUploading
                    ? null
                    : (_) => _controller.toggleFriendSelection(userId),
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
          if (_controller.selectedFriendIds.isEmpty)
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

  Future<void> _handleUpload() async {
    final result = await _controller.uploadPhoto();
    if (!mounted) return;
    if (result.success && result.photo != null) {
      Navigator.of(context).pop(result.photo);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
    }
  }
}
