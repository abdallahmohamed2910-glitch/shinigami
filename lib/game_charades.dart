import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';

class GameCharades extends StatefulWidget {
  final List<GameCategory> categories;
  final AppSettings settings;
  final VoidCallback onBackToHome;

  const GameCharades({
    super.key,
    required this.categories,
    required this.settings,
    required this.onBackToHome,
  });

  @override
  State<GameCharades> createState() => _GameCharadesState();
}

enum CharadesStep {
  categorySelection,
  gameSetup,
  roundIntro,
  activeTurn,
  turnSummary,
  finalResults,
}

class _CharadesTeam {
  final String id;
  final String name;
  int score;

  _CharadesTeam({required this.id, required this.name, this.score = 0});
}

class _GameCharadesState extends State<GameCharades> {
  CharadesStep _step = CharadesStep.categorySelection;
  GameCategory? _selectedCategory;

  // Setup options
  int _numTeams = 2;
  List<String> _teamNames = ['فريق الصقور 🦅', 'فريق الذئاب 🐺', 'فريق الأسود 🦁', 'فريق النمور 🐯'];
  int _selectedRounds = 3;
  int _selectedTimer = 60; // in seconds

  // Game active state
  List<_CharadesTeam> _teams = [];
  int _currentRound = 1;
  int _currentTeamIndex = 0;

  // Word pool
  List<String> _wordPool = [];
  String _currentWord = '';

  // Active turn state
  int _timeLeft = 60;
  int _turnScore = 0;
  List<String> _turnCorrectWords = [];
  List<String> _turnSkippedWords = [];
  bool _isPaused = false;
  Timer? _timer;

