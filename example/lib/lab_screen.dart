import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hardware_triggers/hardware_triggers.dart';

import 'catalog_entry_code.dart';
import 'lab_provider.dart';
import 'lab_state.dart';

/// One screen: connected devices and the live log on one side, the
/// per-device summary you label and copy on the other. Stacks on a phone.
class LabScreen extends ConsumerWidget {
  const LabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(labProvider.notifier);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: notifier.onPointer,
      onPointerUp: notifier.onPointer,
      onPointerSignal: notifier.onPointer,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Trigger Lab'),
          actions: [
            IconButton(
              tooltip: 'Refresh connected devices',
              icon: const Icon(Icons.bluetooth_searching),
              onPressed: notifier.refreshConnected,
            ),
            IconButton(
              tooltip: 'Clear everything seen',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: notifier.clear,
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            if (wide) {
              return const Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _LeftColumn()),
                  VerticalDivider(width: 1),
                  Expanded(child: _SummaryColumn()),
                ],
              );
            }
            return const Column(
              children: [
                Expanded(child: _LeftColumn()),
                Divider(height: 1),
                Expanded(child: _SummaryColumn()),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LeftColumn extends StatelessWidget {
  const _LeftColumn();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _ConnectedDevices(),
      Divider(height: 1),
      Expanded(child: _LiveLog()),
    ],
  );
}

class _ConnectedDevices extends ConsumerWidget {
  const _ConnectedDevices();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(labProvider);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Connected key devices', style: theme.textTheme.titleMedium),
              const Spacer(),
              if (state.interceptSupported == false)
                Text(
                  'no native interception on this platform',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (state.connected.isEmpty)
            Text('none reported', style: theme.textTheme.bodySmall)
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final device in state.connected)
                  _DeviceChip(device: device),
              ],
            ),
        ],
      ),
    );
  }
}

class _DeviceChip extends StatelessWidget {
  const _DeviceChip({required this.device});

  final TriggerDevice device;

  @override
  Widget build(BuildContext context) {
    final entry = TriggerCatalog.lookup(device);
    final ids = device.hasIdentity
        ? ' ${device.vendorId!.toRadixString(16)}:${device.productId!.toRadixString(16)}'
        : '';
    return Chip(
      avatar: Icon(
        entry == null ? Icons.help_outline : Icons.verified_outlined,
        size: 18,
      ),
      label: Text(
        '${device.name} #${device.id}$ids'
        '${device.isExternal == false ? ' (built-in)' : ''}'
        '${entry == null ? '' : ' · ${entry.name}'}',
      ),
    );
  }
}

