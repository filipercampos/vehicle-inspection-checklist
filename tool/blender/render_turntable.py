"""Renders a vehicle turntable used by the app's damage map.

    blender -b --factory-startup -P tool/blender/render_turntable.py

The VEHICLE environment variable picks the Flutter `VehicleType` name
(suv, car, pickup; default suv). ONLY=ring_00,top renders just those photos.
Writes to assets/<VEHICLE>/:
  ring_NN.webp  36 photoreal frames, camera orbiting in 10 degree steps
                (00 = front, 09 = vehicle's left, 18 = rear, 27 = right)
  top.webp      plan view, front of the car pointing right
  parts.bin     per-frame part-id maps (run-length encoded) for hit testing
                and damage highlighting

parts.bin layout (little endian):
  "SUVP", u8 version, u16 width, u16 height, u8 frames, u8 parts,
  parts x (u8 length, ascii CarPart name)        -> id = index + 1, 0 = none
  frames x (u32 run count, runs x (u16 length, u8 id))   rows top to bottom
"""

import math
import os
import struct
import sys
import tempfile

import bpy
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_vehicle  # noqa: E402

KIND = os.environ.get("VEHICLE", "suv")
OUT = os.environ.get("OUT") or os.path.normpath(
    os.path.join(HERE, "..", "..", "assets", KIND))
RING = 36
ID_STEP = 8
ID_SCALE = 50  # percent of the photo resolution


def use_gpu(scene):
    prefs = bpy.context.preferences.addons["cycles"].preferences
    for kind in ("OPTIX", "CUDA"):
        try:
            prefs.compute_device_type = kind
            prefs.get_devices()
        except Exception:
            continue
        found = False
        for d in prefs.devices:
            d.use = d.type == kind
            found = found or d.use
        if found:
            scene.cycles.device = "GPU"
            print("render device", kind)
            return
    print("render device CPU")


def id_material():
    mat = bpy.data.materials.new("veh_part_id")
    try:
        mat.use_nodes = True
    except Exception:
        pass
    nt = mat.node_tree
    nt.nodes.clear()
    info = nt.nodes.new("ShaderNodeObjectInfo")
    div = nt.nodes.new("ShaderNodeMath")
    div.operation = "DIVIDE"
    div.inputs[1].default_value = 255.0 / ID_STEP
    emit = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(info.outputs["Object Index"], div.inputs[0])
    nt.links.new(div.outputs[0], emit.inputs["Color"])
    nt.links.new(emit.outputs[0], out.inputs["Surface"])
    return mat


def read_ids(path, count):
    image = bpy.data.images.load(path)
    w, h = image.size
    px = np.empty(w * h * 4, dtype=np.float32)
    image.pixels.foreach_get(px)
    bpy.data.images.remove(image)
    px = px.reshape(h, w, 4)[::-1]
    ids = np.rint(px[:, :, 0] * 255.0 / ID_STEP).astype(np.int32)
    ids[px[:, :, 3] < 0.5] = 0
    ids[ids > count] = 0
    return ids.astype(np.uint8)


def rle(ids):
    flat = ids.ravel()
    change = np.flatnonzero(np.diff(flat)) + 1
    starts = np.concatenate(([0], change))
    lengths = np.diff(np.concatenate((starts, [flat.size])))
    out = bytearray()
    runs = 0
    for start, length in zip(starts.tolist(), lengths.tolist()):
        value = int(flat[start])
        while length > 0:
            n = min(length, 0xFFFF)
            out += struct.pack("<HB", n, value)
            length -= n
            runs += 1
    return struct.pack("<I", runs) + bytes(out)


def main():
    parts = build_vehicle.build(KIND)
    spec = build_vehicle.SPECS[KIND]
    scene = bpy.data.scenes["Vehicle"]
    layer = scene.view_layers[0]
    col = bpy.data.collections["Vehicle"]
    rig = bpy.data.objects["rig"]
    ring_cam = bpy.data.objects["vehicle_camera"]
    os.makedirs(OUT, exist_ok=True)
    use_gpu(scene)
    scene.render.use_persistent_data = True

    top_data = bpy.data.cameras.new("vehicle_camera_top")
    top_data.lens = 70
    top_cam = bpy.data.objects.new("vehicle_camera_top", top_data)
    col.objects.link(top_cam)
    top_cam.location = (0, 0, 11.6 * spec.view_scale)

    shots = [(f"ring_{k:02d}", ring_cam, math.radians(k * 360 / RING))
             for k in range(RING)]
    # Rig turned so the ground fade is narrow across the plan view too.
    shots.append(("top", top_cam, math.pi / 2))

    top_light = bpy.data.objects["light_top"].data
    top_energy = top_light.energy

    for ob in col.objects:
        part = ob.get("part")
        ob.pass_index = parts.index(part) + 1 if part else 0

    def shoot(name, cam, yaw, path):
        rig.rotation_euler[2] = yaw
        scene.camera = cam
        # The overhead softbox would blow out the roof in the plan view.
        top_light.energy = top_energy * (0.35 if cam is top_cam else 1.0)
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True, scene=scene.name)
        print("rendered", name, flush=True)

    # Beauty pass.
    img = scene.render.image_settings
    img.file_format = "WEBP"
    img.color_mode = "RGBA"
    img.quality = 86
    only = os.environ.get("ONLY")
    for name, cam, yaw in shots:
        if only and name not in only.split(","):
            continue
        shoot(name, cam, yaw, os.path.join(OUT, name + ".webp"))
    if only:
        return

    # Part-id pass: flat emission per object, one sample, no filtering.
    layer.material_override = id_material()
    bpy.data.objects["ground"].hide_render = True
    scene.cycles.samples = 1
    scene.cycles.use_denoising = False
    scene.cycles.pixel_filter_type = "BOX"
    scene.render.dither_intensity = 0.0
    scene.render.resolution_percentage = ID_SCALE
    scene.view_settings.view_transform = "Raw"
    try:
        scene.view_settings.look = "None"
    except TypeError:
        pass
    img.file_format = "PNG"
    img.color_mode = "RGBA"
    img.color_depth = "8"
    img.compression = 15

    tmp = os.path.join(tempfile.gettempdir(), KIND + "_part_id.png")
    frames = []
    for name, cam, yaw in shots:
        shoot(name + " ids", cam, yaw, tmp)
        frames.append(read_ids(tmp, len(parts)))
    os.remove(tmp)

    h, w = frames[0].shape
    seen = sorted({int(v) for f in frames for v in np.unique(f)} - {0})
    missing = [parts[i] for i in range(len(parts)) if i + 1 not in seen]
    print("id map", w, "x", h, "parts seen", len(seen), "missing", missing)

    with open(os.path.join(OUT, "parts.bin"), "wb") as f:
        f.write(b"SUVP")
        f.write(struct.pack("<BHHBB", 1, w, h, len(frames), len(parts)))
        for name in parts:
            raw = name.encode("ascii")
            f.write(struct.pack("<B", len(raw)) + raw)
        for ids in frames:
            f.write(rle(ids))
    print("wrote", OUT, flush=True)


if __name__ == "__main__":
    main()