  final Map<String, String> _categoryIcons = {
    "أفلام مصرية": "🎬",
    "أنمي": "⚔️",
    "كرتون": "🧸",
    "حيوانات": "🦁",
    "أكلات": "🍔",
    "أماكن": "🏰",
    "مهن": "👨‍⚕️",
    "ملابس وإكسسوارات": "🕶️",
    "وسائل مواصلات": "🚀",
    "أجهزة وأدوات": "🎮",
    "رياضة": "⚽"
  };

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _playClickSound() {
    if (widget.settings.soundOn) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  void _triggerVibration({int durationMs = 30}) {
    if (widget.settings.vibrationOn) {
      HapticFeedback.lightImpact();
    }
  }

  void _selectCategory(GameCategory category) {
    _playClickSound();
    _triggerVibration(durationMs: 30);
    setState(() {
      _selectedCategory = category;
      _step = CharadesStep.gameSetup;
    });
  }

  void _startGame() {
    _playClickSound();
    _triggerVibration(durationMs: 50);

    final initialTeams = List.generate(_numTeams, (idx) {
      return _CharadesTeam(
        id: 'team_$idx',
        name: _teamNames[idx],
        score: 0,
      );
    });

    setState(() {
      _teams = initialTeams;
      _currentRound = 1;
      _currentTeamIndex = 0;

      if (_selectedCategory != null) {
        _wordPool = List<String>.from(_selectedCategory!.words)..shuffle();
      }

      _step = CharadesStep.roundIntro;
    });
  }

  void _prepareTurn() {
    _playClickSound();
    _triggerVibration(durationMs: 40);

    if (_wordPool.isEmpty && _selectedCategory != null) {
      _wordPool = List<String>.from(_selectedCategory!.words)..shuffle();
    }

    final word = _wordPool.isNotEmpty ? _wordPool.removeAt(0) : 'انتهت الكلمات';

    setState(() {
      _currentWord = word;
      _timeLeft = _selectedTimer;
      _turnScore = 0;
      _turnCorrectWords = [];
      _turnSkippedWords = [];
      _isPaused = false;
      _step = CharadesStep.activeTurn;
      _startTurnTimer();
    });
  }

  void _startTurnTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && _timeLeft > 0 && _step == CharadesStep.activeTurn) {
        setState(() {
          _timeLeft--;
        });
      } else if (_timeLeft == 0 && _step == CharadesStep.activeTurn) {
        _timer?.cancel();
        _triggerVibration(durationMs: 120);
        _finishTurn();
      }
    });
  }

  void _handleCorrectAnswer() {
    _playClickSound();
    _triggerVibration(durationMs: 30);

    setState(() {
      _turnScore++;
      _turnCorrectWords.add(_currentWord);

      if (_wordPool.isEmpty && _selectedCategory != null) {
        _wordPool = List<String>.from(_selectedCategory!.words)..shuffle();
      }
      _currentWord = _wordPool.isNotEmpty ? _wordPool.removeAt(0) : 'انتهت الكلمات';
    });
  }

  void _handleSkipAnswer() {
    _playClickSound();
    _triggerVibration(durationMs: 25);

    setState(() {
      _turnSkippedWords.add(_currentWord);

      if (_wordPool.isEmpty && _selectedCategory != null) {
        _wordPool = List<String>.from(_selectedCategory!.words)..shuffle();
      }
      _currentWord = _wordPool.isNotEmpty ? _wordPool.removeAt(0) : 'انتهت الكلمات';
    });
  }

  void _togglePause() {
    _playClickSound();
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  void _finishTurn() {
    _timer?.cancel();
    // Save points to active team
    _teams[_currentTeamIndex].score += _turnScore;

    setState(() {
      _step = CharadesStep.turnSummary;
    });
  }

  void _nextTurn() {
    _playClickSound();
    _triggerVibration(durationMs: 30);

    setState(() {
      if (_currentTeamIndex < _teams.length - 1) {
        _currentTeamIndex++;
        _step = CharadesStep.roundIntro;
      } else {
        // Round completed for all teams
        if (_currentRound < _selectedRounds) {
          _currentRound++;
          _currentTeamIndex = 0;
          _step = CharadesStep.roundIntro;
        } else {
          // Game ended completely!
          _step = CharadesStep.finalResults;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: _buildCurrentStep(),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case CharadesStep.categorySelection:
        return _buildCategorySelection();
      case CharadesStep.gameSetup:
        return _buildGameSetup();
      case CharadesStep.roundIntro:
        return _buildRoundIntro();
      case CharadesStep.activeTurn:
        return _buildActiveTurn();
      case CharadesStep.turnSummary:
        return _buildTurnSummary();
      case CharadesStep.finalResults:
        return _buildFinalResults();
    }
  }

  Widget _buildCategorySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () {
                _playClickSound();
                widget.onBackToHome();
              },
            ),
            const Text(
              'من غير كلام 🎭',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.black, color: Color(0xFFDC2626)),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'اختر التصنيف المفضل لبدء تمثيل الكلمات بالإشارة والصمت والسرعة!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.1,
            ),
            itemCount: widget.categories.length,
            itemBuilder: (context, idx) {
              final cat = widget.categories[idx];
              final icon = _categoryIcons[cat.name] ?? '📦';
              return InkWell(
                onTap: () => _selectCategory(cat),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161616),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(icon, style: const TextStyle(fontSize: 32)),
                      const SizedBox(height: 6),
                      Text(
                        cat.name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.extrabold, fontSize: 13, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${cat.words.length} كلمة',
                        style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGameSetup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () {
                _playClickSound();
                setState(() {
                  _step = CharadesStep.categorySelection;
                });
              },
            ),
            const Text('إعدادات الجولة ⚙️', style: TextStyle(fontSize: 22, fontWeight: FontWeight.black, color: Colors.white)),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            children: [
              // Show Category Name Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Text(_categoryIcons[_selectedCategory?.name] ?? '📦', style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('التصنيف المختار:', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        Text(_selectedCategory?.name ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.orangeAccent)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Number of teams slider or picker
              _buildSectionTitle('عدد الفرق المشاركة:'),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [2, 3, 4].map((num) {
                  final isSelected = _numTeams == num;
                  return InkWell(
                    onTap: () {
                      _playClickSound();
                      setState(() {
                        _numTeams = num;
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFDC2626) : const Color(0xFF161616),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isSelected ? Colors.transparent : Colors.white10),
                      ),
                      child: Text('$num فرق', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Custom Round Count Picker
              _buildSectionTitle('عدد جولات الجلسة:'),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [2, 3, 5, 7].map((num) {
                  final isSelected = _selectedRounds == num;
                  return InkWell(
                    onTap: () {
                      _playClickSound();
                      setState(() {
                        _selectedRounds = num;
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFDC2626) : const Color(0xFF161616),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isSelected ? Colors.transparent : Colors.white10),
                      ),
                      child: Text('$num جولات', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Custom Timer Picker (seconds)
              _buildSectionTitle('وقت تخمين كل كلمة (بالثواني):'),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [30, 60, 90, 120].map((sec) {
                  final isSelected = _selectedTimer == sec;
                  return InkWell(
                    onTap: () {
                      _playClickSound();
                      setState(() {
                        _selectedTimer = sec;
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFDC2626) : const Color(0xFF161616),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isSelected ? Colors.transparent : Colors.white10),
                      ),
                      child: Text('$sec ثانية', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        ElevatedButton(
          onPressed: _startGame,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          child: const Text('ابدأ المنافسة 🚀', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildRoundIntro() {
    final activeTeam = _teams[_currentTeamIndex];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Text('الجولة $_currentRound من $_selectedRounds', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              const Text('حان دور الفريق:', style: TextStyle(fontSize: 15, color: Colors.grey)),
              const SizedBox(height: 12),
              Text(
                activeTeam.name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.black, color: Colors.white),
              ),
              const SizedBox(height: 12),
              const Text(
                'استعد لتمثيل الكلمات فور تشغيل المؤقت وحاول مساعدة فريقك لجمع أكبر قدر من النقاط!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: _prepareTurn,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          child: const Text('ابدأ التخمين الآن 🎭', style: TextStyle(fontSize: 18, fontWeight: FontWeight.black, color: Colors.white)),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildActiveTurn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_teams[_currentTeamIndex].name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            Text('النقاط: $_turnScore', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
          ],
        ),
        const SizedBox(height: 16),

        // Word Card
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.3)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('مثل هذه الكلمة بالإشارة:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 16),
                _isPaused
                    ? const Text('المؤقت متوقف ⏸️', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey))
                    : Text(
                        _currentWord,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.black, color: Colors.white),
                      ),
                const SizedBox(height: 24),
                // Time circle
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: CircularProgressIndicator(
                        value: _timeLeft / _selectedTimer,
                        color: _timeLeft < 10 ? Colors.redAccent : const Color(0xFFDC2626),
                        backgroundColor: Colors.white10,
                        strokeWidth: 8,
                      ),
                    ),
                    Text(
                      '$_timeLeft',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.black, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Action Buttons Row
        Row(
          children: [
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isPaused ? null : _handleCorrectAnswer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.emerald,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('صح ✅', style: TextStyle(fontSize: 18, fontWeight: FontWeight.extrabold, color: Colors.white)),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause, color: Colors.white, size: 28),
              onPressed: _togglePause,
              style: IconButton.styleFrom(backgroundColor: Colors.black45, padding: const EdgeInsets.all(14)),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: ElevatedButton(
                onPressed: _isPaused ? null : _handleSkipAnswer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade900,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('تخطي ⏭️', style: TextStyle(fontSize: 13, color: Colors.grey)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTurnSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('ملخص الجولة 📊', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.black, color: Color(0xFFDC2626))),
        const SizedBox(height: 6),
        Text('لقد جمع فريق ${_teams[_currentTeamIndex].name} نقاطاً ممتازة!', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 16),

        // Score Card
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(24)),
          child: Column(
            children: [
              const Text('النقاط المكتسبة بالجولة:', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 4),
              Text('+$_turnScore', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.black, color: Colors.orangeAccent)),
            ],
          ),
        ),

        const SizedBox(height: 16),
        const Text('الكلمات المخمنة بنجاح:', style: TextStyle(color: Colors.emerald, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Expanded(
          child: _turnCorrectWords.isEmpty
              ? const Center(child: Text('لا يوجد كلمات مخمنة.', style: TextStyle(color: Colors.grey, fontSize: 11)))
              : ListView.builder(
                  itemCount: _turnCorrectWords.length,
                  itemBuilder: (context, idx) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.emerald.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: Colors.emerald, size: 16),
                        const SizedBox(width: 8),
                        Text(_turnCorrectWords[idx], style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
        ),

        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _nextTurn,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          child: const Text('التالي ⏭️', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildFinalResults() {
    // Sort teams by highest score
    final sortedTeams = List<_CharadesTeam>.from(_teams)..sort((a, b) => b.score.compareTo(a.score));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        const Center(child: Text('🏆', style: TextStyle(fontSize: 64))),
        const Text('النتائج النهائية 🎖️', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.black, color: Colors.orangeAccent)),
        const SizedBox(height: 12),

        Expanded(
          child: ListView.builder(
            itemCount: sortedTeams.length,
            itemBuilder: (context, idx) {
              final team = sortedTeams[idx];
              final isWinner = idx == 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isWinner ? const Color(0xFFDC2626).withOpacity(0.1) : const Color(0xFF161616),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isWinner ? const Color(0xFFDC2626).withOpacity(0.3) : Colors.white10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${idx + 1}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.black,
                            color: isWinner ? const Color(0xFFDC2626) : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(team.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                      ],
                    ),
                    Text('${team.score} نقطة', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                  ],
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  _playClickSound();
                  _triggerVibration(durationMs: 40);
                  setState(() {
                    _step = CharadesStep.categorySelection;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('لعب مجدداً 🔄', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: widget.onBackToHome,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade900,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('الرئيسية 🏠', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 12.0),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
    );
  }
}
