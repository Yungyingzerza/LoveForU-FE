import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import 'package:loveforu/services/friend_api_service.dart';
import 'package:loveforu/utils/display_utils.dart';

enum FriendshipTab { friends, requests }

class FriendshipCenterSheet extends StatefulWidget {
  const FriendshipCenterSheet({
    super.key,
    required this.friendApiService,
    required this.currentUserId,
    required this.onFriendshipUpdated,
  });

  final FriendApiService friendApiService;
  final String currentUserId;
  final VoidCallback onFriendshipUpdated;

  @override
  State<FriendshipCenterSheet> createState() => _FriendshipCenterSheetState();
}

class _FriendshipCenterSheetState extends State<FriendshipCenterSheet> {
  FriendshipTab _activeTab = FriendshipTab.friends;
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

  void _onTabSelected(FriendshipTab tab) {
    if (_activeTab == tab) {
      return;
    }
    setState(() {
      _activeTab = tab;
    });
    if (tab == FriendshipTab.requests && !_hasLoadedRequests) {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));

      if (accept) {
        _loadFriends();
      }
      widget.onFriendshipUpdated();
    } on FriendApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
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
                ? 'Unable to accept friend request right now.'
                : 'Unable to decline friend request right now.',
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
    final tabs = {
      FriendshipTab.friends: 'Friends',
      FriendshipTab.requests: 'Requests',
    };

    return Column(
      children: [
        Row(
          children: tabs.entries.map((entry) {
            final bool isActive = entry.key == _activeTab;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: OutlinedButton(
                  onPressed: () => _onTabSelected(entry.key),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: isActive ? Colors.white12 : Colors.transparent,
                    side: BorderSide(
                      color: isActive ? Colors.white : Colors.white24,
                    ),
                  ),
                  child: Text(entry.value),
                ),
              ),
            );
          }).toList(growable: false),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _activeTab == FriendshipTab.friends
                ? _buildFriendsTab()
                : _buildRequestsTab(),
          ),
        ),
      ],
    );
  }

  Widget _buildFriendsTab() {
    if (_isLoadingFriends) {
      return const Center(
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white)),
      );
    }

    if (_friendsError != null) {
      return Center(
        child: Text(
          _friendsError!,
          style: const TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (_friends.isEmpty) {
      return const Center(
        child: Text(
          'Add friends to share your moments.',
          style: TextStyle(color: Colors.white60),
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: _friends.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final friend = _friends[index];
        return FriendListTile(friend: friend);
      },
    );
  }

  Widget _buildRequestsTab() {
    if (_isLoadingRequests) {
      return const Center(
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white)),
      );
    }

    if (_requestsError != null) {
      return Center(
        child: Text(
          _requestsError!,
          style: const TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
      );
    }

    final incomingSelected = _direction == FriendshipPendingDirection.incoming;

    return Column(
      children: [
        ToggleButtons(
          isSelected: [
            incomingSelected,
            !incomingSelected,
          ],
          onPressed: (index) {
            final direction = index == 0
                ? FriendshipPendingDirection.incoming
                : FriendshipPendingDirection.outgoing;
            _onDirectionSelected(direction);
          },
          borderRadius: BorderRadius.circular(16),
          fillColor: Colors.white12,
          selectedColor: Colors.white,
          color: Colors.white70,
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Incoming'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Outgoing'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_requests.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                incomingSelected
                    ? 'No incoming requests yet. Share your ID with friends!'
                    : 'No pending outgoing requests.',
                style: const TextStyle(color: Colors.white60),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: _requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) {
                final friendship = _requests[index];
                return FriendRequestTile(
                  friendship: friendship,
                  currentUserId: widget.currentUserId,
                  isProcessing: _activeFriendshipId == friendship.id,
                  processingAccept: _isActiveActionAccept,
                  onDecision: _handleDecision,
                );
              },
            ),
          ),
      ],
    );
  }
}

class FriendListTile extends StatelessWidget {
  const FriendListTile({super.key, required this.friend});

  final FriendListItem friend;

  @override
  Widget build(BuildContext context) {
    final String displayName = friend.displayName.isNotEmpty
        ? friend.displayName
        : friend.friendUserId;
    final String subtitle = friend.friendUserId;
    final DateTime acceptedAt = (friend.acceptedAt ?? friend.createdAt).toLocal();
    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );
    final String acceptedLabel =
        'Friends since: ${localizations.formatMediumDate(acceptedAt)} • ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(acceptedAt))}';
    final String pictureUrl = friend.pictureUrl.isNotEmpty
        ? resolvePhotoUrl(friend.pictureUrl)
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

class FriendRequestTile extends StatelessWidget {
  const FriendRequestTile({
    super.key,
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
    final String headline = isIncoming
        ? 'Request from $otherUserId'
        : 'Awaiting $otherUserId';
    final String subtitle = isIncoming
        ? 'You can accept or decline this request.'
        : 'Pending response from $otherUserId.';
    final DateTime createdAtLocal = friendship.createdAt.toLocal();
    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );
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
          Text(subtitle, style: const TextStyle(color: Colors.white70)),
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
                  child: ElevatedButton(
                    onPressed: isProcessing
                        ? null
                        : () => onDecision(
                              friendship: friendship,
                              accept: true,
                            ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
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
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isProcessing
                        ? null
                        : () => onDecision(
                              friendship: friendship,
                              accept: false,
                            ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
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
              ],
            ),
          ],
        ],
      ),
    );
  }
}
