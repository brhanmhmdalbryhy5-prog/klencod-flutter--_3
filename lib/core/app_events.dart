import 'dart:async';

/// ناقل الأحداث المركزي — أي ملف في التطبيق يمكنه إطلاق حدث
/// والشخصية تسمعه وتتفاعل تلقائياً
class AppEvents {
  AppEvents._();

  static final StreamController<String> _controller =
      StreamController<String>.broadcast();

  static Stream<String> get stream => _controller.stream;

  /// أطلق حدثاً (يستدعيه أي مكان في التطبيق)
  static void fire(String event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  static void dispose() {
    _controller.close();
  }
}