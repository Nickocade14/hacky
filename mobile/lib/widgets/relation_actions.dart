import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/models/auth.dart';
import '../api/models/people.dart';
import '../api/models/requests.dart';
import '../auth/submit_action.dart';
import '../people/person_labels.dart';
import '../theme.dart';
import 'auth_widgets.dart';
import 'connect_sheet.dart';

/// The button on 07 that [Relation.state] decides: Connect · Request sent ·
/// Accept / Not now · Message → 11. Each action shows its busy state, its
/// error and a short success note.
class RelationActions extends StatefulWidget {
  const RelationActions({
    super.key,
    required this.api,
    required this.eventSlug,
    required this.person,
    required this.relation,
    required this.onChanged,
    required this.onMessage,
  });

  static const connectKey = Key('person-connect');
  static const sentKey = Key('person-sent');
  static const acceptKey = Key('person-accept');
  static const notNowKey = Key('person-not-now');
  static const messageKey = Key('person-message');

  final ApiClient api;
  final String eventSlug;
  final PublicProfile person;
  final Relation relation;

  /// Where I stand with them after an action.
  final ValueChanged<Relation> onChanged;

  /// Opens the DM (11) with this conversation id.
  final ValueChanged<String> onMessage;

  @override
  State<RelationActions> createState() => _RelationActionsState();
}

class _RelationActionsState extends State<RelationActions>
    with SubmitAction<RelationActions> {
  /// What the last action did, in green.
  String? _note;

  /// "Not now" was tapped: the request stays, the button goes.
  bool _hidden = false;

  /// Which of Accept / Not now is running, for its label.
  bool _accepting = false;

  String get _first => PersonLabels.firstName(widget.person.name);

  Future<void> _connect() async {
    final result = await ConnectSheet.show(
      context,
      api: widget.api,
      eventSlug: widget.eventSlug,
      person: widget.person,
    );
    if (result == null || !mounted) return;
    final request = result.request;
    final accepted = request.status == ConnectionStatus.accepted;
    setState(
      () => _note = accepted
          ? '$_first had already asked you, so you’re connected. Say hi!'
          : 'Request sent. You’ll get a chat when $_first accepts.',
    );
    widget.onChanged(
      Relation(
        state: accepted ? RelationState.accepted : RelationState.outgoing,
        requestId: request.id,
        conversationId: request.conversationId,
      ),
    );
  }

  Future<void> _accept(String requestId) async {
    setState(() {
      _accepting = true;
      _note = null;
    });
    await runAction(() async {
      final result = await widget.api.acceptRequest(requestId);
      if (!mounted) return;
      setState(() => _note = 'You and $_first are connected. Say hi!');
      widget.onChanged(
        Relation(
          state: RelationState.accepted,
          requestId: result.request.id,
          conversationId: result.request.conversationId,
        ),
      );
    });
  }

  Future<void> _notNow(String requestId) async {
    setState(() {
      _accepting = false;
      _note = null;
    });
    await runAction(() async {
      await widget.api.hideRequest(requestId);
      if (!mounted) return;
      setState(() {
        _hidden = true;
        _note = 'Hidden. You can still accept it from Requests.';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final note = _note;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        ..._buttons(),
        if (error != null) Notice(error!, error: true),
        if (note != null) Notice(note),
      ],
    );
  }

  List<Widget> _buttons() {
    final relation = widget.relation;
    final requestId = relation.requestId;
    final conversationId = relation.conversationId;
    return switch (relation.state) {
      RelationState.none => [
        FilledButton(
          key: RelationActions.connectKey,
          onPressed: _connect,
          style: _wide,
          child: Text('Connect with $_first'),
        ),
      ],
      RelationState.outgoing => [
        FilledButton.icon(
          key: RelationActions.sentKey,
          onPressed: null,
          style: _wide,
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Request sent'),
        ),
        if (_note == null) _Muted('Waiting for $_first to accept.'),
      ],
      RelationState.incoming => [
        _Muted('$_first wants to connect with you.'),
        Row(
          spacing: 12,
          children: [
            Expanded(
              child: FilledButton(
                key: RelationActions.acceptKey,
                onPressed: busy || requestId == null
                    ? null
                    : () => _accept(requestId),
                style: _wide,
                child: Text(busy && _accepting ? 'Accepting…' : 'Accept'),
              ),
            ),
            if (!_hidden)
              Expanded(
                child: SecondaryButton(
                  key: RelationActions.notNowKey,
                  label: busy && !_accepting ? 'Hiding…' : 'Not now',
                  onPressed: busy || requestId == null
                      ? null
                      : () => _notNow(requestId),
                ),
              ),
          ],
        ),
      ],
      RelationState.accepted => [
        FilledButton.icon(
          key: RelationActions.messageKey,
          onPressed: conversationId == null
              ? null
              : () => widget.onMessage(conversationId),
          style: _wide,
          icon: const Icon(Icons.chat_bubble_outline, size: 18),
          label: Text('Message $_first'),
        ),
      ],
    };
  }

  static final _wide = FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(49),
  );
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.muted, fontSize: 13),
    );
  }
}
