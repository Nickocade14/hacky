import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models/auth.dart';
import '../shell/screen_load.dart';
import '../widgets/app_widgets.dart';
import '../widgets/auth_widgets.dart';

/// 08 My profile (Me tab, mobile/design/profile-wireframes.svg).
///
/// Placeholder with a working Sign out. The finished screen edits the public
/// profile (`PATCH /api/me/profile`, `ApiClient.updateProfile`, then
/// [onProfileChanged]) and, when [eventSlug] is set, the event intake
/// (`PATCH /api/events/{slug}/me`, `ApiClient.updateEventMe`). Sign out stays
/// at the bottom.
class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({
    super.key,
    required this.api,
    required this.me,
    required this.eventSlug,
    required this.onProfileChanged,
  });

  final ApiClient api;

  /// The signed-in user, to fill the form.
  final Me me;

  /// The current event, or null before the user joins one (then only the
  /// public profile part is shown).
  final String? eventSlug;

  /// Tell the shell about a saved profile, so the other tabs show it.
  final ValueChanged<PublicProfile> onProfileChanged;

  Future<void> _signOut(BuildContext context) async {
    await api.logout();
    if (context.mounted) ScreenLoad.toLogin(context);
  }

  @override
  Widget build(BuildContext context) {
    return SignedInPage(
      title: 'My profile',
      body: ScreenPlaceholder(
        number: '08',
        summary: 'Edit your profile and what Hacky knows about you for '
            'this event.',
        children: [
          AppCard(
            child: Row(
              spacing: 14,
              children: [
                PersonAvatar(name: me.profile.name, size: 44),
                Expanded(
                  child: Text(
                    '${me.profile.name}\n@${me.profile.handle}',
                    style: const TextStyle(height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          SecondaryButton(
            label: 'Sign out',
            onPressed: () => _signOut(context),
          ),
        ],
      ),
    );
  }
}
