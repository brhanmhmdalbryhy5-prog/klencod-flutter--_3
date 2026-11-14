import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayService {
  static final OverlayService _instance = OverlayService._internal();
  factory OverlayService() => _instance;
  OverlayService._internal();

  bool _isPermissionGranted = false;

  Future<bool> ensurePermission() async {
    if (_isPermissionGranted) return true;
    bool granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!granted) {
      granted = await FlutterOverlayWindow.requestPermission() ?? false;
    }
    _isPermissionGranted = granted;
    return granted;
  }

  Future<void> showOverlay({String title = 'جاري المعالجة...'}) async {
    if (!await ensurePermission()) return;
    await FlutterOverlayWindow.showOverlay(
      height: 160,
      width: WindowSize.matchParent,
      alignment: OverlayAlignment.topCenter, // ✅ تم الإصلاح
      enableDrag: true,
      overlayTitle: title,
    );
  }

  Future<void> closeOverlay() async {
    await FlutterOverlayWindow.closeOverlay();
  }

  Future<void> updateProgress({
    required String title,
    required String status,
    required double progress,
  }) async {
    await FlutterOverlayWindow.shareData({
      'title': title,
      'status': status,
      'progress': progress,
    });
  }
}