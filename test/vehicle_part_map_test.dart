import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_inspection/domain/models.dart';
import 'package:vehicle_inspection/ui/car3d/vehicle_part_map.dart';

void main() {
  for (final type in VehicleType.values) {
    group(type.name, () => _turntable(type));
  }

  test('rejects foreign data', () {
    expect(
      () => VehiclePartMap.parse(ByteData(16)),
      throwsA(isA<FormatException>()),
    );
  });
}

void _turntable(VehicleType type) {
  final bytes = File(VehiclePartMap.assetPath(type)).readAsBytesSync();
  final map = VehiclePartMap.parse(bytes.buffer.asByteData());

  test('holds the whole orbit plus the plan view', () {
    expect(map.frameCount, VehiclePartMap.ringFrames + 1);
  });

  test('every frame has its photo', () {
    for (var f = 0; f < map.frameCount; f++) {
      expect(File(VehiclePartMap.frameAsset(type, f)).existsSync(), isTrue);
    }
  });

  test('every selectable part can be reached from some frame', () {
    final parts = {for (var f = 0; f < map.frameCount; f++) ...map.partsIn(f)};
    final hasBed = type == VehicleType.pickup;
    expect(parts.contains(CarPart.cargoBed), hasBed);
    expect(
      parts,
      containsAll(CarPart.values.where((p) => p != CarPart.cargoBed)),
    );
  });

  test('front view centre hits a front part', () {
    expect(
      map.partAt(0, 0.5, 0.5),
      anyOf(CarPart.frontBumper, CarPart.hood, CarPart.windshield),
    );
  });

  test('plan view centre hits the roof', () {
    expect(map.partAt(VehiclePartMap.topFrame, 0.5, 0.5), CarPart.roof);
  });

  test('side views only show their own side', () {
    final right = map.partsIn(27);
    expect(right, contains(CarPart.doorFrontRight));
    expect(right, contains(CarPart.wheelRearRight));
    expect(right, isNot(contains(CarPart.doorFrontLeft)));

    final left = map.partsIn(9);
    expect(left, contains(CarPart.doorFrontLeft));
    expect(left, isNot(contains(CarPart.doorFrontRight)));
  });

  test('right view: the front of the car is on the right', () {
    double centreU(CarPart part) {
      var sum = 0.0, n = 0;
      for (var x = 0; x < map.width; x++) {
        for (var y = 0; y < map.height; y++) {
          if (map.partAt(27, x / map.width, y / map.height) == part) {
            sum += x / map.width;
            n++;
          }
        }
      }
      return sum / n;
    }

    expect(
      centreU(CarPart.wheelFrontRight),
      greaterThan(centreU(CarPart.wheelRearRight)),
    );
  });

  test('default 3/4 view centre lands on the body', () {
    expect(map.partAt(32, 0.5, 0.5), isNotNull);
  });

  test('outside the car hits nothing', () {
    expect(map.partAt(27, 0.01, 0.01), isNull);
    expect(map.partAt(27, -0.2, 0.5), isNull);
    expect(map.partAt(27, 0.5, 1.2), isNull);
  });

  test('regions cover exactly the requested parts', () {
    final paths = map.regions(
      27,
      1,
      (part) => part == CarPart.doorFrontRight ? 0 : null,
    );
    final bounds = paths.single.getBounds();
    expect(bounds.isEmpty, isFalse);
    final c = bounds.center;
    expect(
      map.partAt(27, c.dx / map.width, c.dy / map.height),
      CarPart.doorFrontRight,
    );
  });
}
