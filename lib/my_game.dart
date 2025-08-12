// lib/my_game.dart
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MyGame extends FlameGame
    with DragCallbacks, TapCallbacks, KeyboardEvents {
  late SpriteComponent background;
  late Basket basket;
  late TextComponent scoreText;
  late TextComponent livesText;
  TextComponent? gameOverText;

  int score = 0;
  int lives = 3;
  bool isGameOver = false;

  final Random random = Random();
  final List<String> fruitImages = ['apple.png', 'banana.png', 'orange.png'];

  late Timer spawnTimer;
  final double spawnInterval = 1.0; // spawn every 1 sec

  Set<LogicalKeyboardKey> _keysPressed = {};
  final double basketSpeed = 400; // px/sec

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Background
    background = SpriteComponent()
      ..sprite = await loadSprite('background.png')
      ..size = size
      ..position = Vector2.zero()
      ..anchor = Anchor.topLeft;
    add(background);

    // Basket (bigger)
    basket = Basket()
      ..sprite = await loadSprite('basket.png')
      ..size = Vector2(200, 120)
      ..anchor = Anchor.center
      ..position = Vector2(size.x / 2, size.y - 80);
    add(basket);

    // Score text
    scoreText = TextComponent(
      text: 'Score: 0',
      position: Vector2(12, 12),
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.white, fontSize: 20),
      ),
      priority: 100,
    );
    add(scoreText);

    // Lives text
    livesText = TextComponent(
      text: 'Lives: $lives',
      position: Vector2(size.x - 12, 12),
      anchor: Anchor.topRight,
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.white, fontSize: 20),
      ),
      priority: 100,
    );
    add(livesText);

    // Spawn timer
    spawnTimer = Timer(
      spawnInterval,
      repeat: true,
      onTick: () {
        if (!isGameOver) spawnFruit();
      },
    )..start();
  }

  Future<void> spawnFruit() async {
    final path = fruitImages[random.nextInt(fruitImages.length)];
    final sprite = await loadSprite(path);

    final double w = 90; // bigger fruit
    final posX = random.nextDouble() * (size.x - w) + w / 2;

    final fruit = Fruit(
      sprite: sprite,
      position: Vector2(posX, -50),
      size: Vector2(w, w),
      vy: 100, // constant slow start
      gravity: 50, // small acceleration
      angularSpeed: (random.nextDouble() - 0.5) * 1.5,
    );

    add(fruit);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!isGameOver) {
      spawnTimer.update(dt);
    }

    // Keyboard movement
    if (!isGameOver && _keysPressed.isNotEmpty) {
      double dx = 0;
      if (_keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
          _keysPressed.contains(LogicalKeyboardKey.keyA)) {
        dx -= 1;
      }
      if (_keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
          _keysPressed.contains(LogicalKeyboardKey.keyD)) {
        dx += 1;
      }
      if (dx != 0) {
        basket.position.x += dx * basketSpeed * dt;
        _clampBasketInside();
      }
    }
  }

  void _clampBasketInside() {
    final halfW = basket.size.x / 2;
    basket.position.x =
        basket.position.x.clamp(halfW, size.x - halfW);
  }

  void onFruitCaught(Fruit fruit) {
    score++;
    scoreText.text = 'Score: $score';
  }

  void onFruitMissed(Fruit fruit) {
    lives--;
    livesText.text = 'Lives: $lives';
    if (lives <= 0) {
      _showGameOver();
    }
  }

  void _showGameOver() {
    isGameOver = true;
    spawnTimer.stop();

    gameOverText = TextComponent(
      text: 'GAME OVER\nTap to Restart',
      anchor: Anchor.center,
      position: size / 2,
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 36,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      priority: 200,
    );
    add(gameOverText!);
  }

  void restartGame() {
    // Remove all fruits
    children.whereType<Fruit>().toList().forEach((f) => f.removeFromParent());

    // Remove game over text
    gameOverText?.removeFromParent();
    gameOverText = null;

    score = 0;
    lives = 3;
    isGameOver = false;
    scoreText.text = 'Score: 0';
    livesText.text = 'Lives: 3';

    spawnTimer = Timer(
      spawnInterval,
      repeat: true,
      onTick: () {
        if (!isGameOver) spawnFruit();
      },
    )..start();
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (isGameOver) restartGame();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (!isGameOver) {
      basket.position.x += event.localDelta.x;
      _clampBasketInside();
    }
  }

  @override
  KeyEventResult onKeyEvent(
      KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _keysPressed = keysPressed;
    return KeyEventResult.handled;
  }
}

class Basket extends SpriteComponent {}

class Fruit extends SpriteComponent with HasGameRef<MyGame> {
  double vy;
  double gravity;
  double angularSpeed;

  Fruit({
    required Sprite sprite,
    required Vector2 position,
    required Vector2 size,
    this.vy = 100,
    this.gravity = 50,
    this.angularSpeed = 1.0,
  }) : super(sprite: sprite, position: position, size: size, anchor: Anchor.center);

  @override
  void update(double dt) {
    super.update(dt);

    vy += gravity * dt; // Falling motion
    position.y += vy * dt;

    angle += angularSpeed * dt; // Rotation

    // Collision with basket
    if (toRect().overlaps(gameRef.basket.toRect())) {
      gameRef.onFruitCaught(this);
      removeFromParent();
      return;
    }

    // Missed fruit
    if (position.y - size.y / 2 > gameRef.size.y) {
      gameRef.onFruitMissed(this);
      removeFromParent();
    }
  }
}
