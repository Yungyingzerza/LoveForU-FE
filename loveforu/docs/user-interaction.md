# LoveForU User Interaction Guide

## Concept

- LoveForU behaves like a private, Locket-style camera feed for LINE friends. Each capture is pushed to selected friends and appears instantly in a looping, vertical feed on the home screen.
- The app depends on a valid LINE login and backend APIs exposed through `API_BASE_URL`. Users must have `.env` entries for `LINE_CHANNEL_ID` and `API_BASE_URL` configured before launch.

## Launch & Authentication

- On startup the app restores any stored LINE session. If restoration works, the latest photos and friends load automatically.
- Without a session, the home screen shows a single call to action: `Login with LINE`. Tapping it invokes LINE OAuth, retrieves the user profile, and exchanges the access token with the backend so the app can load photos, friends, and chat data.
- Authentication errors surface as inline red text or snackbars, prompting the user to retry.

## Home Screen Layout

- **Top bar**: the left avatar opens a profile menu, the center pill shows whose photos are visible (tap to filter), and the right bubble button opens chats.
- **Preview area**: a square viewport renders the latest photos as a vertical, swipeable stack. Each slide shows the image count (e.g. `2/5`) plus a caption/name/timestamp overlay.
- **Bottom controls**: gallery button (imports from camera roll), shutter button (opens the upload workflow), and a context-aware third button. When viewing a friend’s photo it offers _Reply with photo_; otherwise it opens the history sheet. A “History” pill below lists recent uploads and allows deletions.
- Snackbars and inline messages appear near the bottom to report errors (e.g., failed loads, missing permissions).

## Viewing & Filtering Photos

- The feed defaults to `Everyone`, mixing your uploads with accepted friends’ photos in reverse chronological order.
- Tapping the filter pill opens a modal with `Everyone`, `Just me`, and each accepted friend. Choosing an entry filters the feed and adjusts captions to match the active person. The latest item in the filtered list becomes the new preview.
- Pulling down at the top photo triggers a refresh, reloading both the feed and friends in the background.

## Capturing & Sharing Moments

- Pressing the shutter launches the Upload screen with a live camera preview. If the user previously chose a gallery image, that file appears immediately.
- After capturing, the user can add a caption, toggle “Share with all accepted friends,” or pick specific recipients via chips. Selecting “Retake” resets the capture; “Upload” sends the photo to the backend.
- Successful uploads close the screen, push the new photo to the top of the feed, and reset any reply-in-progress state. Upload failures show a snackbar message and keep the user on the screen for retry.

## Replying to A Friend’s Photo

- While a friend’s photo is active in the feed, the right control becomes a _Reply with photo_ button. Tapping it prompts for an optional message, then reuses the upload flow to capture or choose a response.
- Once sent, the app posts the reply via the backend and confirms with a snackbar.

## Photo History & Management

- Tapping the “History” pill displays a bottom sheet listing the photos in the current filter (everyone, self, or a specific friend).
- Each tile shows a thumbnail, caption, uploader, and relative timestamp. Your own photos include a delete icon; confirming removal immediately closes the sheet and refreshes the feed.
- If no photos exist for the active filter, the sheet explains why (e.g., “No photos from Alex yet”).

## Device Gallery Access

- The left square button on the control row opens the device gallery through `ImagePicker`. After selecting a photo, the user continues with the Upload screen as if it was captured in-app.
- Canceling or hitting “Retake” discards the selection; choosing “Upload” sends it to the same recipients workflow.

## Managing Friends

- Opening the profile menu (avatar button) reveals actions: Chats, Refresh profile, Add friend, Friend requests, and Logout. The header shows the LINE display name, picture, and user ID with a quick copy shortcut.
- **Add friend** prompts for a LINE user ID (`Uxxxxxxxxxxxxxxxxxxxx`). Submitting calls the backend; success or failure is announced via snackbar.
- **Friend requests** opens the Friendship Center sheet:
  - Tabs for `Friends` and `Requests`.
  - The `Friends` tab lists accepted friends with avatars, names, and “Friends since” metadata.
  - The `Requests` tab can toggle between `Incoming` and `Outgoing`. Incoming entries provide Accept and Decline buttons; outgoing requests indicate pending status.
  - Actions update the backend, refresh the lists, and notify the home screen so recipient options stay current.

## Messaging with Friends

- The chat bubble in the top bar or the menu shortcut opens the chat threads screen. It lists recent conversations and, when available, a “Start a new chat” section for friends without an active thread.
- Pull-to-refresh reloads threads. Tapping a thread opens the conversation screen, which shows message history, supports pull-to-refresh, and provides a composer for new messages.
- Sending a message immediately appends it to the timeline and notifies the previous screen on return so the thread list can reflect the latest activity.

## Logging Out

- Selecting Logout from the profile menu clears cached LINE credentials, wipes in-memory data (photos, friends, chats), and returns the home screen to the logged-out state. Any future interaction requires logging back in with LINE.
