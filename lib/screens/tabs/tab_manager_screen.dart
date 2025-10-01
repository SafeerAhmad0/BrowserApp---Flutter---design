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
  String _formatUrl(String url) {
    String formatted = url;
    if (formatted.startsWith('https://')) {
      formatted = formatted.substring(8);
    } else if (formatted.startsWith('http://')) {
      formatted = formatted.substring(7);
    }
    if (formatted.startsWith('www.')) {
      formatted = formatted.substring(4);
    }
    // Limit length
    if (formatted.length > 40) {
      formatted = '${formatted.substring(0, 40)}...';
    }
    return formatted;
  }

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
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        widget.onTabSelected?.call(index);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header row
                            Row(
                              children: [
                                // Tab icon
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2196F3).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.language,
                                    color: Color(0xFF2196F3),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Title and URL
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tab.title.isEmpty ? 'Untitled' : tab.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        tab.url.isEmpty ? 'about:blank' : _formatUrl(tab.url),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Tab number badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '#${index + 1}',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Close button
                                IconButton(
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () {
                                    widget.onTabClosed?.call(index);
                                    setState(() {}); // Rebuild to show updated list
                                  },
                                  color: Colors.red.shade400,
                                  tooltip: 'Close Tab',
                                  iconSize: 22,
                                ),
                              ],
                            ),
                            // Preview placeholder
                            const SizedBox(height: 12),
                            Container(
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.web_outlined,
                                  size: 40,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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