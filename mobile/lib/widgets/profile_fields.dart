// The form fields of 08 My profile: labeled text fields, chip lists with add
// and remove, and single-choice chips. Errors show under each field.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../profile/profile_rules.dart';
import '../theme.dart';

const _bold = FontWeight.w700;

/// The bold label over a field.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.ink,
          fontSize: 12,
          fontWeight: _bold,
        ),
      ),
    );
  }
}

/// A small muted or red line under a field.
class FieldNote extends StatelessWidget {
  const FieldNote(this.text, {super.key, this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: error,
      child: Text(
        text,
        style: TextStyle(
          color: error ? AppColors.danger : AppColors.muted,
          fontSize: 12,
          height: 1.5,
        ),
      ),
    );
  }
}

/// A labeled text field like AuthField, that can be multi-line and shows an
/// [error] from the form under it. With [showCounter], it shows "n/max".
class ProfileTextField extends StatelessWidget {
  const ProfileTextField({
    super.key,
    required this.id,
    required this.label,
    required this.controller,
    required this.maxLength,
    this.placeholder,
    this.hint,
    this.error,
    this.lines = 1,
    this.showCounter = false,
    this.keyboardType,
    this.enabled = true,
  });

  /// Tests find the input with `Key(id)`.
  final String id;
  final String label;
  final TextEditingController controller;
  final int maxLength;
  final String? placeholder;
  final String? hint;
  final String? error;

  /// More than 1 makes a text area.
  final int lines;
  final bool showCounter;
  final TextInputType? keyboardType;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        FieldLabel(label),
        Semantics(
          label: label,
          child: TextField(
            key: Key(id),
            controller: controller,
            enabled: enabled,
            minLines: lines,
            maxLines: lines == 1 ? 1 : lines + 4,
            maxLength: showCounter ? maxLength : null,
            inputFormatters: [
              if (!showCounter) LengthLimitingTextInputFormatter(maxLength),
            ],
            keyboardType: lines == 1 ? keyboardType : TextInputType.multiline,
            autocorrect: keyboardType != TextInputType.url,
            style: const TextStyle(color: AppColors.ink, fontSize: 16),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: const TextStyle(color: AppColors.muted),
              errorText: error,
              errorMaxLines: 3,
              helperText: error == null ? hint : null,
              helperMaxLines: 3,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A list of short tags (skills, interests) as chips. Each chip has an ×
/// to remove it; "+ Add" opens a small field to add one.
class TagListEditor extends StatefulWidget {
  const TagListEditor({
    super.key,
    required this.id,
    required this.label,
    required this.tags,
    required this.onChanged,
    this.placeholder = 'Add one',
    this.error,
    this.enabled = true,
  });

  /// Tests find the add chip with `Key('$id-add')` and the field with
  /// `Key('$id-input')`.
  final String id;
  final String label;
  final List<String> tags;
  final ValueChanged<List<String>> onChanged;
  final String placeholder;

  /// From the form (e.g. the server said no).
  final String? error;
  final bool enabled;

  @override
  State<TagListEditor> createState() => _TagListEditorState();
}

class _TagListEditorState extends State<TagListEditor> {
  final _input = TextEditingController();
  bool _adding = false;
  String? _inputError;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add() {
    final problem = ProfileRules.newTag(_input.text, widget.tags);
    if (problem != null) {
      setState(() => _inputError = problem);
      return;
    }
    widget.onChanged([...widget.tags, _input.text.trim()]);
    _input.clear();
    setState(() => _inputError = null);
  }

  void _remove(String tag) =>
      widget.onChanged([for (final t in widget.tags) if (t != tag) t]);

  void _close() => setState(() {
    _adding = false;
    _inputError = null;
    _input.clear();
  });

  @override
  Widget build(BuildContext context) {
    final error = _inputError ?? widget.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        FieldLabel(widget.label),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final tag in widget.tags)
              InputChip(
                label: Text(tag),
                onDeleted: widget.enabled ? () => _remove(tag) : null,
                deleteButtonTooltipMessage: 'Remove $tag',
                backgroundColor: AppColors.hover,
                side: BorderSide.none,
                labelStyle: const TextStyle(
                  color: AppColors.action,
                  fontSize: 13,
                  fontWeight: _bold,
                ),
                deleteIconColor: AppColors.action,
                shape: const StadiumBorder(),
              ),
            if (!_adding)
              ActionChip(
                key: Key('${widget.id}-add'),
                label: const Text('+ Add'),
                tooltip: 'Add to ${widget.label}',
                onPressed: widget.enabled
                    ? () => setState(() => _adding = true)
                    : null,
                backgroundColor: AppColors.white,
                side: const BorderSide(color: AppColors.line),
                labelStyle: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 13,
                  fontWeight: _bold,
                ),
                shape: const StadiumBorder(),
              ),
          ],
        ),
        if (_adding) _addRow(),
        if (error != null) FieldNote(error, error: true),
      ],
    );
  }

  Widget _addRow() {
    return Row(
      spacing: 8,
      children: [
        Expanded(
          child: Semantics(
            label: 'Add to ${widget.label}',
            child: TextField(
              key: Key('${widget.id}-input'),
              controller: _input,
              autofocus: true,
              enabled: widget.enabled,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                LengthLimitingTextInputFormatter(ProfileRules.tagMax),
              ],
              onSubmitted: (_) => _input.text.trim().isEmpty ? _close() : _add(),
              style: const TextStyle(color: AppColors.ink, fontSize: 15),
              decoration: InputDecoration(
                isDense: true,
                hintText: widget.placeholder,
                hintStyle: const TextStyle(color: AppColors.muted),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),
        IconButton.filled(
          key: Key('${widget.id}-confirm'),
          tooltip: 'Add',
          onPressed: widget.enabled ? _add : null,
          icon: const Icon(Icons.add, size: 20),
        ),
        IconButton(
          tooltip: 'Done adding',
          onPressed: _close,
          icon: const Icon(Icons.close, size: 20, color: AppColors.muted),
        ),
      ],
    );
  }
}

/// One choice out of a few, as chips. Tapping the chosen one again clears
/// it, since these fields can be left unset.
class ChoicePicker<T> extends StatelessWidget {
  const ChoicePicker({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.error,
    this.enabled = true,
  });

  final String label;

  /// Each value and its label, in order.
  final List<(T, String)> options;
  final T? value;
  final ValueChanged<T?> onChanged;
  final String? error;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        FieldLabel(label),
        Semantics(
          label: label,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (option, text) in options)
                ChoiceChip(
                  label: Text(text),
                  selected: option == value,
                  showCheckmark: false,
                  onSelected: enabled
                      ? (selected) => onChanged(selected ? option : null)
                      : null,
                  selectedColor: AppColors.action,
                  backgroundColor: AppColors.white,
                  side: BorderSide(
                    color: option == value ? AppColors.action : AppColors.line,
                  ),
                  labelStyle: TextStyle(
                    color: option == value
                        ? AppColors.onAction
                        : AppColors.ink,
                    fontSize: 13,
                    fontWeight: _bold,
                  ),
                  shape: const StadiumBorder(),
                ),
            ],
          ),
        ),
        if (error != null) FieldNote(error!, error: true),
      ],
    );
  }
}
