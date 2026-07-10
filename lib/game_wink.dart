import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';

class GameWink extends StatefulWidget {
  final AppSettings settings;
  final VoidCallback onBackToHome;

  const GameWink({
    super.key,
    required this.settings,
    required this.onBackToHome,
  });

  @override
  State<GameWink> createState() => _GameWinkState();
}

enum WinkStep {
  playersInput,
  passPhone,
  revealRole,
  tableStage,
  passPhoneVote,
  voteScreen,
  finalScreen,
}

class _GameWinkState extends State<GameWink> {
  WinkStep _step = WinkStep.playersInput;
  final List<String> _playerNames = [];
  final TextEditingController _nameController = TextEditingController();

  List<WinkPlayer> _players = [];
  int _currentPlayerIndex = 0;

  // Voting state
  int _votingPlayerIndex = 0;
  Map<String, String> _votes = {}; // voterPlayerId -> votedPlayerId

  // Final results
  String _killerName = '';
  String _mostVotedName = '';
  String _winnerTeam = 'CITIZENS'; // 'CITIZENS' | 'KILLER'

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

  void _startGame() {
    if (_playerNames.length < 3) return;
    _playClickSound();
    _triggerVibration(durationMs: 50);

    final random = Random();
    final List<String> shuffledNames = List.from(_playerNames)..shuffle(random);
    final killerIndex = random.nextInt(shuffledNames.length);

    setState(() {
      _players = List.generate(shuffledNames.length, (idx) {
        final isKiller = idx == killerIndex;
        return WinkPlayer(
          id: 'w_$idx',
          name: shuffledNames[idx],
          role: isKiller ? 'KILLER' : 'CITIZEN',
        );
      });
      _currentPlayerIndex = 0;
      _step = WinkStep.passPhone;
    });
  }

  void _togglePlayerAlive(String playerId) {
    _playClickSound();
    _triggerVibration(durationMs: 25);
    setState(() {
      _players = _players.map((p) {
        if (p.id == playerId) {
          return p.copyWith(isAlive: !p.isAlive);
        }
        return p;
      }).toList();
    });
  }

