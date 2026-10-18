import 'dart:async';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

void main() => runApp(const FallPianoApp());

class FallPianoApp extends StatelessWidget {
  const FallPianoApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Fall Piano',
    theme: ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: const Color(0xFF090B13),
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8B5CF6), brightness: Brightness.dark),
    ),
    home: const GamePage(),
  );
}

class TileNote {
  TileNote(this.lane, this.spawned, this.id);
  final int lane;
  final double spawned;
  final int id;
  bool hit = false;
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with TickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();
  final Random _random = Random();
  final List<TileNote> _notes = [];
  Timer? _timer;
  DateTime? _started;
  String _songName = 'ما تم اختيار أغنية';
  String _mode = 'أربعة مسارات';
  int _score = 0;
  int _combo = 0;
  int _bestCombo = 0;
  int _nextId = 0;
  double _bpm = 110;
  bool _playing = false;
  bool _autoDifficulty = true;
  double _difficulty = 1;
  int get _lanes => _mode == 'بيانو 8 مفاتيح' ? 8 : 4;

  @override
  void dispose() {
    _timer?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _pickSong() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio, withData: false);
    if (result == null || result.files.single.path == null) return;
    final file = result.files.single;
    try {
      await _player.setFilePath(file.path!);
      setState(() => _songName = file.name);
      _show('تم تحميل الملف. تحليل النغمات الحقيقي غير متوفر في هذه النسخة؛ سيتم إنشاء إيقاع تجريبي متزامن مع BPM.');
    } catch (e) {
      _show('تعذر فتح الملف الصوتي: $e');
    }
  }

  void _start() async {
    _timer?.cancel();
    _notes.clear();
    _score = 0; _combo = 0; _bestCombo = 0;
    _started = DateTime.now();
    setState(() => _playing = true);
    try { if (_player.audioSource != null) { await _player.seek(Duration.zero); await _player.play(); } } catch (_) {}
    _timer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted || !_playing) return;
      final elapsed = DateTime.now().difference(_started!).inMilliseconds / 1000;
      final interval = 60 / _bpm / _difficulty;
      if ((elapsed / interval) > _nextId) {
        _notes.add(TileNote(_random.nextInt(_lanes), elapsed, _nextId++));
      }
      _notes.removeWhere((n) => elapsed - n.spawned > 2.4 || n.hit);
      setState(() {});
    });
  }

  void _stop() {
    _timer?.cancel();
    _player.pause();
    setState(() => _playing = false);
  }

  void _tapLane(int lane) {
    if (!_playing) return;
    final now = DateTime.now().difference(_started!).inMilliseconds / 1000;
    TileNote? nearest;
    double distance = 999;
    for (final n in _notes.where((n) => n.lane == lane && !n.hit)) {
      final d = (now - n.spawned - 1.65).abs();
      if (d < distance) { distance = d; nearest = n; }
    }
    setState(() {
      if (nearest != null && distance < .48) {
        nearest.hit = true; _score += distance < .18 ? 100 : distance < .32 ? 70 : 40;
        _combo++; _bestCombo = max(_bestCombo, _combo);
      } else { _combo = 0; }
    });
  }

  void _show(String message) => showDialog<void>(context: context, builder: (c) => AlertDialog(
    title: const Text('Fall Piano'), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('حسنًا'))],
  ));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('FALL PIANO', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)), centerTitle: true),
    body: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(14, 6, 14, 10), child: Column(children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF151827), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white10)),
          child: Row(children: [const Icon(Icons.music_note, color: Color(0xFFB69CFF), size: 30), const SizedBox(width: 10), Expanded(child: Text(_songName, maxLines: 1, overflow: TextOverflow.ellipsis)), IconButton(onPressed: _pickSong, icon: const Icon(Icons.folder_open))])),
        const SizedBox(height: 10),
        Row(children: [Expanded(child: _selector('نمط اللعب', _mode, ['أربعة مسارات','بيانو 8 مفاتيح'], (v) => setState(() { _mode = v; _notes.clear(); }))), const SizedBox(width: 8), Expanded(child: _selector('BPM', '${_bpm.round()}', ['80','100','110','120','140','160'], (v) => setState(() => _bpm = double.parse(v))))]),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('الصعوبة التلقائية'), subtitle: Text(_autoDifficulty ? 'سرعة متوسطة تتدرج مع اللعب' : 'تحكم يدوي بسرعة توليد الملاحظات'), value: _autoDifficulty, onChanged: (v) => setState(() { _autoDifficulty = v; _difficulty = v ? 1 : 1.35; })),
        Row(children: [Expanded(child: _stat('النقاط', '$_score')), const SizedBox(width: 8), Expanded(child: _stat('التتابع', '$_combo')), const SizedBox(width: 8), Expanded(child: _stat('أفضل تتابع', '$_bestCombo'))]),
      ])),
      Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: const Color(0xFF101321), border: Border.all(color: const Color(0xFF292D43))), clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(builder: (context, constraints) {
          final laneW = constraints.maxWidth / _lanes;
          final now = _started == null ? 0.0 : DateTime.now().difference(_started!).inMilliseconds / 1000;
          return Stack(children: [
            for (int i = 0; i < _lanes; i++) Positioned(left: i * laneW, top: 0, bottom: 0, width: laneW, child: GestureDetector(onTap: () => _tapLane(i), child: Container(decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.white.withOpacity(.07))), color: i.isEven ? Colors.white.withOpacity(.015) : Colors.transparent)))),
            for (final note in _notes) if (!note.hit) Positioned(left: note.lane * laneW + 3, width: laneW - 6, top: ((now - note.spawned) / 2.4) * constraints.maxHeight, height: 62, child: IgnorePointer(child: Container(decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFB69CFF), Color(0xFF6D5DFB)]), borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(.3), blurRadius: 12)])))),
            Positioned(bottom: 55, left: 0, right: 0, child: Container(height: 3, color: const Color(0xFFFF6B9D))),
            if (!_playing) const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.piano, size: 52, color: Color(0xFFB69CFF)), SizedBox(height: 8), Text('اضغط ابدأ للعب', style: TextStyle(color: Colors.white70))])),
            Positioned(bottom: 0, left: 0, right: 0, height: 52, child: Row(children: List.generate(_lanes, (i) => Expanded(child: GestureDetector(onTap: () => _tapLane(i), child: Container(margin: const EdgeInsets.all(2), decoration: BoxDecoration(color: i % 2 == 0 ? const Color(0xFFE9E9F2) : const Color(0xFF35374A), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7))), child: Center(child: Text('${i+1}', style: TextStyle(color: i%2==0 ? Colors.black87 : Colors.white, fontWeight: FontWeight.bold))))))))),
          ]);
        }))),
      Padding(padding: const EdgeInsets.all(14), child: Row(children: [Expanded(child: FilledButton.icon(onPressed: _playing ? _stop : _start, icon: Icon(_playing ? Icons.stop : Icons.play_arrow), label: Text(_playing ? 'إيقاف اللعب' : 'ابدأ اللعب'), style: FilledButton.styleFrom(minimumSize: const Size(0, 52)))), const SizedBox(width: 10), OutlinedButton(onPressed: () { setState(() { _notes.clear(); _score = 0; _combo = 0; }); }, style: OutlinedButton.styleFrom(minimumSize: const Size(56, 52)), child: const Icon(Icons.refresh))])),
      const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('نسخة تجريبية • توليد نغمات إيقاعي وليس استخراجًا لحنيًا حقيقيًا', style: TextStyle(fontSize: 11, color: Colors.white54))),
    ])),
  );

  Widget _stat(String label, String value) => Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: const Color(0xFF151827), borderRadius: BorderRadius.circular(12)), child: Column(children: [Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(fontSize: 11, color: Colors.white60))]));
  Widget _selector(String label, String value, List<String> options, ValueChanged<String> onChanged) => DropdownButtonFormField<String>(value: value, decoration: InputDecoration(labelText: label, filled: true, fillColor: const Color(0xFF151827), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)), items: options.map((v) => DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) { if (v != null) onChanged(v); });
}