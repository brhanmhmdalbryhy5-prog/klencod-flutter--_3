void _scrollToLatestAchievement() {
  // حساب آخر إنجاز مفتوح (كل 10 أنميات = إنجاز جديد)
  int unlockedIndex = (animes.length / 10).floor();
  if (unlockedIndex > 99) unlockedIndex = 99; // الحد الأقصى 100 إنجاز
  if (unlockedIndex < 0) unlockedIndex = 0;

  // كل إنجاز عرضه 90 + مسافة 10 = 100 بكسل
  double offset = (unlockedIndex * 100.0) - 150.0; // نطرح 150 لنجعله يظهر في منتصف الشاشة تقريباً
  if (offset < 0) offset = 0;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_achievementsController.hasClients) {
      double maxScroll = _achievementsController.position.maxScrollExtent;
      _achievementsController.animateTo(
        offset > maxScroll ? maxScroll : offset,
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeInOut,
      );
    }
  });
}