import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/messaging_service.dart';

class MessageImage extends StatefulWidget {
  const MessageImage(
      {super.key, required this.service, required this.attachment});
  final MessagingService service;
  final Map<String, dynamic> attachment;

  @override
  State<MessageImage> createState() => _MessageImageState();
}

class _MessageImageState extends State<MessageImage> {
  late Future<String> url = _load();
  bool originalFallback = false;

  Future<String> _load() =>
      widget.service.signedImageUrl(widget.attachment['storage_path'] as String,
          thumbnail: !originalFallback);

  @override
  void didUpdateWidget(covariant MessageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment['storage_path'] !=
        widget.attachment['storage_path']) {
      originalFallback = false;
      url = _load();
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Open image ${widget.attachment['file_name']}',
        child: InkWell(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => MessageImageViewer(
                      service: widget.service, attachment: widget.attachment))),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280, maxHeight: 240),
              child: FutureBuilder<String>(
                  future: url,
                  builder: (_, snapshot) {
                    if (snapshot.hasError) {
                      return const SizedBox(
                          width: 180,
                          height: 120,
                          child: Center(
                              child: Text('Image unavailable. Tap to open')));
                    }
                    if (!snapshot.hasData) {
                      return const SizedBox(
                          width: 180,
                          height: 120,
                          child: Center(child: CircularProgressIndicator()));
                    }
                    return Image.network(snapshot.data!,
                        fit: BoxFit.contain,
                        cacheWidth: 480,
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : const SizedBox(
                                width: 180,
                                height: 120,
                                child:
                                    Center(child: CircularProgressIndicator())),
                        errorBuilder: (_, __, ___) {
                          if (!originalFallback) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted && !originalFallback) {
                                setState(() {
                                  originalFallback = true;
                                  url = _load();
                                });
                              }
                            });
                            return const SizedBox(
                                width: 180,
                                height: 120,
                                child:
                                    Center(child: CircularProgressIndicator()));
                          }
                          return const SizedBox(
                              width: 180,
                              height: 120,
                              child: Center(
                                  child: Text(
                                      'Could not load image. Tap to open')));
                        });
                  }),
            ),
          ),
        ),
      );
}

class MessageImageViewer extends StatefulWidget {
  const MessageImageViewer(
      {super.key, required this.service, required this.attachment});
  final MessagingService service;
  final Map<String, dynamic> attachment;

  @override
  State<MessageImageViewer> createState() => _MessageImageViewerState();
}

class _MessageImageViewerState extends State<MessageImageViewer> {
  late Future<String> url = widget.service.signedImageUrl(
      widget.attachment['storage_path'] as String,
      thumbnail: false);
  String? saveError;

  void _reload() => setState(() => url = widget.service.signedImageUrl(
      widget.attachment['storage_path'] as String,
      thumbnail: false));

  Future<void> _save() async {
    try {
      await widget.service.openAttachment(widget.attachment);
    } catch (e) {
      if (mounted) setState(() => saveError = 'Could not save image: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: IconButton(
              tooltip: 'Close image',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close)),
          title: Text('${widget.attachment['file_name']}',
              overflow: TextOverflow.ellipsis),
          actions: [
            if (!kIsWeb)
              IconButton(
                  tooltip: 'Save or open image',
                  onPressed: _save,
                  icon: const Icon(Icons.download_outlined)),
          ]),
      body: SafeArea(
          child: Column(children: [
        Expanded(
            child: FutureBuilder<String>(
                future: url,
                builder: (_, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                        child: TextButton(
                            onPressed: _reload,
                            child: const Text('Could not load image. Retry')));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 5,
                      child: Center(
                          child: Image.network(snapshot.data!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => TextButton(
                                  onPressed: _reload,
                                  child: const Text(
                                      'Could not load image. Retry')))));
                })),
        if (saveError != null)
          Text(saveError!, style: const TextStyle(color: Colors.white)),
      ])));
}
