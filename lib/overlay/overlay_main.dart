import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

// نقطة الدخول للطبقة العائمة
@pragma("vm:entry-point")
void overlayMain() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverlayWidget(),
    ),
  );
}

class OverlayWidget extends StatefulWidget {
  const OverlayWidget({super.key});

  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> {
  String _title = 'جاري المعالجة...';
  String _status = 'تهيئة...';
  double _progress = 0.0;
  StreamSubscription? _dataSubscription;

  @override
  void initState() {
    super.initState();
    // الاستماع للبيانات القادمة من التطبيق الرئيسي
    _dataSubscription = FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is Map) {
        setState(() {
          _title = event['title'] ?? _title;
          _status = event['status'] ?? _status;
          _progress = (event['progress'] as num?)?.toDouble() ?? _progress;
        });
      }
    });
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1F28).withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.cyan.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_download, color: Colors.cyan, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _status,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 8,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.cyan),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_progress * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}