import 'package:flutter/material.dart';

import 'package:loveforu/services/photo_api_service.dart';
import 'package:loveforu/utils/display_utils.dart';

class PhotoListTile extends StatelessWidget {
  const PhotoListTile({
    super.key,
    required this.photo,
    this.canDelete = false,
    this.isDeleting = false,
    this.onDelete,
  });

  final PhotoResponse photo;
  final bool canDelete;
  final bool isDeleting;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final String imageUrl = resolvePhotoUrl(photo.imageUrl);
    final String caption = photo.caption?.isNotEmpty == true
        ? photo.caption!
        : 'No caption';
    final String uploader = photo.uploaderDisplayName.isNotEmpty
        ? photo.uploaderDisplayName
        : (photo.uploaderId.isNotEmpty ? photo.uploaderId : 'Unknown');
    final DateTime uploadedAt = photo.createdAt.toLocal();
    final String uploadLabel = formatElapsedTime(uploadedAt);

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
          '$uploader • $uploadLabel',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: canDelete
            ? (isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.white70,
                    ),
                    tooltip: 'Delete photo',
                    onPressed: onDelete,
                  ))
            : null,
      ),
    );
  }
}
