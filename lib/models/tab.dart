import 'package:webview_flutter/webview_flutter.dart';

class BrowserTab {
  final String id;
  final String title;
  final String url;
  final WebViewController controller;

  BrowserTab({
    required this.id,
    required this.title,
    required this.url,
    required this.controller,
  });

  BrowserTab copyWith({
    String? id,
    String? title,
    String? url,
    WebViewController? controller,
  }) {
    return BrowserTab(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      controller: controller ?? this.controller,
    );
  }
}