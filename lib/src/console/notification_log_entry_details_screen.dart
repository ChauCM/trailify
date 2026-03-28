import 'package:flutter/material.dart';
import 'package:logarte/logarte.dart';
import 'package:logarte/src/console/logarte_theme_wrapper.dart';
import 'package:logarte/src/console/network_log_entry_details_screen.dart';
import 'package:logarte/src/extensions/object_extensions.dart';
import 'package:logarte/src/extensions/string_extensions.dart';

class NotificationLogEntryDetailsScreen extends StatelessWidget {
  final NotificationLogarteEntry entry;
  final Logarte instance;

  const NotificationLogEntryDetailsScreen(
    this.entry, {
    Key? key,
    required this.instance,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LogarteThemeWrapper(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: Navigator.of(context).pop,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(
            entry.title ?? entry.topic ?? entry.eventType.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                instance.onShare?.call(entry.toString());
              },
            ),
            IconButton(
              icon: const Icon(Icons.copy_all),
              onPressed: () {
                entry.toString().copyToClipboard(context);
              },
            ),
            const SizedBox(width: 12.0),
          ],
        ),
        body: Scrollbar(
          child: ListView(
            children: [
              SelectableCopiableTile(
                title: 'EVENT TYPE',
                subtitle: entry.eventType.name.toUpperCase(),
              ),
              const Divider(height: 0.0),
              if (entry.title != null) ...[
                SelectableCopiableTile(
                  title: 'TITLE',
                  subtitle: entry.title!,
                ),
                const Divider(height: 0.0),
              ],
              if (entry.body != null) ...[
                SelectableCopiableTile(
                  title: 'BODY',
                  subtitle: entry.body!,
                ),
                const Divider(height: 0.0),
              ],
              if (entry.topic != null) ...[
                SelectableCopiableTile(
                  title: 'TOPIC',
                  subtitle: entry.topic!,
                ),
                const Divider(height: 0.0),
              ],
              if (entry.messageId != null) ...[
                SelectableCopiableTile(
                  title: 'MESSAGE ID',
                  subtitle: entry.messageId!,
                ),
                const Divider(height: 0.0),
              ],
              if (entry.source != null) ...[
                SelectableCopiableTile(
                  title: 'SOURCE',
                  subtitle: entry.source!,
                ),
                const Divider(height: 0.0),
              ],
              if (entry.data != null) ...[
                SelectableCopiableTile(
                  title: 'DATA',
                  subtitle: entry.data.prettyJson,
                ),
                const Divider(height: 0.0),
              ],
              SelectableCopiableTile(
                title: 'TIMESTAMP',
                subtitle: entry.date.toString(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
