import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/custom_list_provider.dart';

/// F-02: Screen for creating, viewing, renaming, and deleting custom word lists.
///
/// Accessible from ProfileScreen → Custom Lists tile.
class CustomListScreen extends ConsumerWidget {
  const CustomListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(customListsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Word Lists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New list',
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ],
      ),
      body: listsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (lists) {
          if (lists.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.list_alt_outlined,
                      size: 64, color: Theme.of(context).colorScheme.outlineVariant),
                  const SizedBox(height: 16),
                  const Text('No lists yet'),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _showCreateDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Create your first list'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: lists.length,
            itemBuilder: (context, i) {
              final list = lists[i];
              return ListTile(
                title: Text(list.name),
                subtitle: Text(
                    '${list.words.length} word${list.words.length == 1 ? '' : 's'}'),
                leading: const Icon(Icons.list),
                trailing: PopupMenuButton<_Action>(
                  onSelected: (action) => _handleAction(context, ref, list, action),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: _Action.rename, child: Text('Rename')),
                    PopupMenuItem(
                        value: _Action.delete, child: Text('Delete')),
                  ],
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _WordListDetailScreen(list: list),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Word List'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'List name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(customListsProvider.notifier).create(name);
    }
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    CustomWordList list,
    _Action action,
  ) async {
    switch (action) {
      case _Action.rename:
        final controller = TextEditingController(text: list.name);
        final newName = await showDialog<String>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Rename List'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(context, controller.text.trim()),
                child: const Text('Rename'),
              ),
            ],
          ),
        );
        if (newName != null && newName.isNotEmpty) {
          await ref.read(customListsProvider.notifier).rename(list.id, newName);
        }

      case _Action.delete:
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete List'),
            content: Text('Delete "${list.name}"? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.error),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirm == true) {
          await ref.read(customListsProvider.notifier).delete(list.id);
        }
    }
  }
}

enum _Action { rename, delete }

/// Detail screen showing words in a list with ability to remove them.
class _WordListDetailScreen extends ConsumerWidget {
  final CustomWordList list;
  const _WordListDetailScreen({required this.list});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch live updates so additions/removals refresh automatically.
    final listsAsync = ref.watch(customListsProvider);
    final liveList = listsAsync.valueOrNull?.firstWhere(
      (l) => l.id == list.id,
      orElse: () => list,
    );
    final words = liveList?.words ?? list.words;

    return Scaffold(
      appBar: AppBar(title: Text(list.name)),
      body: words.isEmpty
          ? const Center(child: Text('No words yet. Add words from game results.'))
          : ListView.builder(
              itemCount: words.length,
              itemBuilder: (context, i) {
                final word = words[i];
                return ListTile(
                  title: Text(word),
                  leading: const Icon(Icons.text_fields),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => ref
                        .read(customListsProvider.notifier)
                        .removeWord(list.id, word),
                  ),
                );
              },
            ),
    );
  }
}
