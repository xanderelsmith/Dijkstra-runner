import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'map_page.dart';

void main() {
  runApp(const DijkstraRunnerApp());
}

class DijkstraRunnerApp extends StatelessWidget {
  const DijkstraRunnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dungeon Chase',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xfff97316),
          secondary: Color(0xff38bdf8),
          surface: Color(0xff1e293b),
        ),
        scaffoldBackgroundColor: const Color(0xff1e293b),
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: const GamePage(),
    );
  }
}

enum AiMode { dijkstra, random }

class GridPos {
  const GridPos(this.row, this.col);

  final int row;
  final int col;

  @override
  bool operator ==(Object other) {
    return other is GridPos && other.row == row && other.col == col;
  }

  @override
  int get hashCode => row.hashCode ^ (col.hashCode << 16);
}

class _Neighbor {
  const _Neighbor(this.pos, this.cost);
  final GridPos pos;
  final int cost;
}

class _Move {
  const _Move(this.dr, this.dc);
  final int dr;
  final int dc;
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage>
    with SingleTickerProviderStateMixin {
  static const int gridSize = 15;
  static const List<List<int>> mapData = [
    [1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    [1, 5, 5, 5, 1, 0, 1, 5, 5, 5, 5, 5, 5, 5, 1],
    [1, 5, 0, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0, 5, 1],
    [1, 5, 0, 1, 5, 5, 1, 1, 1, 1, 1, 0, 1, 5, 1],
    [1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1],
    [0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
    [1, 5, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    [1, 5, 0, 1, 1, 1, 1, 1, 1, 1, 1, 5, 5, 5, 1],
    [1, 5, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 5, 1],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 5, 1],
    [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1],
    [1, 1, 1, 1, 1, 5, 5, 5, 5, 5, 5, 5, 5, 5, 1],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
  ];

  final FocusNode _focusNode = FocusNode();
  final List<_Move> _keyQueue = <_Move>[];
  final Random _rng = Random();

  late final Ticker _ticker;
  Duration _previousTick = Duration.zero;
  double _enemyAccumulatorMs = 0;

  GridPos _player = const GridPos(1, 1);
  GridPos _enemy = const GridPos(13, 13);
  AiMode _aiMode = AiMode.dijkstra;
  List<GridPos> _enemyPath = [];
  bool _gameRunning = true;
  String _statusText = 'Game started. Use WASD or Arrows to move.';

  // How often the enemy moves (in milliseconds). Higher = slower bot.
  // Default is fairly slow so new players have time to react.
  double _enemyIntervalMs = 1000; // 5 seconds per move - significantly slower

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
    _resetGame();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _resetGame() {
    setState(() {
      _player = const GridPos(1, 1);
      _enemy = const GridPos(13, 13);
      _aiMode = AiMode.dijkstra;
      _enemyPath = [];
      _gameRunning = true;
      _statusText = 'Game started. Use WASD or Arrows to move.';
      _keyQueue.clear();
      _enemyAccumulatorMs = 0;
      _previousTick = Duration.zero;
    });
  }

  void _onTick(Duration elapsed) {
    if (!_gameRunning) {
      _previousTick = elapsed;
      return;
    }
    final dt = (elapsed - _previousTick).inMilliseconds;
    _previousTick = elapsed;
    if (dt <= 0) return;

    setState(() {
      _processInputQueue();
      if (_player == _enemy) {
        _endGame(false);
        return;
      }

      _enemyAccumulatorMs += dt;
      if (_enemyAccumulatorMs >= _enemyIntervalMs) {
        _enemyAccumulatorMs -= _enemyIntervalMs;
        _moveEnemy();
        if (_player == _enemy) {
          _endGame(false);
          return;
        }
      }
    });
  }

  void _processInputQueue() {
    if (_keyQueue.isEmpty) {
      return;
    }
    final move = _keyQueue.removeAt(0);
    final next = GridPos(_player.row + move.dr, _player.col + move.dc);
    if (_isWalkable(next)) {
      _player = next;
      _enemyPath = [];
    }
  }

  void _moveEnemy() {
    if (!_gameRunning) return;
    GridPos? nextMove;
    if (_aiMode == AiMode.dijkstra) {
      if (_enemyPath.isEmpty) {
        _enemyPath = _findShortestPath(_enemy, _player);
      }
      if (_enemyPath.isNotEmpty) {
        nextMove = _enemyPath.removeAt(0);
      }
    } else {
      final neighbors = _neighbors(_enemy);
      if (neighbors.isNotEmpty) {
        int smallest = 1 << 20;
        for (final neighbor in neighbors) {
          final dist =
              (neighbor.row - _player.row).abs() +
              (neighbor.col - _player.col).abs();
          if (dist < smallest || (dist == smallest && _rng.nextBool())) {
            smallest = dist;
            nextMove = neighbor;
          }
        }
      }
    }
    if (nextMove != null) {
      _enemy = nextMove;
    }
  }

  bool _isWalkable(GridPos pos) {
    return pos.row >= 0 &&
        pos.row < gridSize &&
        pos.col >= 0 &&
        pos.col < gridSize &&
        mapData[pos.row][pos.col] != 0;
  }

  List<GridPos> _neighbors(GridPos node) {
    final result = <GridPos>[];
    const dirs = <_Move>[_Move(-1, 0), _Move(1, 0), _Move(0, -1), _Move(0, 1)];
    for (final d in dirs) {
      final next = GridPos(node.row + d.dr, node.col + d.dc);
      if (_isWalkable(next)) {
        result.add(next);
      }
    }
    return result;
  }

  List<_Neighbor> _neighborsWithCost(GridPos node) {
    final result = <_Neighbor>[];
    const dirs = <_Move>[_Move(-1, 0), _Move(1, 0), _Move(0, -1), _Move(0, 1)];
    for (final d in dirs) {
      final next = GridPos(node.row + d.dr, node.col + d.dc);
      if (_isWalkable(next)) {
        result.add(_Neighbor(next, mapData[next.row][next.col]));
      }
    }
    return result;
  }

  List<GridPos> _findShortestPath(GridPos start, GridPos goal) {
    final distances = List.generate(
      gridSize,
      (_) => List.filled(gridSize, double.infinity),
    );
    final predecessors = List.generate(
      gridSize,
      (_) => List<GridPos?>.filled(gridSize, null, growable: false),
    );
    final unvisited = <String>{};

    String key(GridPos pos) => '${pos.row},${pos.col}';

    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        unvisited.add('$r,$c');
      }
    }
    distances[start.row][start.col] = 0;

    GridPos? smallestNode() {
      double smallest = double.infinity;
      GridPos? best;
      for (final k in unvisited) {
        final parts = k.split(',');
        final r = int.parse(parts[0]);
        final c = int.parse(parts[1]);
        final dist = distances[r][c];
        if (dist < smallest) {
          smallest = dist;
          best = GridPos(r, c);
        }
      }
      return best;
    }

    while (true) {
      final current = smallestNode();
      if (current == null) break;
      final curKey = key(current);
      if (distances[current.row][current.col] == double.infinity) break;
      if (current == goal) break;
      unvisited.remove(curKey);

      for (final neighbor in _neighborsWithCost(current)) {
        if (!unvisited.contains(key(neighbor.pos))) continue;
        final newDist = distances[current.row][current.col] + neighbor.cost;
        if (newDist < distances[neighbor.pos.row][neighbor.pos.col]) {
          distances[neighbor.pos.row][neighbor.pos.col] = newDist;
          predecessors[neighbor.pos.row][neighbor.pos.col] = current;
        }
      }
    }

    final path = <GridPos>[];
    GridPos? cursor = goal;
    if (predecessors[goal.row][goal.col] == null && goal != start) {
      return path;
    }
    while (cursor != null && cursor != start) {
      path.add(cursor);
      cursor = predecessors[cursor.row][cursor.col];
    }
    return path.reversed.toList();
  }

  void _endGame(bool won) {
    _gameRunning = false;
    _statusText = won
        ? '🎉 YOU ESCAPED! Click Reset to play again.'
        : '☠️ CAUGHT! The Enemy (${_aiMode == AiMode.dijkstra ? 'DIJKSTRA' : 'RANDOM'}) won. Click Reset.';

    // Show game over dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _showGameOverDialog(won);
      }
    });
  }

  void _showGameOverDialog(bool won) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xff1e293b),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: won ? const Color(0xff22c55e) : const Color(0xffef4444),
              width: 3,
            ),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                won ? '🎉 VICTORY!' : '☠️ GAME OVER',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: won
                      ? const Color(0xff22c55e)
                      : const Color(0xffef4444),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                won
                    ? 'Congratulations! You successfully escaped the enemy!'
                    : 'The Enemy (${_aiMode == AiMode.dijkstra ? 'DIJKSTRA' : 'RANDOM'}) caught you!',
                style: const TextStyle(fontSize: 16, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xff334155),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xff475569)),
                ),
                child: Column(
                  children: [
                    Text(
                      'AI Mode: ${_aiMode == AiMode.dijkstra ? 'Smart Chase (Dijkstra)' : 'Random Chase'}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enemy Speed: ${(_enemyIntervalMs / 1000).toStringAsFixed(1)}s per move',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetGame();
              },
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xfff97316),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Play Again',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _toggleAiMode() {
    setState(() {
      _aiMode = _aiMode == AiMode.dijkstra ? AiMode.random : AiMode.dijkstra;
      _enemyPath = [];
    });
  }

  void _showCarAnimationInfo() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xff0f172a),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Flutter Demo Flow: Car Animation',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'This demo explains how to animate a car marker along an optimal path, '
                    'building directly on a route calculated with Dijkstra.',
                  ),
                  SizedBox(height: 16),
                  Text(
                    '1) Route Calculation (The Dijkstra Step)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Call your routing API with start and end LatLng coordinates.\n'
                    '• The backend runs Dijkstra on the road network and returns a list of '
                    'LatLngs forming the optimal polyline route.',
                  ),
                  SizedBox(height: 12),
                  Text(
                    '2) Polyline Drawing',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Feed the returned coordinates into a PolylineLayer (e.g. in flutter_map).\n'
                    '• This draws the route line on the map—the same optimal path that Dijkstra found.',
                  ),
                  SizedBox(height: 12),
                  Text(
                    '3) Marker Animation (The Demo Step)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Animate a custom car marker along the polyline by iterating over the coordinates '
                    'with an AnimationController (or a package like animated_marker).\n'
                    '• On each animation tick, move the marker to the next coordinate.\n'
                    '• Optionally compute the bearing between successive points to rotate the car '
                    'so it faces the direction of travel.\n\n'
                    'This shows the car visually following the exact optimal path calculated by the algorithm.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _handleKey(RawKeyEvent event) {
    if (!_gameRunning || event is! RawKeyDownEvent) return;
    final key = event.logicalKey;
    _Move? move;
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
      move = const _Move(-1, 0);
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.keyS) {
      move = const _Move(1, 0);
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.keyA) {
      move = const _Move(0, -1);
    } else if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      move = const _Move(0, 1);
    }
    if (move != null) {
      _keyQueue.add(move);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 1000;
    return Scaffold(
      body: RawKeyboardListener(
        focusNode: _focusNode,
        onKey: _handleKey,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dungeon Chase: Dijkstra AI Game',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xfff97316),
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Use WASD or Arrows to move the Player (P). '
                      'The Enemy (E) will chase you. Switch the AI mode below!',
                      style: TextStyle(color: Color(0xffcbd5f5)),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: isWide
                          ? _buildWideLayout()
                          : _buildStackedLayout(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 320, child: _buildControlPanel()),
        const SizedBox(width: 24),
        Expanded(
          child: Stack(
            children: [
              _buildCanvas(),
              // Directional controller overlay
              Positioned(
                bottom: 16,
                right: 16,
                child: _buildDirectionalController(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStackedLayout() {
    return Stack(
      children: [
        ListView(
          children: [
            _buildCanvas(),
            const SizedBox(height: 24),
            _buildControlPanel(),
          ],
        ),
        // Directional controller overlay
        Positioned(bottom: 16, right: 16, child: _buildDirectionalController()),
      ],
    );
  }

  Widget _buildControlPanel() {
    final aiIsDijkstra = _aiMode == AiMode.dijkstra;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff334155),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xff475569)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Enemy AI Mode',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xfffb923c),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: aiIsDijkstra
                  ? const Color(0xff22c55e)
                  : const Color(0xffef4444),
              foregroundColor: aiIsDijkstra
                  ? const Color(0xff0f172a)
                  : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: _gameRunning ? _toggleAiMode : null,
            child: Text(
              aiIsDijkstra ? 'AI: SMART CHASE (Dijkstra)' : 'AI: RANDOM CHASE',
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Enemy Speed',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text(
                'Fast',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              Expanded(
                child: Slider(
                  // Smaller interval = faster, larger = slower.
                  min: 1000,
                  max:
                      30000, // Increased max to 30 seconds for very slow speeds
                  divisions: 29,
                  value: _enemyIntervalMs.clamp(1000, 30000),
                  label: '${(_enemyIntervalMs / 1000).toStringAsFixed(1)}s',
                  onChanged: (value) {
                    setState(() {
                      _enemyIntervalMs = value;
                    });
                  },
                ),
              ),
              const Text(
                'Slow',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff6b7280),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: _resetGame,
            child: const Text('Reset Game'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff3b82f6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: _showCarAnimationInfo,
            child: const Text('Car Animation Demo Flow'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff10b981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MapPage()),
              );
            },
            child: const Text('Open Real-World Map'),
          ),
          const SizedBox(height: 24),
          const Text(
            'Current Status',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xfffb923c),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xff1e293b),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xff475569)),
            ),
            child: Text(
              _statusText,
              style: const TextStyle(color: Color(0xfffed7aa), fontSize: 13),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Legend',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xfffb923c),
            ),
          ),
          const SizedBox(height: 12),
          _legendEntry(
            color: const Color(0xfff59e0b),
            label: 'Player (P)',
            isCircle: true,
          ),
          _legendEntry(
            color: const Color(0xffef4444),
            label: 'Enemy (E)',
            isCircle: true,
          ),
          _legendEntry(color: const Color(0xff90ee90), label: 'Grass (Cost 1)'),
          _legendEntry(color: const Color(0xff8b4513), label: 'Swamp (Cost 5)'),
          _legendEntry(
            color: const Color(0xff1a1a2e),
            label: 'Wall (Cost 0 - Impassable)',
            borderColor: const Color(0xff475569),
          ),
        ],
      ),
    );
  }

  Widget _legendEntry({
    required Color color,
    required String label,
    bool isCircle = false,
    Color? borderColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
              border: borderColor == null
                  ? null
                  : Border.all(color: borderColor),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xfff97316), width: 4),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 15,
              offset: Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(
          painter: GamePainter(
            mapData: mapData,
            player: _player,
            enemy: _enemy,
            aiMode: _aiMode,
            enemyPath: _enemyPath,
          ),
        ),
      ),
    );
  }

  Widget _buildDirectionalController() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: const Color(0xff334155).withOpacity(0.9),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xfff97316), width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Stack(
        children: [
          // Center button (optional - could be used for special action)
          Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xff475569),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Up button
          Positioned(
            top: 8,
            left: 50,
            child: _buildDirectionButton(
              icon: Icons.arrow_upward,
              onTap: () => _handleDirectionalMove(const _Move(-1, 0)),
            ),
          ),
          // Down button
          Positioned(
            bottom: 8,
            left: 50,
            child: _buildDirectionButton(
              icon: Icons.arrow_downward,
              onTap: () => _handleDirectionalMove(const _Move(1, 0)),
            ),
          ),
          // Left button
          Positioned(
            left: 8,
            top: 50,
            child: _buildDirectionButton(
              icon: Icons.arrow_back,
              onTap: () => _handleDirectionalMove(const _Move(0, -1)),
            ),
          ),
          // Right button
          Positioned(
            right: 8,
            top: 50,
            child: _buildDirectionButton(
              icon: Icons.arrow_forward,
              onTap: () => _handleDirectionalMove(const _Move(0, 1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _gameRunning ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _gameRunning
                ? const Color(0xfff97316)
                : const Color(0xff6b7280),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  void _handleDirectionalMove(_Move move) {
    if (!_gameRunning) return;
    _keyQueue.add(move);
  }
}

class GamePainter extends CustomPainter {
  GamePainter({
    required this.mapData,
    required this.player,
    required this.enemy,
    required this.aiMode,
    required this.enemyPath,
  });

  final List<List<int>> mapData;
  final GridPos player;
  final GridPos enemy;
  final AiMode aiMode;
  final List<GridPos> enemyPath;

  // Color Reference - All pixel colors used in the game:
  //
  // TILE COLORS:
  // - Wall:      #1a1a2e (RGB: 26, 26, 46) - Dark blue-gray
  // - Swamp:     #8b4513 (RGB: 139, 69, 19) - Brown/Saddle Brown
  // - Grass:     #90ee90 (RGB: 144, 238, 144) - Light Green
  //
  // BORDER COLORS:
  // - Wall border:  #475569 (RGB: 71, 85, 105) - Slate-600
  // - Tile border:  #334155 (RGB: 51, 65, 85) - Slate-700
  //
  // TEXT COLORS:
  // - Grass text:   #1a1a2e (RGB: 26, 26, 46) - Dark text on light green
  // - Swamp text:   #ffffff (RGB: 255, 255, 255) - White text on brown
  //
  // TOKEN COLORS:
  // - Player:       #f59e0b (RGB: 245, 158, 11) - Amber-500
  // - Enemy:        #ef4444 (RGB: 239, 68, 68) - Red-500
  // - Token text:   #1e293b (RGB: 30, 41, 59) - Slate-800
  //
  // PATH VISUALIZATION:
  // - Dijkstra path: #3b82f6 with 88 alpha (RGB: 59, 130, 246, 136) - Blue overlay

  static const Color wallColor = Color(0xff1a1a2e); // Dark blue-gray for walls
  static const Color swampColor = Color(0xff8b4513); // Brown for swamp
  static const Color grassColor = Color(0xff90ee90); // Light green for grass

  @override
  void paint(Canvas canvas, Size size) {
    final tileSize = size.width / mapData.length;
    final paint = Paint();
    final pathCells = enemyPath.toSet();

    for (int r = 0; r < mapData.length; r++) {
      for (int c = 0; c < mapData[r].length; c++) {
        final rect = Rect.fromLTWH(
          c * tileSize,
          r * tileSize,
          tileSize,
          tileSize,
        );
        final tile = mapData[r][c];
        if (tile == 0) {
          paint.color = const Color.fromARGB(255, 203, 33, 163);
        } else if (tile == 5) {
          paint.color = swampColor;
        } else {
          paint.color = grassColor;
        }
        canvas.drawRect(rect, paint);

        if (aiMode == AiMode.dijkstra && pathCells.contains(GridPos(r, c))) {
          paint.color = const Color(0x883b82f6);
          canvas.drawRect(rect, paint);
        }

        // Use darker border for better contrast on colored tiles
        paint.color = tile == 0
            ? const Color(0xff475569) // Lighter border on dark walls
            : const Color(0xff334155); // Dark border on colored tiles
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawRect(rect, paint);

        if (tile != 0) {
          // Draw a small "pixel" rectangle instead of text to indicate cost.
          // Grass (1) gets a light pixel, swamp (5) gets a dark pixel.
          final double pixelSize = tileSize * 0.18;
          final Rect pixelRect = Rect.fromCenter(
            center: Offset(
              rect.left + tileSize / 2,
              rect.top + tileSize * 0.22,
            ),
            width: pixelSize,
            height: pixelSize,
          );
          paint
            ..style = PaintingStyle.fill
            ..color = tile == 5
                ? const Color(0xff020617) // very dark pixel on swamp
                : const Color(0xffffffff); // white pixel on grass
          canvas.drawRRect(
            RRect.fromRectAndRadius(pixelRect, const Radius.circular(2)),
            paint,
          );
        }
      }
    }
    _drawToken(canvas, player, tileSize, const Color(0xfff59e0b), 'P');
    _drawToken(canvas, enemy, tileSize, const Color(0xffef4444), 'E');
  }

  void _drawToken(
    Canvas canvas,
    GridPos pos,
    double tileSize,
    Color color,
    String label,
  ) {
    final center = Offset(
      pos.col * tileSize + tileSize / 2,
      pos.row * tileSize + tileSize / 2,
    );
    final paint = Paint()..color = color;
    canvas.drawCircle(center, tileSize / 3, paint);
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xff1e293b),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) {
    return oldDelegate.player != player ||
        oldDelegate.enemy != enemy ||
        oldDelegate.aiMode != aiMode ||
        oldDelegate.enemyPath != enemyPath;
  }
}