class _LiveLog extends ConsumerWidget {
  const _LiveLog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(labProvider.select((s) => s.log));
    final theme = Theme.of(context);
    if (log.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Pair a remote and press a button.\n'
            'Every key the window receives shows up here with its device.\n'
            'Home and Power never reach an app; a button that acts as a '
            'mouse shows up as a pointer line.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: log.length,
      itemBuilder: (context, i) {
        final line = log[i];
        final color = switch (line.kind) {
          LogKind.down => theme.colorScheme.primary,
          LogKind.up => theme.colorScheme.onSurfaceVariant,
          LogKind.pattern => theme.colorScheme.tertiary,
          LogKind.pointer => theme.colorScheme.secondary,
          LogKind.info => theme.colorScheme.outline,
        };
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 88,
                child: Text(
                  _clock(line.at),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  line.text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: line.kind == LogKind.pattern
                        ? FontWeight.w600
                        : null,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _clock(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(at.hour)}:${two(at.minute)}:${two(at.second)}'
        '.${(at.millisecond ~/ 10).toString().padLeft(2, '0')}';
  }
}

class _SummaryColumn extends ConsumerWidget {
  const _SummaryColumn();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(labProvider.select((s) => s.summaries));
    final theme = Theme.of(context);
    if (summaries.isEmpty) {
      return Center(
        child: Text(
          'Each device you press builds a Catalog Entry here.',
          style: theme.textTheme.bodyMedium,
        ),
      );
    }
    final ordered = summaries.values.toList()
      ..sort((a, b) => a.entryName.compareTo(b.entryName));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final summary in ordered) ...[
          _SummaryCard(summary: summary),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({required this.summary});

  final DeviceSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(labProvider.notifier);
    final swallowed = ref.watch(labProvider.select((s) => s.swallowed));
    final theme = Theme.of(context);
    final device = summary.device;
    final known = summary.catalogEntry;
    final rows = summary.buttons.values.toList()
      ..sort((a, b) => a.label.compareTo(b.label));

    return Card(
      key: ValueKey('summary-${summary.deviceKey}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              key: ValueKey('name-${summary.deviceKey}'),
              initialValue: summary.entryName,
              decoration: const InputDecoration(
                labelText: 'Entry name',
                helperText: 'How the catalog will call this Trigger',
              ),
              onChanged: (v) => notifier.setEntryName(summary.deviceKey, v),
            ),
            const SizedBox(height: 8),
            Text(
              device == null
                  ? 'No device info: Flutter key path or injected input.'
                  : 'Reports as "${device.name}", id ${device.id}'
                        '${device.hasIdentity ? ', vendor ${_hex(device.vendorId!)}, product ${_hex(device.productId!)}' : ', no vendor/product id'}'
                        '${switch (device.isExternal) {
                          true => ', external',
                          false => ', built-in',
                          null => '',
                        }}'
                        '${known == null ? '' : '. Already in the catalog as ${known.name}.'}',
              style: theme.textTheme.bodySmall,
            ),
            if (summary.pointerClicks > 0 || summary.pointerScrolls > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Pointer input seen: ${summary.pointerClicks} clicks, '
                  '${summary.pointerScrolls} scrolls. Not a key; goes into '
                  'the notes.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              Text('No keys yet.', style: theme.textTheme.bodySmall)
            else
              _ButtonTable(
                deviceKey: summary.deviceKey,
                rows: rows,
                swallowed: swallowed,
              ),
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey('notes-${summary.deviceKey}'),
              initialValue: summary.notes,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                helperText:
                    'Mode used, pairing hints, buttons no app can see',
              ),
              onChanged: (v) => notifier.setNotes(summary.deviceKey, v),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: const Icon(Icons.copy_all_outlined),
                label: const Text('Copy as catalog entry'),
                onPressed: () async {
                  final code = catalogEntryCode(summary);
                  await Clipboard.setData(ClipboardData(text: code));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Catalog entry for ${summary.entryName} copied',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _hex(int v) => '0x${v.toRadixString(16).padLeft(4, '0')}';
}

class _ButtonTable extends ConsumerWidget {
  const _ButtonTable({
    required this.deviceKey,
    required this.rows,
    required this.swallowed,
  });

  final String deviceKey;
  final List<ButtonRow> rows;
  final Set<LogicalKeyboardKey> swallowed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(labProvider.notifier);
    final theme = Theme.of(context);
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(2),
        2: IntrinsicColumnWidth(),
        3: IntrinsicColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            _head(theme, 'Label'),
            _head(theme, 'Key'),
            _head(theme, 'Reliable: 1 · 2 · 3 · hold'),
            _head(theme, 'Swallow'),
          ],
        ),
        for (final row in rows)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextFormField(
                  key: ValueKey('label-$deviceKey-${row.key.keyId}'),
                  initialValue: row.label,
                  decoration: const InputDecoration(isDense: true),
                  onChanged: (v) => notifier.setLabel(deviceKey, row.key, v),
                ),
              ),
              Text(
                '${keyName(row.key)}'
                '${row.code == null ? '' : ' · code ${row.code}'}\n'
                '${row.presses} ${row.presses == 1 ? 'press' : 'presses'}'
                '${row.longestHold == null ? '' : ', longest hold ${row.longestHold!.inMilliseconds} ms'}',
                style: theme.textTheme.bodySmall,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final kind in PressKind.values)
                    Checkbox(
                      value: row.reliable.contains(kind),
                      onChanged: (v) => notifier.setReliable(
                        deviceKey,
                        row.key,
                        kind,
                        v ?? false,
                      ),
                    ),
                ],
              ),
              Switch(
                value: swallowed.contains(row.key),
                onChanged: (v) => notifier.setSwallowed(row.key, v),
              ),
            ],
          ),
      ],
    );
  }

  static Widget _head(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(text, style: theme.textTheme.labelMedium),
  );
}
