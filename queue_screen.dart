import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import '../app.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final h = App.handler;
    return Scaffold(
      appBar: AppBar(title: const Text('Queue'), backgroundColor: Colors.transparent),
      body: StreamBuilder<List<MediaItem>>(
        stream: h.queue,
        builder: (_, qs) {
          final items = qs.data ?? const <MediaItem>[];
          if (items.isEmpty) return const Center(child: Text('Queue is empty'));
          return StreamBuilder<int?>(
            stream: h.player.currentIndexStream,
            builder: (_, cs) {
              final cur = cs.data;
              return ReorderableListView.builder(
                itemCount: items.length,
                onReorder: (o, n) {
                  if (n > o) n -= 1;
                  h.moveQueueItem(o, n);
                },
                itemBuilder: (_, i) {
                  final it = items[i];
                  return Dismissible(
                    key: ValueKey('${it.id}#$i'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                        color: const Color(0xFF5A1D1D),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete_outline)),
                    onDismissed: (_) => h.removeQueueItem(i),
                    child: ListTile(
                      key: ValueKey('t${it.id}#$i'),
                      selected: i == cur,
                      selectedColor: LColors.electric,
                      leading: Cover(path: it.artUri?.toFilePath(), size: 40, radius: 6),
                      title: Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(it.artist ?? '', maxLines: 1),
                      trailing: const Icon(Icons.drag_handle),
                      onTap: () => h.skipToQueueItem(i),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