  void _startVotingFlow() {
    _playClickSound();
    _triggerVibration(durationMs: 40);
    setState(() {
      _votingPlayerIndex = 0;
      _votes = {};
      _step = WinkStep.passPhoneVote;
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
        _step = WinkStep.passPhoneVote;
      } else {
        _calculateResults(_votes);
      }
    });
  }

  void _calculateResults(Map<String, String> finalVotes) {
    final Map<String, int> voteCounts = {};
    for (var p in _players) {
      voteCounts[p.id] = 0;
    }

    finalVotes.values.forEach((votedId) {
      if (voteCounts.containsKey(votedId)) {
        voteCounts[votedId] = voteCounts[votedId]! + 1;
      }
    });

    final killer = _players.firstWhere((p) => p.role == 'KILLER');
    _killerName = killer.name;

    int maxVotes = -1;
    String mostVotedId = '';
    bool isTie = false;

    voteCounts.forEach((playerId, count) {
      if (count > maxVotes) {
        maxVotes = count;
        mostVotedId = playerId;
        isTie = false;
      } else if (count == maxVotes) {
        isTie = true;
      }
    });

    final votedPlayer = _players.firstWhere((p) => p.id == mostVotedId, orElse: () => _players.first);
    _mostVotedName = votedPlayer.name;

    // Citizens Win if they vote out the killer (must have maximum votes, no tie)
    final isKillerVotedOut = !isTie && mostVotedId == killer.id;
    if (isKillerVotedOut) {
      _winnerTeam = 'CITIZENS';
    } else {
      _winnerTeam = 'KILLER';
    }

    _triggerVibration(durationMs: 60);
    setState(() {
      _step = WinkStep.finalScreen;
    });
  }

  void _restartGame() {
    _startGame();
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
      case WinkStep.playersInput:
        return _buildPlayersInput();
      case WinkStep.passPhone:
        return _buildPassPhone();
      case WinkStep.revealRole:
        return _buildRevealRole();
      case WinkStep.tableStage:
        return _buildTableStage();
      case WinkStep.passPhoneVote:
        return _buildPassPhoneVote();
      case WinkStep.voteScreen:
        return _buildVoteScreen();
      case WinkStep.finalScreen:
        return _buildFinalScreen();
    }
  }

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
              'الغمزة 😉',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.black, color: Color(0xFFDC2626)),
            ),
            const SizedBox(width: 48),
          ],
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.people_outline, color: Color(0xFFDC2626), size: 22),
                  SizedBox(width: 8),
                  Text('أدخل أسماء اللاعبين (3 - 20)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
                        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white12), borderRadius: BorderRadius.all(Radius.circular(16))),
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFDC2626)), borderRadius: BorderRadius.all(Radius.circular(16))),
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
                        Text('${idx + 1}. ${_playerNames[idx]}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
          onPressed: _playerNames.length >= 3 ? _startGame : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            disabledBackgroundColor: Colors.grey.shade900,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          child: Text(
            'ابدأ اللعبة 🚀',
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
        const Text('مرر الهاتف للاعب التالي:', style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.medium)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
          child: Text(player.name, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.black, color: Colors.white)),
        ),
        const SizedBox(height: 24),
        const Text('تأكد من عدم رؤية الآخرين للشاشة واضغط الزر لعرض دورك سرياً.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
        const Spacer(),
        ElevatedButton(
          onPressed: () {
            _playClickSound();
            _triggerVibration(durationMs: 40);
            setState(() {
              _step = WinkStep.revealRole;
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            padding: const EdgeInsets.symmetric(vertical: 16),
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          child: const Text('أنا هو، اعرض دوري 🤫', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildRevealRole() {
    final player = _players[_currentPlayerIndex];
    final isKiller = player.role == 'KILLER';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Text(player.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.black, color: Colors.white)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: isKiller ? Colors.redAccent.withOpacity(0.3) : Colors.emeraldAccent.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Text(isKiller ? '🔪' : '🛡️', style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              Text(
                isKiller ? 'أنت القاتل الصامت!' : 'أنت مواطن بريء!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.black, color: isKiller ? Colors.redAccent : Colors.emeraldAccent),
              ),
              const SizedBox(height: 16),
              Text(
                isKiller
                    ? 'أنت الغمّاز! يجب عليك قتل اللاعبين تدريجياً عن طريق غمزهم بعينك سرياً دون أن يلاحظك أحد.'
                    : 'راقب حركات عيون الآخرين بحذر لكشف القاتل الغمّاز، وتجنب أن تقع ضحية لغمزاته!',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
        const Spacer(),
        ElevatedButton(
          onPressed: () {
            _playClickSound();
            _triggerVibration(durationMs: 30);
            setState(() {
              if (_currentPlayerIndex < _players.length - 1) {
                _currentPlayerIndex++;
                _step = WinkStep.passPhone;
              } else {
                _step = WinkStep.tableStage;
              }
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            padding: const EdgeInsets.symmetric(vertical: 16),
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          child: const Text('فهمت، أخفِ الشاشة 🔒', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildTableStage() {
    final aliveCount = _players.where((p) => p.isAlive).length;
    final deadCount = _players.where((p) => !p.isAlive).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'الساحة واللعب مستمر 🤫',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.black, color: Color(0xFFDC2626)),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(24)),
          child: const Column(
            children: [
              Text('التعليمات بالساحة:', style: TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('• الكل يتطلع بوجوه الآخرين ويتبادل النظرات.', textAlign: TextAlign.right, style: TextStyle(color: Colors.grey, fontSize: 11)),
              Text('• القاتل يغمز بعينه سرياً لأي مواطن يريد قتله.', textAlign: TextAlign.right, style: TextStyle(color: Colors.grey, fontSize: 11)),
              Text('• إذا تم غمزك، اضغط على اسمك لتغيير حالتك لميت.', textAlign: TextAlign.right, style: TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildCounter('الأحياء 🟢', '$aliveCount', Colors.emerald),
            Container(width: 1, height: 40, color: Colors.white10),
            _buildCounter('المتوفين 🔴', '$deadCount', Colors.redAccent),
          ],
        ),
        const SizedBox(height: 12),
        const Text('قائمة اللاعبين (اضغط على اسمك لإعلان وفاتك):', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Expanded(
          child: ListView.builder(
            itemCount: _players.length,
            itemBuilder: (context, idx) {
              final p = _players[idx];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => _togglePlayerAlive(p.id),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: p.isAlive ? Colors.black38 : Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: p.isAlive ? Colors.white10 : Colors.red.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(p.isAlive ? '⭕' : '💀', style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Text(p.name, style: TextStyle(fontWeight: FontWeight.bold, color: p.isAlive ? Colors.white : Colors.redAccent)),
                          ],
                        ),
                        if (!p.isAlive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                            child: const Text('ميت', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _startVotingFlow,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          child: const Text('بدء التصويت 🗳️', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildPassPhoneVote() {
    final voter = _players[_votingPlayerIndex];
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
          child: const Icon(Icons.people_alt_outlined, size: 48, color: Color(0xFFDC2626)),
        ),
        const SizedBox(height: 24),
        const Text('مرر الهاتف ليدلي بصوته:', style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.medium)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
          child: Text(voter.name, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.black, color: Colors.white)),
        ),
        const SizedBox(height: 24),
        const Text('تأكد من عدم رؤية الآخرين للشاشة واضغط الزر للتصويت.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
        const Spacer(),
        ElevatedButton(
          onPressed: () {
            _playClickSound();
            _triggerVibration(durationMs: 30);
            setState(() {
              _step = WinkStep.voteScreen;
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            padding: const EdgeInsets.symmetric(vertical: 16),
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          child: const Text('أنا هو 🤫', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildVoteScreen() {
    final voter = _players[_votingPlayerIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('صوت المشتبه به للّاعب 🗳️', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
        const SizedBox(height: 4),
        const Text('اختر سرياً اللاعب الذي تشك بأنه القاتل (الغمّاز).', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(24)),
          child: Column(
            children: [
              const Text('اللاعب الحالي الذي يصوت:', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 4),
              Text(voter.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.black, color: Colors.white)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('اختر المشتبه به:', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: _players
                .where((p) => p.id != voter.id) // Cannot vote for yourself
                .map((p) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ElevatedButton(
                        onPressed: () => _handleVoteCast(p.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF161616),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.white12)),
                        ),
                        child: Text(p.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 8),
        Text('لاعب ${_votingPlayerIndex + 1} من ${_players.length} صوتوا حتى الآن.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 11)),
      ],
    );
  }

  Widget _buildFinalScreen() {
    final citizensWin = _winnerTeam == 'CITIZENS';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        if (citizensWin) ...[
          const Center(child: Text('🎉', style: TextStyle(fontSize: 64))),
          const Text('انتصار المواطنين! 🎉', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.black, color: Colors.emerald)),
          const SizedBox(height: 6),
          const Text('رائع! لقد كشفتم القاتل الغمّاز وصوتّم ضده بنجاح بالأغلبية.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
        ] else ...[
          const Center(child: Text('🔪', style: TextStyle(fontSize: 64))),
          const Text('انتصار القاتل! 🔪', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.black, color: Color(0xFFDC2626))),
          const SizedBox(height: 6),
          const Text('عمل مذهل أيها القاتل! لقد تمكنت من تضليلهم ولم يجمعوا أصواتاً كافية ضدك.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF161616), borderRadius: BorderRadius.circular(24)),
          child: Column(
            children: [
              _buildResultRow('القاتل الحقيقي كان:', _killerName, const Color(0xFFDC2626)),
              const Divider(color: Colors.white10),
              _buildResultRow('الأكثر تصويتاً عليه:', _mostVotedName, Colors.orangeAccent),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text('تفاصيل التصويت واللاعبين:', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Expanded(
          child: ListView.builder(
            itemCount: _players.length,
            itemBuilder: (context, idx) {
              final p = _players[idx];
              final isKiller = p.role == 'KILLER';
              final vCount = _votes.values.where((v) => v == p.id).length;

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${p.name} ${isKiller ? '🔪' : ''}', style: TextStyle(fontWeight: FontWeight.bold, color: isKiller ? const Color(0xFFDC2626) : Colors.white)),
                    Text('$vCount أصوات 🗳️', style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text('لعب مجدداً 🔄', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: widget.onBackToHome,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade900, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text('الرئيسية 🏠', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultRow(String title, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.black, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildCounter(String title, String count, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(count, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.black)),
      ],
    );
  }
}
