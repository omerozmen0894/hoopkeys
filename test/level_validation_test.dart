import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_drop_arena/main.dart';

void main() {
  test('all levels use sane playable geometry', () {
    expect(GameLevel.samples, hasLength(100));

    for (final level in GameLevel.samples) {
      expect(
        level.dropX,
        inInclusiveRange(0.08, 0.92),
        reason: 'B${level.index + 1} dropX saha disinda',
      );
      expect(
        level.goal.left,
        inInclusiveRange(0.04, 0.88),
        reason: 'B${level.index + 1} pota solu hatali',
      );
      expect(
        level.goal.right,
        inInclusiveRange(0.12, 0.96),
        reason: 'B${level.index + 1} pota sagi hatali',
      );
      expect(
        level.goal.top,
        inInclusiveRange(0.82, 0.93),
        reason: 'B${level.index + 1} pota yuksekligi hatali',
      );

      final startLane = Rect.fromLTWH(level.dropX - 0.08, 0.12, 0.16, 0.18);
      for (final obstacle in level.obstacles) {
        final rect = obstacle.normalized;
        expect(
          rect.left,
          greaterThanOrEqualTo(0.04),
          reason: 'B${level.index + 1} ${obstacle.id} soldan tasiyor',
        );
        expect(
          rect.right,
          lessThanOrEqualTo(0.96),
          reason: 'B${level.index + 1} ${obstacle.id} sagdan tasiyor',
        );
        expect(
          rect.top,
          greaterThanOrEqualTo(0.10),
          reason: 'B${level.index + 1} ${obstacle.id} ustten tasiyor',
        );
        expect(
          rect.bottom,
          lessThanOrEqualTo(0.84),
          reason: 'B${level.index + 1} ${obstacle.id} alttan tasiyor',
        );
        expect(
          rect.inflate(0.06).overlaps(level.goal),
          isFalse,
          reason: 'B${level.index + 1} ${obstacle.id} potayi kapatiyor',
        );
        expect(
          rect.inflate(0.02).overlaps(startLane),
          isFalse,
          reason: 'B${level.index + 1} ${obstacle.id} baslangici kapatiyor',
        );
      }

      for (final key in level.keyTargets) {
        expect(
          key.dx,
          inInclusiveRange(0.08, 0.92),
          reason: 'B${level.index + 1} anahtar x hatali',
        );
        expect(
          key.dy,
          inInclusiveRange(0.10, 0.84),
          reason: 'B${level.index + 1} anahtar y hatali',
        );
      }
    }
  });

  test('all levels survive a basic physics smoke run', () {
    for (final level in GameLevel.samples) {
      final run = GameRun(level: level);
      final target = level.goal.center - run.ball;
      run.shoot(Offset(target.dx * 0.65, target.dy * 0.95));

      for (var frame = 0; frame < 360; frame++) {
        run.step(1 / 60);
        expect(
          run.ball.dx.isFinite,
          isTrue,
          reason: 'B${level.index + 1} ball.dx bozuldu',
        );
        expect(
          run.ball.dy.isFinite,
          isTrue,
          reason: 'B${level.index + 1} ball.dy bozuldu',
        );
        expect(
          run.velocity.dx.isFinite,
          isTrue,
          reason: 'B${level.index + 1} velocity.dx bozuldu',
        );
        expect(
          run.velocity.dy.isFinite,
          isTrue,
          reason: 'B${level.index + 1} velocity.dy bozuldu',
        );
        expect(
          run.ball.dx,
          inInclusiveRange(0.0, 1.0),
          reason: 'B${level.index + 1} top yatayda sahadan cikti',
        );
        expect(
          run.ball.dy,
          lessThanOrEqualTo(1.05),
          reason: 'B${level.index + 1} top alttan sahadan cikti',
        );
        if (run.won || run.failed) break;
      }

      expect(
        run.trail.length,
        lessThanOrEqualTo(18),
        reason: 'B${level.index + 1} iz listesi buyuyor',
      );
    }
  });

  test('power-up jokers apply visible gameplay effects', () {
    final routeRun = GameRun(level: GameLevel.samples.first);
    final routeVelocityBefore = routeRun.velocity;
    routeRun.addControlJoker();
    expect(routeRun.velocity, isNot(routeVelocityBefore));
    expect(routeRun.guideSeconds, greaterThan(0));

    const breakerLevel = GameLevel(
      index: 998,
      name: 'Breaker Test',
      hint: 'test',
      dropX: 0.30,
      startVX: 0,
      goal: Rect.fromLTWH(0.62, 0.88, 0.22, 0.06),
      obstacles: [
        GameObstacle(
          id: 'wall',
          kind: ObstacleKind.wall,
          normalized: Rect.fromLTWH(0.40, 0.42, 0.24, 0.04),
        ),
      ],
    );
    final breakerRun = GameRun(level: breakerLevel);
    breakerRun.addBreakerJoker();
    expect(breakerRun.obstacles.single.open, isTrue);

    const gateLevel = GameLevel(
      index: 999,
      name: 'Gate Test',
      hint: 'test',
      dropX: 0.30,
      startVX: 0,
      goal: Rect.fromLTWH(0.62, 0.88, 0.22, 0.06),
      obstacles: [
        GameObstacle(
          id: 'gate',
          kind: ObstacleKind.gate,
          normalized: Rect.fromLTWH(0.40, 0.42, 0.24, 0.04),
        ),
      ],
    );
    final gateRun = GameRun(level: gateLevel);
    gateRun.openGateJoker();
    expect(gateRun.obstacles.single.open, isTrue);
  });
}
