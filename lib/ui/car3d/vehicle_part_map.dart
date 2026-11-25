import 'dart:typed_data';
import 'dart:ui' show Path, Rect;

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../domain/models.dart';

/// Which [CarPart] is under each pixel of every pre-rendered vehicle frame.
///
/// The frames and this map are rendered from the same Blender scene
/// (`tool/blender/render_turntable.py`), one set per [VehicleType], so a tap
/// on the photo maps exactly to a part of the damage checklist.
class VehiclePartMap {
  VehiclePartMap._(this.width, this.height, this._frames, this._parts);

  /// Frames of the orbit, 10° apart: 0 = front, 9 = vehicle's left,
  /// 18 = rear, 27 = vehicle's right.
  static const ringFrames = 36;

  /// Index of the plan view, stored after the orbit.
  static const topFrame = ringFrames;

  /// Folder holding the turntable of [type].
  static String assetDir(VehicleType type) => switch (type) {
    VehicleType.car => 'assets/car',
    VehicleType.suv => 'assets/suv',
    VehicleType.pickup => 'assets/pickup',
  };

  static String assetPath(VehicleType type) => '${assetDir(type)}/parts.bin';

  static String frameAsset(VehicleType type, int frame) => frame == topFrame
      ? '${assetDir(type)}/top.webp'
      : '${assetDir(type)}/ring_${frame.toString().padLeft(2, '0')}.webp';

  static final _cache = <String, VehiclePartMap>{};
  static final _loading = <String, Future<VehiclePartMap>>{};

  /// The map of [type], once [load] has completed.
  static VehiclePartMap? cached(VehicleType type) => _cache[assetDir(type)];

  static Future<VehiclePartMap> load(VehicleType type, [AssetBundle? bundle]) =>
      _loading[assetDir(type)] ??= (bundle ?? rootBundle)
          .load(assetPath(type))
          .then((data) => _cache[assetDir(type)] = VehiclePartMap.parse(data));

  /// Parses the run-length encoded file described in
  /// `tool/blender/render_turntable.py`.
  factory VehiclePartMap.parse(ByteData data) {
    if (data.lengthInBytes < 11 || data.getUint32(0) != 0x53555650) {
      throw const FormatException('Not a vehicle part map');
    }
    var o = 4;
    final version = data.getUint8(o++);
    if (version != 1) {
      throw FormatException('Unsupported part map version $version');
    }
    final width = data.getUint16(o, Endian.little);
    final height = data.getUint16(o + 2, Endian.little);
    final frameCount = data.getUint8(o + 4);
    final partCount = data.getUint8(o + 5);
    o += 6;

    final parts = <CarPart?>[null];
    for (var i = 0; i < partCount; i++) {
      final length = data.getUint8(o++);
      final name = String.fromCharCodes([
        for (var k = 0; k < length; k++) data.getUint8(o + k),
      ]);
      o += length;
      parts.add(CarPart.values.asNameMap()[name]);
    }

    final frames = <Uint8List>[];
    for (var f = 0; f < frameCount; f++) {
      final runs = data.getUint32(o, Endian.little);
      o += 4;
      final ids = Uint8List(width * height);
      var p = 0;
      for (var r = 0; r < runs; r++) {
        final length = data.getUint16(o, Endian.little);
        final id = data.getUint8(o + 2);
        o += 3;
        if (id != 0) ids.fillRange(p, p + length, id);
        p += length;
      }
      if (p != ids.length) {
        throw FormatException('Frame $f covers $p of ${ids.length} pixels');
      }
      frames.add(ids);
    }
    return VehiclePartMap._(width, height, frames, parts);
  }

  final int width;
  final int height;
  final List<Uint8List> _frames;

  /// Part for each id; id 0 (background, underbody) is null.
  final List<CarPart?> _parts;

  int get frameCount => _frames.length;

  /// Part at ([u], [v]), both in 0..1 from the frame's top-left corner.
  CarPart? partAt(int frame, double u, double v) {
    if (u < 0 || v < 0 || u >= 1 || v >= 1) return null;
    final x = (u * width).floor(), y = (v * height).floor();
    return _parts[_frames[frame][y * width + x]];
  }

  /// Every part visible in [frame].
  Set<CarPart> partsIn(int frame) {
    final seen = List.filled(_parts.length, false);
    for (final id in _frames[frame]) {
      seen[id] = true;
    }
    return {
      for (var id = 1; id < _parts.length; id++)
        if (seen[id]) ?_parts[id],
    };
  }

  /// Silhouettes of the parts of [frame] in map pixels, one path per group.
  /// [groupOf] returns the group (0 ≤ group < [groups]) of a part, or null
  /// to leave it out.
  List<Path> regions(int frame, int groups, int? Function(CarPart) groupOf) {
    final groupOfId = [
      for (final part in _parts) part == null ? null : groupOf(part),
    ];
    final paths = List.generate(groups, (_) => Path());
    if (groupOfId.every((g) => g == null)) return paths;
    final ids = _frames[frame];
    for (var y = 0; y < height; y++) {
      final row = y * width;
      var x = 0;
      while (x < width) {
        final group = groupOfId[ids[row + x]];
        final start = x++;
        while (x < width && groupOfId[ids[row + x]] == group) {
          x++;
        }
        if (group != null) {
          paths[group].addRect(
            Rect.fromLTRB(start.toDouble(), y.toDouble(), x.toDouble(), y + 1),
          );
        }
      }
    }
    return paths;
  }
}
