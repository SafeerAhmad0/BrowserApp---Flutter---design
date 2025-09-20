import 'package:flutter/material.dart';
import '../../models/tab.dart';

class TabManagerScreen extends StatefulWidget {
  final List<BrowserTab> tabs;
  final Function(int)? onTabSelected;
  final Function(int)? onTabClosed;
  final VoidCallback? onNewTab;

  const TabManagerScreen({
    super.key,
    required this.tabs,
    this.onTabSelected,
    this.onTabClosed,
    this.onNewTab,
  });

  @override
  State<TabManagerScreen> createState() => _TabManagerScreenState();
}

class _TabManagerScreenState extends State<TabManagerScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tabs (${widget.tabs.length})'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              widget.onNewTab?.call();
              Navigator.pop(context);
            },
            tooltip: 'New Tab',
          ),
        ],
      ),
      body: widget.tabs.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.tab_outlined,
                    size: 80,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No tabs open',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap + to open a new tab',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.tabs.length,
              itemBuilder: (context, index) {
                final BrowserTab tab = widget.tabs[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    title: Text(
                      tab.title.isEmpty ? 'Untitled' : tab.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          tab.url.isEmpty ? 'about:blank' : tab.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey[300]!,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.web,
                              size: 32,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.tab,
                        color: Color(0xFF2196F3),
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            widget.onTabClosed?.call(index);
                            Navigator.pop(context);
                          },
                          color: Colors.red,
                          tooltip: 'Close Tab',
                        ),
                      ],
                    ),
                    onTap: () {
                      widget.onTabSelected?.call(index);
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          widget.onNewTab?.call();
          Navigator.pop(context);
        },
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Tab'),
      ),
    );
  }
}