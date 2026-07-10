import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'models.dart';

class GameSpy extends StatefulWidget {
  final List<GameCategory> categories;
  final AppSettings settings;
  final VoidCallback onBackToHome;

  const GameSpy({
    super.key,
    required this.categories,
    required this.settings,
    required this.onBackToHome,
  });

  @override
  State<GameSpy> createState() => _GameSpyState();
}

enum SpyStep {
  playersInput,
  categorySelection,
  passPhone,
  revealRole,
  questioning,
  voting,
  results,
}

class _GameSpyState extends State<GameSpy> {
  SpyStep _step = SpyStep.playersInput;
  final List<String> _playerNames = [];
  final TextEditingController _nameController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Active game session state
  List<SpyPlayer> _players = [];
  String _selectedSecretWord = '';
  String _selectedCategoryName = '';
  GameCategory? _selectedCategory;
  int _currentPlayerIndex = 0;

  // Questioning state
  List<Map<String, String>> _questionPairs = [];
  int _timerSeconds = 120;
  bool _timerActive = false;
  Timer? _timer;

  // Voting state
  int _votingPlayerIndex = 0;
  Map<String, String> _votes = {}; // voterId -> votedId

  // Results state
  String _spyPlayerName = '';
  String _mostVotedPlayerName = '';
  bool _spyVotedOut = false;
  String _winners = ''; // 'CITIZENS' | 'SPY'

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
    _nameController.dispose();
    _timer?.cancel();
    _audioPlayer.dispose();
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

