import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayService {
  static final OverlayService _instance = OverlayService._internal();
  factory OverlayService() => _instance;
  OverlayService._internal();

  bool _isPermissionGranted = false;

  Future<bool> ensurePermission() async {
    if (_isPermissionGranted) return true;
    try {
      bool granted = await FlutterOverlayWindow.isPermissionGranted();
      if (!granted) {
        granted = await FlutterOverlayWindow.requestPermission() ?? false;
      }
      _isPermissionGranted = granted;
      return granted;
    } catch (_) {
      return false;
    }
  }

  /// إرجاع bool لمعرفة ما إذا نجح فتح النافذة أم لا
  Future<bool> showOverlay({String title = 'جاري المعالجة...'}) async {
    if (!await ensurePermission()) return false;
    try {
      await FlutterOverlayWindow.showOverlay(
        height: 160,
        width: WindowSize.matchParent,
        alignment: OverlayAlignment.topCenter,
        enableDrag: true,
        overlayTitle: title,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> closeOverlay() async {
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (_) {}
  }

  Future<void> updateProgress({
    required String title,
    required String status,
    required double progress,
  }) async {
    try {
      await FlutterOverlayWindow.shareData({
        'title': title,
        'status': status,
        'progress': progress,
      });
    } catch (_) {}
  }
}