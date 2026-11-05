import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models/auth.dart';
import '../screens/conversations_screen.dart';
import '../screens/hacky_chat_screen.dart';
import '../screens/home_screen.dart';
import '../screens/join_event_screen.dart';
import '../screens/my_profile_screen.dart';
import '../screens/search_people_screen.dart';
import '../widgets/app_widgets.dart';
import 'app_tab.dart';
import 'app_tab_bar.dart';
import 'current_event.dart';
import 'screen_load.dart';

/// The signed-in app: the five tabs and the bottom tab bar. Opened after log
/// in (with [me] from the login response) and at launch with a saved token
/// (loads `GET /api/me`; a 401 goes back to log in).
///
/// It owns who is signed in and the current event ([CurrentEvent]), and
/// gives both to each tab screen by constructor. Each tab is built the first
/// time it's opened and then kept, so switching tabs keeps its state.
class SignedInShell extends StatefulWidget {
  const SignedInShell({
    super.key,
    required this.api,
    this.me,
    this.initialTab = AppTab.home,
  });

  final ApiClient api;

  /// From the login response; null when restoring a session.
  final Me? me;
  final AppTab initialTab;

  @override
  State<SignedInShell> createState() => _SignedInShellState();
}

class _SignedInShellState extends State<SignedInShell>
    with ScreenLoad<SignedInShell> {
  Me? _me;
  String? _eventSlug;
  late AppTab _tab = widget.initialTab;
  late final _opened = <AppTab>{widget.initialTab};

  @override
  void initState() {
    super.initState();
    final me = widget.me;
    if (me != null) {
      _signedIn(me);
      loading = false;
    } else {
      runLoad(_loadMe);
    }
  }

  Future<void> _loadMe() async {
    final me = await widget.api.getMe();
    if (mounted) setState(() => _signedIn(me));
  }

  void _signedIn(Me me) {
    _me = me;
    _eventSlug = CurrentEvent.slugFor(me);
  }

  void _open(AppTab tab) => setState(() {
    _tab = tab;
    _opened.add(tab);
  });

  void _joined(String slug) => setState(() => _eventSlug = slug);

  void _profileChanged(PublicProfile profile) =>
      setState(() => _me = Me(profile: profile, events: _me!.events));

  @override
  Widget build(BuildContext context) {
    final me = _me;
    if (me == null) {
      final message = problem;
      return Scaffold(
        body: SafeArea(
          child: message != null
              ? ProblemView(message: message, onRetry: () => runLoad(_loadMe))
              : const LoadingView(label: 'Loading your account…'),
        ),
      );
    }
    return Scaffold(
      body: IndexedStack(
        index: _tab.index,
        children: [
          for (final tab in AppTab.values)
            _opened.contains(tab) ? _screen(tab, me) : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: AppTabBar(current: _tab, onChanged: _open),
    );
  }

  Widget _screen(AppTab tab, Me me) {
    final api = widget.api;
    final slug = _eventSlug;
    if (slug == null) {
      return switch (tab) {
        AppTab.home => JoinEventScreen(api: api, onJoined: _joined),
        AppTab.me => _myProfile(me, null),
        _ => SignedInPage(
          title: tab.label,
          body: NoEventView(onOpenHome: () => _open(AppTab.home)),
        ),
      };
    }
    return switch (tab) {
      AppTab.home => HomeScreen(
        key: ValueKey(slug),
        api: api,
        me: me,
        eventSlug: slug,
        onOpenTab: _open,
      ),
      AppTab.people => SearchPeopleScreen(
        key: ValueKey(slug),
        api: api,
        eventSlug: slug,
      ),
      AppTab.hacky => HackyChatScreen(
        key: ValueKey(slug),
        api: api,
        me: me,
        eventSlug: slug,
      ),
      AppTab.chats => ConversationsScreen(
        key: ValueKey(slug),
        api: api,
        eventSlug: slug,
      ),
      AppTab.me => _myProfile(me, slug),
    };
  }

  Widget _myProfile(Me me, String? slug) => MyProfileScreen(
    api: widget.api,
    me: me,
    eventSlug: slug,
    onProfileChanged: _profileChanged,
  );
}