  void _addPlayer() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty && !_playerNames.contains(name) && _playerNames.length < 20) {
      _playClickSound();
      _triggerVibration(durationMs: 25);
      setState(() {
        _playerNames.add(name);
        _nameController.clear();
      });
    }
  }

  void _removePlayer(int index) {
    _playClickSound();
    _triggerVibration(durationMs: 25);
    setState(() {
      _playerNames.removeAt(index);
    });
  }

  void _startGame(GameCategory chosenCat) {
    if (_playerNames.length < 3) return;

    _playClickSound();
    _triggerVibration(durationMs: 50);

    // Pick random secret word from selection category
    final random = Random();
    final randomWord = chosenCat.words[random.nextInt(chosenCat.words.length)];

    setState(() {
      _selectedSecretWord = randomWord;
      _selectedCategoryName = chosenCat.name;
      _selectedCategory = chosenCat;

      // Assign spy and roles
      final List<String> shuffledNames = List.from(_playerNames)..shuffle(random);
      final spyIndex = random.nextInt(shuffledNames.length);

      _players = List.generate(shuffledNames.length, (idx) {
        final isSpy = idx == spyIndex;
        return SpyPlayer(
          id: 'p_$idx',
          name: shuffledNames[idx],
          role: isSpy ? 'SPY' : 'CITIZEN',
        );
      });

      _currentPlayerIndex = 0;
      _step = SpyStep.passPhone;
    });
  }

  void _handlePlayerRevealClick() {
    _playClickSound();
    _triggerVibration(durationMs: 40);
    setState(() {
      _step = SpyStep.revealRole;
    });
  }

  void _handlePlayerConfirmSeen() {
    _playClickSound();
    _triggerVibration(durationMs: 30);
    setState(() {
      if (_currentPlayerIndex < _players.length - 1) {
        _currentPlayerIndex++;
        _step = SpyStep.passPhone;
      } else {
        _generateQuestioningOrder();
      }
    });
  }

  void _generateQuestioningOrder() {
    final random = Random();
    final shuffledPlayers = List<SpyPlayer>.from(_players)..shuffle(random);
    final List<Map<String, String>> pairs = [];

    for (int i = 0; i < shuffledPlayers.length; i++) {
      final asker = shuffledPlayers[i].name;
      final receiver = shuffledPlayers[(i + 1) % shuffledPlayers.length].name;
      pairs.add({'asker': asker, 'receiver': receiver});
    }

    setState(() {
      _questionPairs = pairs;
      _timerSeconds = 120;
      _timerActive = true;
      _step = SpyStep.questioning;
      _startTimer();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerActive && _timerSeconds > 0) {
        setState(() {
          _timerSeconds--;
        });
      } else if (_timerSeconds == 0) {
        _timerActive = false;
        _timer?.cancel();
        _triggerVibration(durationMs: 100);
      }
    });
  }

  void _toggleTimer() {
    _playClickSound();
    setState(() {
      _timerActive = !_timerActive;
    });
  }

  void _skipTimer() {
    _playClickSound();
    setState(() {
      _timerSeconds = 0;
      _timerActive = false;
    });
  }

  void _startVoting() {
    _playClickSound();
    _triggerVibration(durationMs: 40);
    setState(() {
      _votingPlayerIndex = 0;
      _votes = {};
      _step = SpyStep.voting;
    });
  }

  void _handleVoteCast(String votedPlayerId) {
    _playClickSound();
    _triggerVibration(durationMs: 30);
    final voter = _players[_votingPlayerIndex];
    
    setState(() {
      _votes[voter.id] = votedPlayerId;
      if (_votingPlayerIndex < _players.length - 1) {
        _votingPlayerIndex++;
      } else {
        _calculateResults();
      }
    });
  }

  void _calculateResults() {
    // Count votes
    final Map<String, int> voteCounts = {};
    for (var p in _players) {
      voteCounts[p.id] = 0;
    }

    _votes.values.forEach((votedId) {
      if (voteCounts.containsKey(votedId)) {
        voteCounts[votedId] = voteCounts[votedId]! + 1;
      }
    });

    final spy = _players.firstWhere((p) => p.role == 'SPY');
    _spyPlayerName = spy.name;

    // Find player with the most votes
    int maxVotes = -1;
    SpyPlayer? mostVoted;
    bool isTie = false;

    for (var p in _players) {
      final count = voteCounts[p.id] ?? 0;
      if (count > maxVotes) {
        maxVotes = count;
        mostVoted = p;
        isTie = false;
      } else if (count == maxVotes) {
        isTie = true;
      }
    }

    _mostVotedPlayerName = mostVoted != null ? mostVoted.name : 'لا أحد';
    _spyVotedOut = mostVoted != null && !isTie && mostVoted.role == 'SPY';
    _winners = _spyVotedOut ? 'CITIZENS' : 'SPY';

    // Update state players with vote counts for listing
    _players = _players.map((p) {
      return p; // We can show detailed voting in Results
    }).toList();

    _triggerVibration(durationMs: 80);
    setState(() {
      _step = SpyStep.results;
    });
  }

  void _restartGame() {
    if (_selectedCategory != null) {
      _startGame(_selectedCategory!);
    }
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: _buildCurrentStep(context),
      ),
    );
  }

  Widget _buildCurrentStep(BuildContext context) {
    switch (_step) {
      case SpyStep.playersInput:
        return _buildPlayersInput();
      case SpyStep.categorySelection:
        return _buildCategorySelection();
      case SpyStep.passPhone:
        return _buildPassPhone();
      case SpyStep.revealRole:
        return _buildRevealRole();
      case SpyStep.questioning:
        return _buildQuestioning();
      case SpyStep.voting:
        return _buildVoting();
      case SpyStep.results:
        return _buildResults();
    }
  }

  // STEP 1: Players input screen
  Widget _buildPlayersInput() {
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
              'بكاسة 🕵️',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.black,
                color: Color(0xFFDC2626),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.people_outline, color: Color(0xFFDC2626), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'أدخل أسماء اللاعبين (3 - 20)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      maxLength: 15,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addPlayer(),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'اسم اللاعب الجديد...',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        filled: true,
                        fillColor: Colors.black,
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFDC2626)),
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white12),
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addPlayer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _playerNames.isEmpty
              ? const Center(
                  child: Text(
                    'لم يتم إضافة لاعبين بعد.\nابدأ بكتابة الأسماء بالصندوق أعلاه ⬆️',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                )
              : ListView.builder(
                  itemCount: _playerNames.length,
                  itemBuilder: (context, idx) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1C),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${idx + 1}. ${_playerNames[idx]}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => _removePlayer(idx),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _playerNames.length >= 3
              ? () {
                  _playClickSound();
                  _triggerVibration(durationMs: 30);
                  setState(() {
                    _step = SpyStep.categorySelection;
                  });
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            disabledBackgroundColor: Colors.grey.shade900,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          child: Text(
            'الانتقال لاختيار التصنيف 🎯',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.extrabold,
              color: _playerNames.length >= 3 ? Colors.white : Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }

  // STEP 1.5: Category Selection Screen
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
                setState(() {
                  _step = SpyStep.playersInput;
                });
              },
            ),
            const Text(
              'اختر تصنيف الكلمات 🎭',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.black,
                color: Color(0xFFDC2626),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'اضغط على أحد التصنيفات أدناه لتحميل قائمة الكلمات والبدء فوراً.',
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
                onTap: () => _startGame(cat),
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

  // STEP 2: Pass Phone screen
  Widget _buildPassPhone() {
    final player = _players[_currentPlayerIndex];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(48),
            border: Border.all(color: Colors.white10),
          ),
          child: const Icon(Icons.arrow_forward_rounded, size: 48, color: Color(0xFFDC2626)),
        ),
        const SizedBox(height: 24),
        const Text(
          'مرر الهاتف للاعب التالي:',
          style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.medium),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Text(
            player.name,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.black, color: Colors.white),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'تأكد من عدم رؤية الآخرين للشاشة واضغط الزر لعرض دورك سرياً.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: _handlePlayerRevealClick,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            padding: const EdgeInsets.symmetric(vertical: 16),
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          child: const Text(
            'أنا هو، اعرض دوري 🤫',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // STEP 3: Reveal Role screen
  Widget _buildRevealRole() {
    final player = _players[_currentPlayerIndex];
    final isSpy = player.role == 'SPY';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Text(
          player.name,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.black, color: Colors.white),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: isSpy ? Colors.redAccent.withOpacity(0.3) : Colors.emeraldAccent.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Text(
                isSpy ? '🕵️' : '🎭',
                style: const TextStyle(fontSize: 64),
              ),
              const SizedBox(height: 12),
              Text(
                isSpy ? 'أنت الجاسوس (بره السالفة)!' : 'أنت مواطن داخل اللعبة!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.black,
                  color: isSpy ? Colors.redAccent : Colors.emeraldAccent,
                ),
              ),
              const SizedBox(height: 16),
              if (isSpy) ...[
                const Text(
                  'حاول التظاهر بمعرفة الكلمة، وخمّن ما هي من أسئلة الآخرين دون كشف هويتك!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ] else ...[
                const Text(
                  'الكلمة السرية المشتركة هي:',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedSecretWord,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.black, color: Colors.white),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('التصنيف الحالي: ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(_selectedCategoryName, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: _handlePlayerConfirmSeen,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            padding: const EdgeInsets.symmetric(vertical: 16),
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          child: const Text(
            'فهمت، أخفِ الشاشة 🔒',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // STEP 4: Questioning / Discussion Screen
  Widget _buildQuestioning() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'مرحلة الأسئلة والنقاش 💬',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.black, color: Color(0xFFDC2626)),
        ),
        const SizedBox(height: 4),
        const Text(
          'كل لاعب يوجه سؤالاً واحداً محدداً للاعب الآخر بالترتيب الدائري المعروض بالأسفل:',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 12),

        // Question order carousel list
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
            ),
            child: ListView.builder(
              itemCount: _questionPairs.length,
              itemBuilder: (context, idx) {
                final pair = _questionPairs[idx];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          pair['asker'] ?? '',
                          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Icon(Icons.arrow_back, color: Colors.grey, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'يسأل ${pair['receiver']}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Discussion timer card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_bottom_rounded, size: 16, color: Colors.grey),
                  SizedBox(width: 4),
                  Text('مؤقت المناقشة والحكم الجماعي', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _formatTime(_timerSeconds),
                style: TextStyle(
                  fontSize: 36,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.black,
                  color: _timerSeconds < 15 ? Colors.redAccent : Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _toggleTimer,
                    icon: Icon(_timerActive ? Icons.pause : Icons.play_arrow, size: 16, color: Colors.white),
                    label: Text(_timerActive ? 'إيقاف مؤقت' : 'استئناف', style: const TextStyle(fontSize: 12, color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black45, padding: const EdgeInsets.symmetric(horizontal: 16)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _skipTimer,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black45, padding: const EdgeInsets.symmetric(horizontal: 12)),
                    child: const Text('إنهاء الوقت ⏭️', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _startVoting,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          child: const Text(
            'البدء في التصويت السري 🗳️',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ],
    );
  }

  // STEP 5: Voting Screen (per-player)
  Widget _buildVoting() {
    final voter = _players[_votingPlayerIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'التصويت السري 🗳️',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
        ),
        const SizedBox(height: 4),
        const Text(
          'اختر الشخص المشتبه به الذي تشك بأنه الجاسوس (البكّاس).',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              const Text('اللاعب الحالي المصوّت الآن:', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  voter.name,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.black, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('اختر المشتبه به من القائمة:', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: _players
                .where((p) => p.id != voter.id) // Cannot vote for self
                .map((p) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ElevatedButton(
                        onPressed: () => _handleVoteCast(p.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF161616),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Colors.white12),
                          ),
                        ),
                        child: Text(p.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'اللاعب ${_votingPlayerIndex + 1} من ${_players.length} يدلي بصوته الآن.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
      ],
    );
  }

  // STEP 6: Results Screen
  Widget _buildResults() {
    final citizensWin = _winners == 'CITIZENS';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        if (citizensWin) ...[
          const Center(child: Text('🎉', style: TextStyle(fontSize: 64))),
          const Text(
            'انتصار المواطنين! 🛡️',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.black, color: Colors.emerald),
          ),
          const SizedBox(height: 8),
          const Text(
            'رائع! لقد تكاتفتم وعثرتم على البكّاس الحقيقي وصوّتم ضده بنجاح بالأغلبية!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ] else ...[
          const Center(child: Text('🕵️‍♂️', style: TextStyle(fontSize: 64))),
          const Text(
            'انتصار الجاسوس! 🦊',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.black, color: Color(0xFFDC2626)),
          ),
          const SizedBox(height: 8),
          const Text(
            'مدهش! لقد تمكن الجاسوس من تشتيت الأصوات أو إيقاعكم ببعض ولم تنجحوا في كشف هويته بالأغلبية!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              _buildResultRow('القاتل/الجاسوس الحقيقي كان:', _spyPlayerName, const Color(0xFFDC2626)),
              const Divider(color: Colors.white10),
              _buildResultRow('الأكثر تصويتاً عليه اللاعب:', _mostVotedPlayerName, Colors.orangeAccent),
              const Divider(color: Colors.white10),
              _buildResultRow('الكلمة السرية للجلسة:', _selectedSecretWord, Colors.blueAccent),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'تفاصيل التصويت للاعبين:',
          style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView.builder(
            itemCount: _players.length,
            itemBuilder: (context, idx) {
              final p = _players[idx];
              final isSpy = p.role == 'SPY';
              final vCount = _votes.values.where((v) => v == p.id).length;

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${p.name} ${isSpy ? '🕵️' : ''}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSpy ? const Color(0xFFDC2626) : Colors.white,
                      ),
                    ),
                    Text(
                      '$vCount أصوات 🗳️',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
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
                onPressed: _restartGame,
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

  Widget _buildResultRow(String title, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.medium)),
          Text(
            value,
            style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.black),
          ),
        ],
      ),
    );
  }
}
