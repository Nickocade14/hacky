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
import 'ask_hacky_button.dart';
import 'current_event.dart';
import 'screen_load.dart';
import 'shell_header.dart';
import 'shell_scope.dart';

/// The signed-in app: the header, the five pages and the Ask Hacky button,
/// laid out like the web on a phone (web/src/SignedInShell.tsx). Opened after
/// log in (with [me] from the login response) and at launch with a saved
/// token (loads `GET /api/me`; a 401 goes back to log in).
///
/// It lands on Hacky, or on Home (the events to join) before the user is in
/// an event. It owns who is signed in and the current event ([CurrentEvent]),
/// and gives both to each page by constructor. A page is built the first
/// time it's opened and then kept, so switching keeps its state. Chats is
/// built right away, because it tells the header when something is waiting.
class SignedInShell extends StatefulWidget {
  const SignedInShell({super.key, required this.api, this.me, this.initialTab});

  final ApiClient api;

  /// From the login response; null when restoring a session.
  final Me? me;

  /// Null opens Hacky, or Home before the user joins an event.
  final AppTab? initialTab;

  @override
  State<SignedInShell> createState() => _SignedInShellState();
}

class _SignedInShellState extends State<SignedInShell>
    with ScreenLoad<SignedInShell> {
  Me? _me;
  String? _eventSlug;
  AppTab _tab = AppTab.hacky;
  final _opened = <AppTab>{};

  /// Requests to answer plus unread messages, from Chats.
  int _waiting = 0;

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
    _tab =
        widget.initialTab ??
        (_eventSlug == null ? AppTab.home : AppTab.hacky);
    _opened.add(_tab);
    if (_eventSlug != null) _opened.add(AppTab.chats);
  }

  void _open(AppTab tab) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _tab = tab;
      _opened.add(tab);
    });
  }

  void _joined(String slug) {
    setState(() {
      _eventSlug = slug;
      _opened.add(AppTab.chats);
    });
    _refreshMe();
  }

  /// After joining, `Me.events` has the event: its name for the header and
  /// my role for Chats.
  Future<void> _refreshMe() async {
    try {
      final me = await widget.api.getMe();
      if (mounted) setState(() => _me = me);
    } catch (_) {
      // The header just keeps its fallback line until the next launch.
    }
  }

  void _profileChanged(PublicProfile profile) =>
      setState(() => _me = Me(profile: profile, events: _me!.events));

  void _waitingChanged(int waiting) {
    if (mounted && waiting != _waiting) setState(() => _waiting = waiting);
  }

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
    final slug = _eventSlug;
    final onHacky = _tab == AppTab.hacky;
    final compact = _tab == AppTab.chats;
    // The button steps aside for the keyboard, and where there's no Hacky yet.
    final typing = MediaQuery.viewInsetsOf(context).bottom > 0;
    final askHacky = !onHacky && slug != null && !typing;
    return Scaffold(
      appBar: ShellHeader(
        me: me,
        eventName: me.events
            .where((event) => event.slug == slug)
            .firstOrNull
            ?.name,
        current: _tab,
        waiting: _waiting,
        onOpen: _open,
      ),
      body: ShellScope(
        bottomClearance: askHacky ? 76 : 0,
        child: IndexedStack(
          index: _tab.index,
          children: [
            for (final tab in AppTab.values)
              _opened.contains(tab)
                  ? _screen(tab, me)
                  : const SizedBox.shrink(),
          ],
        ),
      ),
      floatingActionButton: askHacky
          ? AskHackyButton(
              key: ShellHeader.keyOf(AppTab.hacky),
              compact: compact,
              onPressed: () => _open(AppTab.hacky),
            )
          : null,
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
        onWaitingChanged: _waitingChanged,
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
