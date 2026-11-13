import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../models/anime.dart';
import '../services/storage_service.dart';
import 'anime_details_screen.dart';

class RandomPickerScreen extends StatefulWidget {
  const RandomPickerScreen({super.key});

  @override
  State<RandomPickerScreen> createState() => _RandomPickerScreenState();
}

class _RandomPickerScreenState extends State<RandomPickerScreen> {
  final StorageService storage = StorageService();
  List<Anime> watchingAnimes = [];
  List<Anime> topThree = [];
  bool isLoading = true;
  bool isRolling = false;

  @override
  void initState() {
    super.initState();
    _loadAnimes();
  }

  Future<void> _loadAnimes() async {
    final allAnimes = await storage.loadAnimes();
    if (!mounted) return;
    setState(() {
      watchingAnimes = allAnimes.where((a) => a.status == 'أتابعه' && a.parentId == null).toList();
      isLoading = false;
    });
  }

  void _roll() {
    if (watchingAnimes.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تحتاج إلى 3 أنميات على الأقل في قائمة "أتابعه" لعمل قرعة.')));
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() {
      isRolling = true;
      topThree.clear();
    });

    // محاكاة التحميل لجعل الحركة تبدو ذكية
    Future.delayed(const Duration(milliseconds: 1500), () {
      final shuffled = List<Anime>.from(watchingAnimes)..shuffle(Random());
      if (!mounted) return;
      setState(() {
        topThree = shuffled.take(3).toList();
        isRolling = false;
      });
      HapticFeedback.heavyImpact();
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = primaryColorNotifier.value;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('قرعة الأوتاكو 🎲', style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: 20),
                // 🎯 تصميم زر القرعة
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [primaryColor.withOpacity(0.2), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: primaryColor.withOpacity(0.5)),
                    boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.2), blurRadius: 30, spreadRadius: 5)],
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.auto_awesome, color: primaryColor, size: 50),
                      const SizedBox(height: 15),
                      Text('ماذا أشاهد الآن؟', style: GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 10),
                      Text('اضغط على الزر لاختيار 3 أنميات لك بالترتيب', style: GoogleFonts.cairo(fontSize: 14, color: Colors.white60)),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: isRolling ? null : _roll,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          elevation: 10,
                          shadowColor: primaryColor.withOpacity(0.5),
                        ),
                        child: isRolling
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text('اسحب القرعة', style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                const Divider(color: Colors.white12),
                const SizedBox(height: 10),

                // 🎯 عرض النتائج
                Expanded(
                  child: topThree.isEmpty
                      ? Center(child: Text('النتائج ستظهر هنا...', style: GoogleFonts.cairo(color: Colors.white38, fontSize: 18)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: topThree.length,
                          itemBuilder: (context, index) {
                            final anime = topThree[index];
                            final isFirst = index == 0;
                            
                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: Duration(milliseconds: 500 + (index * 200)),
                              curve: Curves.easeOutBack,
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: Opacity(
                                    opacity: value.clamp(0.0, 1.0),
                                    child: child,
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 15),
                                decoration: BoxDecoration(
                                  color: isFirst ? primaryColor.withOpacity(0.2) : const Color(0xFF1B1F28),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: isFirst ? primaryColor : Colors.white12, width: isFirst ? 2 : 1),
                                  boxShadow: isFirst ? [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 20, spreadRadius: 5)] : [],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(15),
                                  leading: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: 30,
                                        backgroundColor: isFirst ? primaryColor : Colors.black26,
                                        child: Text('${index + 1}', style: GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ),
                                      if (isFirst) const Positioned(bottom: 0, right: 0, child: Icon(Icons.star, color: Color(0xFFFFC857), size: 20)),
                                    ],
                                  ),
                                  title: Text(
                                    anime.title,
                                    style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold, color: isFirst ? const Color(0xFFFFD700) : Colors.white),
                                  ),
                                  subtitle: Text(
                                    isFirst ? 'شاهد هذا أولاً!' : 'ثم شاهد هذا',
                                    style: GoogleFonts.cairo(color: isFirst ? primaryColor : Colors.white54),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.arrow_forward_ios, color: Colors.white70),
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => AnimeDetailsScreen(anime: anime)));
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}