import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ImageService {
  static final Map<String, String> _cache = {};

  /// تحميل صورة من الإنترنت وحفظها محلياً (تجنب التكرار تلقائياً).
  static Future<String?> downloadImage(String? url, {String prefix = 'img'}) async {
    if (url == null || url.isEmpty) return null;
    
    // التحقق من الكاش الداخلي
    if (_cache.containsKey(url)) {
      final cached = _cache[url]!;
      if (await File(cached).exists()) return cached;
    }

    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final folder = Directory('${directory.path}/anime_images');
        if (!await folder.exists()) await folder.create(recursive: true);
        
        // اسم الملف مبني على hash الرابط لمنع التكرار
        final filename = '${prefix}_${url.hashCode.abs()}.jpg';
        final file = File('${folder.path}/$filename');
        
        if (!await file.exists()) {
          await file.writeAsBytes(response.bodyBytes);
        }
        
        _cache[url] = file.path;
        return file.path;
      }
    } catch (_) {}
    return null;
  }

  static void clearCache() => _cache.clear();
}