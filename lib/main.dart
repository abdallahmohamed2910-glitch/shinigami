import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'game_spy.dart';
import 'game_charades.dart';
import 'game_wink.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const ShinigamiApp());
}

class ShinigamiApp extends StatelessWidget {
  const ShinigamiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'شينيغامي - Shinigami',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFDC2626), // Crimson red
          background: Color(0xFF0D0D0D), // Solid deep black
          surface: Color(0xFF161616), // Dark gray
        ),
        fontFamily: 'Inter',
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _activeGame = 'HOME'; // 'HOME' | 'SPY' | 'CHARADES' | 'WINK'
  AppSettings _settings = AppSettings(soundOn: true, vibrationOn: true);
  List<GameCategory> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadDatabase();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sound = prefs.getBool('shinigami_soundOn') ?? true;
      final vib = prefs.getBool('shinigami_vibrationOn') ?? true;
      setState(() {
        _settings = AppSettings(soundOn: sound, vibrationOn: vib);
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  Future<void> _saveSettings(AppSettings newSettings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('shinigami_soundOn', newSettings.soundOn);
      await prefs.setBool('shinigami_vibrationOn', newSettings.vibrationOn);
      setState(() {
        _settings = newSettings;
      });
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  Future<void> _loadDatabase() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/database.json');
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);
      final db = GameDatabase.fromJson(jsonData);
      setState(() {
        _categories = db.categories;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading word database: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _playClickSound() {
    if (_settings.soundOn) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  void _triggerVibration() {
    if (_settings.vibrationOn) {
      HapticFeedback.mediumImpact();
    }
  }

  void _selectGame(String gameKey) {
    _playClickSound();
    _triggerVibration();
    setState(() {
      _activeGame = gameKey;
    });
  }

  void _openSettingsDialog() {
    _playClickSound();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: const Color(0xFF161616),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              title: const Row(
                children: [
                  Icon(Icons.settings, color: Color(0xFFDC2626)),
                  SizedBox(width: 8),
                  Text('الإعدادات', style: TextStyle(fontWeight: FontWeight.black, fontSize: 18, color: Colors.white)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    activeColor: const Color(0xFFDC2626),
                    title: const Text('المؤثرات الصوتية 🔊', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    value: _settings.soundOn,
                    onChanged: (val) {
                      final updated = _settings.copyWith(soundOn: val);
                      _saveSettings(updated);
                      setDialogState(() {});
                    },
                  ),
                  SwitchListTile(
                    activeColor: const Color(0xFFDC2626),
                    title: const Text('الاهتزاز اللمسي 📳', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    value: _settings.vibrationOn,
                    onChanged: (val) {
                      final updated = _settings.copyWith(vibrationOn: val);
                      _saveSettings(updated);
                      setDialogState(() {});
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إغلاق', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFDC2626)))
              : _buildActiveView(),
        ),
      ),
    );
  }

  Widget _buildActiveView() {
    switch (_activeGame) {
      case 'SPY':
        return GameSpy(
          categories: _categories,
          settings: _settings,
          onBackToHome: () => setState(() => _activeGame = 'HOME'),
        );
      case 'CHARADES':
        return GameCharades(
          categories: _categories,
          settings: _settings,
          onBackToHome: () => setState(() => _activeGame = 'HOME'),
        );
      case 'WINK':
        return GameWink(
          settings: _settings,
          onBackToHome: () => setState(() => _activeGame = 'HOME'),
        );
      default:
        return _buildHome();
    }
  }

  Widget _buildHome() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF161616),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.star, size: 14, color: Color(0xFFDC2626)),
                    SizedBox(width: 4),
                    Text(
                      'ألعاب جماعية بلا إنترنت',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.extrabold, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.grey, size: 24),
                onPressed: _openSettingsDialog,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF161616),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Colors.white10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Logo Mask Oni and Title
          Column(
            children: [
              CustomPaint(
                size: const Size(100, 100),
                painter: OniMaskPainter(),
              ),
              const SizedBox(height: 12),
              const Text(
                'شينيغامي Shinigami',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.black, color: Colors.white),
              ),
              const SizedBox(height: 6),
              const Text(
                'مجموعة ألعاب الحفلات والتجمعات المشوقة والمثيرة في تطبيق واحد دون الحاجة للاتصال بالإنترنت!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.5),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Game Selector Cards
          Expanded(
            child: ListView(
              children: [
                _buildGameCard(
                  title: 'بكاسة (الجاسوس)',
                  desc: 'الكل يستلم كلمة سرية ما عدا لاعب واحد "بره اللعبة"! هل ستكشفونه أم سيفلت بذكائه؟',
                  icon: '🕵️',
                  onTap: () => _selectGame('SPY'),
                ),
                const SizedBox(height: 12),
                _buildGameCard(
                  title: 'من غير كلام (تمثيل وإشارة)',
                  desc: 'اختر تصنيفك المفضل ومثل الكلمات لفريقك بالإشارة والصمت. احصد أكبر عدد من النقاط!',
                  icon: '🎭',
                  onTap: () => _selectGame('CHARADES'),
                ),
                const SizedBox(height: 12),
                _buildGameCard(
                  title: 'الغمزة (القاتل الصامت)',
                  desc: 'قاتل يغمز للجميع سرياً ليقضي عليهم، ومواطنون يحاولون كشف هويته والتصويت ضده!',
                  icon: '😉',
                  onTap: () => _selectGame('WINK'),
                ),
              ],
            ),
          ),

          // Footer Credit
          const Center(
            child: Text(
              'تطبيق شينيغامي © ٢٠٢٦ • صنع للشغوفين بالألعاب الجماعية',
              style: TextStyle(fontSize: 10, color: Colors.white24),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildGameCard({
    required String title,
    required String desc,
    required String icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161616),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              alignment: Alignment.center,
              child: Text(icon, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.black, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.grey, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}

class OniMaskPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDC2626)
      ..style = PaintingStyle.fill;

    final path = Path();
    // Simple custom Oni mask path drawing
    path.moveTo(size.width * 0.2, size.height * 0.35);
    path.quadraticBezierTo(size.width * 0.15, size.height * 0.1, size.width * 0.32, size.height * 0.25);
    path.lineTo(size.width * 0.2, size.height * 0.35);
    path.close();
    canvas.drawPath(path, paint);

    final path2 = Path();
    path2.moveTo(size.width * 0.8, size.height * 0.35);
    path2.quadraticBezierTo(size.width * 0.85, size.height * 0.1, size.width * 0.68, size.height * 0.25);
    path2.lineTo(size.width * 0.8, size.height * 0.35);
    path2.close();
    canvas.drawPath(path2, paint);

    // Face Shield
    final facePaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final facePath = Path();
    facePath.moveTo(size.width * 0.25, size.height * 0.35);
    facePath.lineTo(size.width * 0.75, size.height * 0.35);
    facePath.lineTo(size.width * 0.70, size.height * 0.75);
    facePath.quadraticBezierTo(size.width * 0.5, size.height * 0.88, size.width * 0.30, size.height * 0.75);
    facePath.close();

    canvas.drawPath(facePath, facePaint);
    canvas.drawPath(facePath, strokePaint);

    // Glowing Red Eyes
    final eyePaint = Paint()..color = const Color(0xFFDC2626);
    final eyePath1 = Path();
    eyePath1.moveTo(size.width * 0.32, size.height * 0.45);
    eyePath1.lineTo(size.width * 0.44, size.height * 0.48);
    eyePath1.lineTo(size.width * 0.40, size.height * 0.54);
    eyePath1.lineTo(size.width * 0.30, size.height * 0.50);
    eyePath1.close();
    canvas.drawPath(eyePath1, eyePaint);

    final eyePath2 = Path();
    eyePath2.moveTo(size.width * 0.68, size.height * 0.45);
    eyePath2.lineTo(size.width * 0.56, size.height * 0.48);
    eyePath2.lineTo(size.width * 0.60, size.height * 0.54);
    eyePath2.lineTo(size.width * 0.70, size.height * 0.50);
    eyePath2.close();
    canvas.drawPath(eyePath2, eyePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
