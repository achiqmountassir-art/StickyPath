import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../progress/challenge_store.dart';
import '../progress/custom_task.dart';
import '../theme/app_colors.dart';

/// Compact create/edit sheet for custom challenge-day tasks.
Future<bool> showTaskFormSheet({
  required BuildContext context,
  required ChallengeStore store,
  CustomTask? existing,
  int? initialDayNumber,
}) async {
  final challenge = store.active;
  if (challenge == null) return false;

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF15161B),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return _TaskFormBody(
        store: store,
        challenge: challenge,
        existing: existing,
        initialDayNumber: initialDayNumber ??
            existing?.dayNumber ??
            challenge.homeCurrentDay,
      );
    },
  );
  return result ?? false;
}

class _TaskFormBody extends StatefulWidget {
  const _TaskFormBody({
    required this.store,
    required this.challenge,
    required this.initialDayNumber,
    this.existing,
  });

  final ChallengeStore store;
  final ActiveChallenge challenge;
  final CustomTask? existing;
  final int initialDayNumber;

  @override
  State<_TaskFormBody> createState() => _TaskFormBodyState();
}

class _TaskFormBodyState extends State<_TaskFormBody> {
  late final TextEditingController _title;
  late int _dayNumber;
  TimeOfDay? _reminder;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title ?? '');
    _dayNumber = widget.initialDayNumber.clamp(1, widget.challenge.totalDays);
    final minutes = existing?.reminderMinutes;
    if (minutes != null) {
      _reminder = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickReminder() async {
    HapticFeedback.selectionClick();
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminder ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.pink,
              surface: Color(0xFF15161B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _reminder = picked);
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Enter a task title');
      return;
    }
    if (_dayNumber < 1 || _dayNumber > widget.challenge.totalDays) {
      setState(() => _error = 'Pick a day in this challenge');
      return;
    }

    setState(() {
      _error = null;
      _saving = true;
    });

    final minutes = _reminder == null
        ? null
        : _reminder!.hour * 60 + _reminder!.minute;
    final existing = widget.existing;
    final ok = existing == null
        ? await widget.store.addCustomTask(
              title: title,
              dayNumber: _dayNumber,
              reminderMinutes: minutes,
            ) !=
            null
        : await widget.store.updateCustomTask(
            existing.id,
            title: title,
            dayNumber: _dayNumber,
            reminderMinutes: minutes,
            clearReminder: minutes == null,
          );

    if (!mounted) return;
    if (!ok) {
      setState(() {
        _saving = false;
        _error = 'Could not save this task';
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final total = widget.challenge.totalDays;
    final dayItems = [
      for (var label = 1; label <= total; label++)
        (
          dayNumber: total - label + 1,
          label: label,
        ),
    ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 18, 24, 20 + inset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null ? 'New task' : 'Edit task',
              style: AppFonts.sansStyle(size: 18, weight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _title,
              autofocus: widget.existing == null,
              textInputAction: TextInputAction.done,
              style: AppFonts.sansStyle(size: 16, weight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Task title',
                hintStyle: AppFonts.sansStyle(
                  size: 16,
                  color: AppColors.mutedWhite,
                ),
                filled: true,
                fillColor: const Color(0xFF1A1B21),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF343A48)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF343A48)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: AppColors.pink.withValues(alpha: 0.85),
                  ),
                ),
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              // ignore: deprecated_member_use
              value: _dayNumber,
              dropdownColor: const Color(0xFF1A1B21),
              decoration: InputDecoration(
                labelText: 'Challenge day',
                labelStyle: AppFonts.sansStyle(
                  size: 13,
                  color: AppColors.mutedWhite,
                ),
                filled: true,
                fillColor: const Color(0xFF1A1B21),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF343A48)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF343A48)),
                ),
              ),
              items: [
                for (final item in dayItems)
                  DropdownMenuItem(
                    value: item.dayNumber,
                    child: Text(
                      'Day ${item.label} of $total',
                      style: AppFonts.sansStyle(size: 15),
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _dayNumber = value);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.notifications_outlined,
                color: _reminder == null
                    ? AppColors.mutedWhite
                    : AppColors.pink,
              ),
              title: Text(
                _reminder == null
                    ? 'Add reminder (optional)'
                    : 'Reminder ${_reminder!.format(context)}',
                style: AppFonts.sansStyle(size: 15, weight: FontWeight.w600),
              ),
              trailing: _reminder == null
                  ? null
                  : IconButton(
                      tooltip: 'Remove reminder',
                      onPressed: () => setState(() => _reminder = null),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
              onTap: _pickReminder,
            ),
            Text(
              'Does not repeat',
              style: AppFonts.sansStyle(
                size: 13,
                color: AppColors.mutedWhite,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppFonts.sansStyle(size: 13, color: AppColors.pink),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.pink,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  widget.existing == null ? 'Save task' : 'Update task',
                  style: AppFonts.sansStyle(size: 16, weight: FontWeight.w700),
                ),
              ),
            ),
            if (widget.existing != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          await widget.store.deleteCustomTask(
                            widget.existing!.id,
                          );
                          if (context.mounted) {
                            Navigator.pop(context, true);
                          }
                        },
                  child: Text(
                    'Delete task',
                    style: AppFonts.sansStyle(
                      size: 14,
                      weight: FontWeight.w600,
                      color: AppColors.mutedWhite,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
