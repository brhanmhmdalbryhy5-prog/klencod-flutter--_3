import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../main.dart';
import '../services/backup_service.dart';

class BackupProgressScreen extends StatefulWidget {
  final bool isRestore;
  const BackupProgressScreen({super.key, required this.isRestore});

  @override
  State<BackupProgressScreen> createState() => _BackupProgressScreenState();
}

class _BackupProgressScreenState extends State<BackupProgressScreen> {
  final BackupService _service = BackupService();
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (_started) return;
    _started = true;
    if (widget.isRestore) {
      await _service.restoreBackup();
    } else {
      await _service.createBackup();
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}س ${d.inMinutes % 60}د';
    if (d.inMinutes > 0) return '${d.inMinutes}د ${d.inSeconds % 60}ث';
    return '${d.inSeconds}ث';
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = primaryColorNotifier.value;

    return ValueListenableBuilder<BackupProgress?>(
      valueListenable: _service.progress,
      builder: (context, progress, _) {
        if (progress == null) {
          return Scaffold(
            backgroundColor: const Color(0xFF111318),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return PopScope(
          canPop: progress.isDone,
          onPopInvoked: (didPop) {
            if (!didPop && !progress.isDone) {
              _showCancelDialog();
            }
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF111318),
            appBar: AppBar(
              backgroundColor: const Color(0xFF111318),
              title: Text(widget.isRestore ? 'استعادة النسخة' : 'إنشاء النسخة'),
              centerTitle: true,
              leading: progress.isDone
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _showCancelDialog,
                    ),
              automaticallyImplyLeading: progress.isDone,
            ),
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: progress.isDone
                    ? _buildDoneView(progress, primaryColor)
                    : _buildProgressView(progress, primaryColor),
              ),
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════
  // واجهة التقدم
  // ══════════════════════════════════════════════════════════════
  Widget _buildProgressView(BackupProgress progress, Color primaryColor) {
    return Column(
      children: [
        const Spacer(),
        // دائرة التقدم
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 220,
              height: 220,
              child: CircularProgressIndicator(
                value: progress.totalFiles == 0 ? null : progress.percentage,
                strokeWidth: 14,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            ),
            Column(
              children: [
                Icon(
                  widget.isRestore ? Icons.restore : Icons.backup,
                  size: 50,
                  color: primaryColor,
                ),
                const SizedBox(height: 8),
                Text(
                  '${(progress.percentage * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 30),

        // الحالة
        Text(
          progress.stage,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1F28),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            progress.currentFileName.isEmpty
                ? 'جاري التحضير...'
                : progress.currentFileName,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 30),
        const Spacer(),

        // الإحصائيات
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.5,
          children: [
            _statBox(Icons.insert_drive_file, 'الملفات',
                '${progress.currentFile} / ${progress.totalFiles}',
                Colors.cyan),
            _statBox(Icons.storage, 'الحجم',
                '${_formatBytes(progress.bytesProcessed)} / ${_formatBytes(progress.totalBytes)}',
                Colors.amber),
            _statBox(Icons.speed, 'السرعة',
                '${progress.speedMBps.toStringAsFixed(1)} MB/s',
                Colors.greenAccent),
            _statBox(Icons.timer, 'المتبقي',
                _formatDuration(progress.eta), Colors.orangeAccent),
          ],
        ),

        const SizedBox(height: 20),

        // زر الإلغاء
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showCancelDialog,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.cancel),
            label: const Text('إلغاء العملية'),
          ),
        ),
      ],
    );
  }

  Widget _statBox(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 10)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // واجهة الإكمال
  // ══════════════════════════════════════════════════════════════
  Widget _buildDoneView(BackupProgress progress, Color primaryColor) {
    final hasError = progress.error != null;
    final color = hasError ? Colors.redAccent : Colors.greenAccent;

    return Column(
      children: [
        const Spacer(),
        Icon(
          hasError ? Icons.error_outline : Icons.check_circle,
          size: 100,
          color: color,
        ),
        const SizedBox(height: 20),
        Text(
          hasError ? 'حدث خطأ' : (widget.isRestore ? 'تمت الاستعادة' : 'تم الإنشاء'),
          style: TextStyle(
              fontSize: 26, fontWeight: FontWeight.w900, color: color),
        ),
        const SizedBox(height: 12),
        if (hasError)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1F28),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              progress.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          )
        else if (progress.resultPath != null) ...[
          const Text('مسار الملف:',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1B1F28),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    progress.resultPath!,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 10),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.cyan, size: 20),
                  tooltip: 'نسخ المسار',
                  onPressed: () {
                    Clipboard.setData(
                        ClipboardData(text: progress.resultPath!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم نسخ المسار')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '💡 الملف محفوظ داخل مجلد التطبيق.\n'
            'استخدم "مشاركة" لحفظه في Google Drive أو أي مكان آخر.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.5),
          ),
        ],
        const Spacer(),
        if (!hasError && progress.resultPath != null) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                await Share.shareXFiles([XFile(progress.resultPath!)],
                    text: 'نسخة ذاكرة الأوتاكو');
              },
              style: FilledButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.share),
              label: const Text('مشاركة / حفظ في Drive'),
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryColor,
              side: BorderSide(color: primaryColor),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.arrow_back),
            label: const Text('رجوع'),
          ),
        ),
      ],
    );
  }

  void _showCancelDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B1F28),
        title: const Text('إلغاء العملية؟'),
        content: const Text(
            'سيتم إيقاف العملية. الملفات المنسوخة حتى الآن ستبقى، لكنها غير مكتملة.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('استمرار')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              _service.cancel();
              Navigator.pop(ctx);
            },
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }
}