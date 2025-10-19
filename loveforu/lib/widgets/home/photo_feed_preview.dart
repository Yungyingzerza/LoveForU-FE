import 'package:flutter/material.dart';

import 'package:loveforu/services/photo_api_service.dart';
import 'package:loveforu/utils/display_utils.dart';

class PhotoFeedPreview extends StatefulWidget {
  const PhotoFeedPreview({
    super.key,
    required this.photos,
    required this.resolvePhotoUrl,
    this.onActivePhotoChanged,
    this.onRefresh,
  });

  final List<PhotoResponse> photos;
  final String Function(String) resolvePhotoUrl;
  final void Function(PhotoResponse?)? onActivePhotoChanged;
  final Future<void> Function()? onRefresh;

  @override
  State<PhotoFeedPreview> createState() => _PhotoFeedPreviewState();
}

class _PhotoFeedPreviewState extends State<PhotoFeedPreview> {
  late final PageController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    if (widget.photos.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onActivePhotoChanged?.call(widget.photos.first);
      });
    }
  }

  @override
  void didUpdateWidget(covariant PhotoFeedPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photos.length != widget.photos.length) {
      if (_currentIndex >= widget.photos.length) {
        _currentIndex = widget.photos.isNotEmpty ? widget.photos.length - 1 : 0;
      }
      _scheduleUiUpdate();
      _notifyActivePhoto(
        widget.photos.isNotEmpty ? widget.photos[_currentIndex] : null,
      );
    } else if (widget.photos.isNotEmpty &&
        widget.photos.first.id != oldWidget.photos.first.id) {
      _controller.jumpToPage(0);
      _currentIndex = 0;
      _notifyActivePhoto(widget.photos.first);
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

    final int safeIndex = _currentIndex.clamp(0, widget.photos.length - 1);
    final bool refreshEnabled = widget.onRefresh != null && _currentIndex == 0;
    Widget content = Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          scrollDirection: Axis.vertical,
          physics: refreshEnabled
              ? const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                )
              : const PageScrollPhysics(),
          itemCount: widget.photos.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
            if (index >= 0 && index < widget.photos.length) {
              widget.onActivePhotoChanged?.call(widget.photos[index]);
            }
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

    if (widget.onRefresh != null) {
      content = RefreshIndicator(
        onRefresh: () async {
          if (_currentIndex != 0) {
            return;
          }
          await widget.onRefresh!();
        },
        color: Colors.white,
        backgroundColor: const Color(0xFF0F1F39),
        child: NotificationListener<OverscrollIndicatorNotification>(
          onNotification: (notification) {
            notification.disallowIndicator();
            return false;
          },
          child: content,
        ),
      );
    }

    return content;
  }

  Widget _buildCaptionOverlay(PhotoResponse photo) {
    final String caption = photo.caption?.trim().isNotEmpty == true
        ? photo.caption!.trim()
        : 'No caption';
    final String uploader = photo.uploaderDisplayName.isNotEmpty
        ? photo.uploaderDisplayName
        : (photo.uploaderId.isNotEmpty ? photo.uploaderId : 'Unknown uploader');
    final DateTime localTime = photo.createdAt.toLocal();
    final String timeLabel = formatElapsedTime(localTime);

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
            '$uploader • $timeLabel',
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

  void _notifyActivePhoto(PhotoResponse? photo) {
    final callback = widget.onActivePhotoChanged;
    if (callback == null) {
      return;
    }
    void invoke() {
      if (!mounted) {
        return;
      }
      callback(photo);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => invoke());
  }
}
