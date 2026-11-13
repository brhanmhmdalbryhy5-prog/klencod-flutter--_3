Widget _randomPickerButton() {
  return Container(
    margin: const EdgeInsets.only(bottom: 20),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(colors: [Color(0xFF247BA0), Color(0xFF27866F), Color(0xFF202431)], begin: Alignment.topRight, end: Alignment.bottomLeft),
      border: Border.all(color: Colors.cyan.withOpacity(0.6), width: 1.5),
      boxShadow: [BoxShadow(color: Colors.cyan.withOpacity(0.5), blurRadius: 25, spreadRadius: 5)],
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.lightImpact();
          // 🔥 الانتقال لشاشة القرعة الجديدة
          Navigator.push(context, MaterialPageRoute(builder: (_) => const RandomPickerScreen()));
        },
        child: const Padding(
          padding: EdgeInsets.all(17),
          child: Row(
            children: [
              CircleAvatar(radius: 25, backgroundColor: Colors.white24, child: Icon(Icons.casino, color: Colors.white, size: 29)),
              SizedBox(width: 13),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('قرعة الأنمي 🎲', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)), SizedBox(height: 5), Text('ماذا أشاهد الآن؟', style: TextStyle(color: Colors.white70, fontSize: 12))])),
              Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    ),
  );
}