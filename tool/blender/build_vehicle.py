"""Builds the inspection vehicles used by the app's damage map.

Run inside Blender 5.2+ (live session or `blender -b -P build_vehicle.py`).
Everything lives in a dedicated "Vehicle" scene/collection, so the script can
be re-run and never touches other data in the file.

Axes: +X = front, +Y = vehicle's left, +Z = up. Units are metres.
Every selectable object carries a custom property `part` holding the name of
the matching `CarPart` enum value in the Flutter app.

One body builder serves every vehicle type; the shape comes from a spec in
SPECS, keyed by the Flutter `VehicleType` name.
"""

import math
import os
from types import SimpleNamespace

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROWS = 12  # points per half section, floor centre -> roof centre

SIDED = {"fenderFront", "doorFront", "doorRear", "quarterRear", "windows"}


def const(v):
    return lambda s: v


def ramp(v, k):
    return lambda s: v + k * s


SPECS = {
    "suv": SimpleNamespace(
        half_width=0.93, plan_length=2.40, plan_power=6.0,
        axles=(1.42, -1.38), wheel_r=0.36, arch_r=0.46, track=0.78,
        stations=[
            -2.30, -2.22, -2.10, -1.98, -1.70, -1.38, -1.05, -0.85, -0.80,
            -0.75, -0.40, -0.03, 0.02, 0.07, 0.42, 0.62, 0.86, 1.15, 1.32,
            1.60, 1.90, 2.10, 2.22, 2.30,
        ],
        # Top of the lower body (hood line, window sill, tailgate top).
        belt=[
            (-2.30, 1.07), (-2.22, 1.13), (-1.40, 1.14), (0.0, 1.11),
            (1.15, 1.07), (1.90, 1.045), (2.20, 1.00), (2.30, 0.97),
        ],
        # Greenhouse height above the belt.
        cabin=[
            (-2.22, 0.0), (-1.98, 0.45), (-1.50, 0.52), (-0.30, 0.54),
            (0.42, 0.49), (1.15, 0.0),
        ],
        sill_z=0.30, side_z=0.66, end_x=1.9, end_span=0.4,
        # Panel boundaries along x.
        hood_x=1.15, tail_x=-2.22, windshield_x=0.42, rear_glass_x=-1.98,
        fender_x=0.86, quarter_x=-1.70, door_split=0.02, rear_door_x=-0.80,
        pillars=[(-0.03, 0.07), (-0.85, -0.75)],
        front_corner=1.95, rear_corner=-2.0,
        paint=(0.27, 0.31, 0.37), pivot=1.3,
        # (angle from, angle to, lower edge, upper edge) per lamp.
        headlight=(17, 52, ramp(0.815, 0.03), ramp(0.895, 0.03)),
        drl=(17.5, 51, ramp(0.876, 0.03), ramp(0.889, 0.03)),
        taillight=(20, 56, ramp(0.91, -0.01), ramp(1.01, 0.02)),
        # name, part, finish, front, half angle, z lo, z hi, grid, kwargs
        patches=[
            ("grille", "frontBumper", "blackGloss", True, 12.5, 0.63, 0.875,
             (20, 8), dict(lift=0.002)),
            ("intake", "frontBumper", "blackGloss", True, 19, 0.385, 0.47,
             (24, 3), dict(lift=0.002)),
            ("plate_front", "frontBumper", "plate", True, 5.2, 0.495, 0.585,
             (6, 2), dict(lift=0.006, thickness=0.004)),
            ("light_bar", "tailgate", "taillight", False, 19, 0.955, 0.98,
             (20, 1), dict(lift=0.003, thickness=0.006)),
            ("plate_rear", "tailgate", "plate", False, 5.2, 0.73, 0.83,
             (6, 2), dict(lift=0.006, thickness=0.004)),
            ("skid_rear", "rearBumper", "rim", False, 13, 0.375, 0.43,
             (14, 2), dict(lift=0.004)),
        ],
        handles={"doorFront": (0.10, 0.27), "doorRear": (-0.72, -0.55)},
        handle_drop=0.165,
        mirror=(1.0, 0.955, 1.18, 1.0),
        roof_rail=(-1.72, 0.18, 0.575), cladding=True, bed=None,
        rig_z=0.78, view_scale=1.0,
    ),
    # Five-door hatchback.
    "car": SimpleNamespace(
        half_width=0.89, plan_length=2.14, plan_power=6.0,
        axles=(1.20, -1.40), wheel_r=0.315, arch_r=0.385, track=0.755,
        stations=[
            -2.05, -2.00, -1.92, -1.82, -1.62, -1.40, -1.25, -1.00, -0.95,
            -0.90, -0.55, -0.13, -0.08, -0.03, 0.30, 0.50, 0.72, 1.05, 1.20,
            1.45, 1.72, 1.88, 1.98, 2.05,
        ],
        belt=[
            (-2.05, 0.84), (-2.00, 0.90), (-1.30, 0.93), (0.0, 0.90),
            (1.05, 0.865), (1.72, 0.80), (1.98, 0.73), (2.05, 0.70),
        ],
        cabin=[
            (-2.00, 0.0), (-1.62, 0.43), (-1.20, 0.50), (-0.30, 0.52),
            (0.30, 0.47), (1.05, 0.0),
        ],
        sill_z=0.21, side_z=0.52, end_x=1.70, end_span=0.35,
        hood_x=1.05, tail_x=-2.00, windshield_x=0.30, rear_glass_x=-1.62,
        fender_x=0.72, quarter_x=-1.25, door_split=-0.08, rear_door_x=-0.95,
        pillars=[(-0.13, -0.03), (-1.00, -0.90)],
        front_corner=1.78, rear_corner=-1.82,
        paint=(0.035, 0.10, 0.30), pivot=1.05,
        headlight=(15, 54, ramp(0.60, 0.035), ramp(0.675, 0.04)),
        drl=(15.5, 53, ramp(0.658, 0.04), ramp(0.669, 0.04)),
        taillight=(25, 47, ramp(0.70, 0.0), ramp(0.85, 0.02)),
        patches=[
            ("grille", "frontBumper", "blackGloss", True, 13, 0.615, 0.665,
             (20, 3), dict(lift=0.002)),
            ("intake", "frontBumper", "blackGloss", True, 24, 0.255, 0.375,
             (24, 4), dict(lift=0.002)),
            ("plate_front", "frontBumper", "plate", True, 5.6, 0.415, 0.505,
             (6, 2), dict(lift=0.006, thickness=0.004)),
            ("plate_rear", "tailgate", "plate", False, 5.6, 0.56, 0.65,
             (6, 2), dict(lift=0.006, thickness=0.004)),
        ],
        handles={"doorFront": (0.0, 0.16), "doorRear": (-0.87, -0.71)},
        handle_drop=0.14,
        mirror=(0.86, 0.905, 0.96, 0.85),
        roof_rail=None, cladding=False, bed=None,
        rig_z=0.66, view_scale=0.90,
    ),
    # Double-cab pickup with an open cargo bed.
    "pickup": SimpleNamespace(
        half_width=0.93, plan_length=2.78, plan_power=8.0,
        axles=(1.72, -1.36), wheel_r=0.39, arch_r=0.49, track=0.80,
        stations=[
            -2.65, -2.57, -2.45, -2.33, -2.05, -1.70, -1.36, -1.02, -0.80,
            -0.70, -0.62, -0.55, -0.20, 0.13, 0.18, 0.23, 0.50, 0.72, 1.05,
            1.30, 1.50, 1.72, 2.00, 2.25, 2.45, 2.57, 2.65,
        ],
        belt=[
            (-2.65, 1.10), (-2.57, 1.14), (-0.70, 1.15), (0.0, 1.13),
            (1.30, 1.10), (2.10, 1.07), (2.50, 1.02), (2.65, 0.98),
        ],
        # The cab ends at the bed: the greenhouse drops to the belt there.
        cabin=[
            (-0.70, 0.0), (-0.55, 0.50), (-0.20, 0.55), (0.30, 0.54),
            (0.72, 0.49), (1.30, 0.0),
        ],
        sill_z=0.36, side_z=0.72, end_x=2.2, end_span=0.45,
        hood_x=1.30, tail_x=-2.57, windshield_x=0.72, rear_glass_x=-0.55,
        fender_x=1.05, quarter_x=-0.62, door_split=0.18, rear_door_x=-0.62,
        pillars=[(0.13, 0.23)],
        front_corner=2.30, rear_corner=-2.36,
        paint=(0.62, 0.63, 0.65), pivot=1.65,
        headlight=(16, 52, ramp(0.83, 0.03), ramp(0.92, 0.03)),
        drl=(16.5, 51, ramp(0.90, 0.03), ramp(0.913, 0.03)),
        taillight=(29, 50, ramp(0.80, 0.0), ramp(1.07, 0.0)),
        patches=[
            ("grille", "frontBumper", "blackGloss", True, 13.5, 0.69, 0.90,
             (20, 8), dict(lift=0.002)),
            ("intake", "frontBumper", "blackGloss", True, 19, 0.445, 0.53,
             (24, 3), dict(lift=0.002)),
            ("plate_front", "frontBumper", "plate", True, 5.2, 0.555, 0.645,
             (6, 2), dict(lift=0.006, thickness=0.004)),
            ("plate_rear", "tailgate", "plate", False, 5.2, 0.80, 0.90,
             (6, 2), dict(lift=0.006, thickness=0.004)),
            ("step_rear", "rearBumper", "rim", False, 15, 0.46, 0.53,
             (14, 2), dict(lift=0.004)),
        ],
        handles={"doorFront": (0.26, 0.43), "doorRear": (-0.54, -0.37)},
        handle_drop=0.165,
        mirror=(1.15, 0.955, 1.23, 1.05),
        roof_rail=None, cladding=True,
        # Open bed: front x, rear x, floor z, side wall thickness. The floor
        # stays above the rear wheel arches.
        bed=(-0.80, -2.55, 0.93, 0.10),
        rig_z=0.85, view_scale=1.15,
    ),
}

S = SPECS["suv"]


# --------------------------------------------------------------- profile

def lerp(a, b, t):
    return a + (b - a) * t


def piecewise(knots, x):
    if x <= knots[0][0]:
        return knots[0][1]
    if x >= knots[-1][0]:
        return knots[-1][1]
    for (x0, y0), (x1, y1) in zip(knots, knots[1:]):
        if x <= x1:
            return lerp(y0, y1, (x - x0) / (x1 - x0))
    return knots[-1][1]


def plan(x):
    t = min(1.0, abs(x) / S.plan_length)
    return (1 - t ** S.plan_power) ** (1 / S.plan_power)


def section(x):
    """Half cross-section at x as (y, z) pairs, floor centre to roof centre."""
    f = plan(x) * S.half_width
    b = piecewise(S.belt, x)
    h = piecewise(S.cabin, x) if S.tail_x < x < S.hood_x else 0.0
    s = min(1.0, h / 0.4)
    q = max(0.0, (abs(x) - S.end_x) / S.end_span)
    zb = S.sill_z + 0.06 * q * q
    return [
        (0.0, zb - 0.02),
        (0.72 * f, zb),
        (0.95 * f, zb + 0.06),
        (0.975 * f, zb + 0.18),
        (0.985 * f, S.side_z),
        (0.97 * f, b - 0.14),
        (0.93 * f, b - 0.02),
        (0.89 * f, b + 0.02),
        (lerp(0.74, 0.72, s) * f, b + 0.03 + 0.80 * h),
        (lerp(0.50, 0.62, s) * f, b + 0.045 + 0.97 * h),
        (lerp(0.25, 0.33, s) * f, b + 0.055 + h),
        (0.0, b + 0.065 + h),
    ]


def classify(xm, j, cap=None):
    """Part and finish of the cage face in band j around x = xm."""
    if j == 0:
        return "", "under"
    if cap == "front":
        if j >= 7:
            return "hood", "paint"
        return "frontBumper", "plastic" if j <= 2 else "paint"
    if cap == "rear":
        if j <= 3:
            return "rearBumper", "plastic" if j <= 2 else "paint"
        return "tailgate", "paint"
    if j >= 7:
        if xm > S.hood_x:
            return "hood", "paint"
        if xm < S.tail_x:
            return "tailgate", "paint"
        if S.bed and xm < S.bed[0] + 0.1:
            # Bed rails; the deck between them is cut away in build_body.
            return "quarterRear", "paint"
        windshield = xm > S.windshield_x
        rear_glass = xm < S.rear_glass_x
        if j >= 9:
            if windshield:
                return "windshield", "glass"
            if rear_glass:
                return "rearWindow", "glass"
            return "roof", "paint"
        if j == 8:
            hatch = rear_glass and not S.bed
            return ("tailgate" if hatch else "roof"), "paint"
        if xm > S.fender_x:
            return "fenderFront", "paint"
        if xm < S.quarter_x:
            return "quarterRear", "paint"
        pillar = any(a < xm < b for a, b in S.pillars)
        return "windows", "blackGloss" if pillar else "glass"
    if xm > S.front_corner:
        if j <= 4:
            return "frontBumper", "plastic" if j <= 2 else "paint"
        return "fenderFront", "paint"
    if xm < S.rear_corner:
        if j <= 3:
            return "rearBumper", "plastic" if j <= 2 else "paint"
        return "quarterRear", "paint"
    part = (
        "fenderFront" if xm > S.fender_x
        else "doorFront" if xm > S.door_split
        else "doorRear" if xm > S.rear_door_x
        else "quarterRear"
    )
    return part, "plastic" if j <= 2 else "paint"


# ------------------------------------------------------------- materials

def principled(name, **inputs):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    try:
        mat.use_nodes = True
    except Exception:
        pass
    node = next(
        (n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None
    )
    for key, value in inputs.items():
        socket = node.inputs.get(key)
        if socket is None:
            print("missing socket", key)
            continue
        socket.default_value = value
    return mat


def rgba(r, g, b):
    return (r, g, b, 1.0)


def build_materials():
    m = {}
    m["paint"] = principled(
        "veh_paint", **{
            "Base Color": rgba(*S.paint), "Metallic": 0.8,
            "Roughness": 0.28, "Coat Weight": 1.0, "Coat Roughness": 0.03,
        })
    m["plastic"] = principled(
        "veh_plastic", **{"Base Color": rgba(0.025, 0.025, 0.028),
                          "Roughness": 0.55})
    m["blackGloss"] = principled(
        "veh_black_gloss", **{"Base Color": rgba(0.008, 0.008, 0.01),
                              "Roughness": 0.08, "Coat Weight": 1.0})
    m["glass"] = principled(
        "veh_glass", **{"Base Color": rgba(0.010, 0.013, 0.018),
                        "Roughness": 0.02, "Coat Weight": 1.0,
                        "Coat Roughness": 0.0})
    m["chrome"] = principled(
        "veh_chrome", **{"Base Color": rgba(0.85, 0.86, 0.88),
                         "Metallic": 1.0, "Roughness": 0.12})
    m["rim"] = principled(
        "veh_rim", **{"Base Color": rgba(0.62, 0.64, 0.67), "Metallic": 1.0,
                      "Roughness": 0.25})
    m["steel"] = principled(
        "veh_steel", **{"Base Color": rgba(0.35, 0.35, 0.36),
                        "Metallic": 1.0, "Roughness": 0.4})
    m["tire"] = principled(
        "veh_tire", **{"Base Color": rgba(0.012, 0.012, 0.013),
                       "Roughness": 0.82})
    m["headlight"] = principled(
        "veh_headlight", **{"Base Color": rgba(0.03, 0.033, 0.04),
                            "Roughness": 0.05, "Metallic": 0.5,
                            "Coat Weight": 1.0})
    m["drl"] = principled(
        "veh_drl", **{"Base Color": rgba(1, 1, 1),
                      "Emission Color": rgba(1, 1, 1),
                      "Emission Strength": 6.0})
    m["taillight"] = principled(
        "veh_taillight", **{"Base Color": rgba(0.45, 0.01, 0.012),
                            "Roughness": 0.06, "Coat Weight": 1.0,
                            "Emission Color": rgba(1, 0.02, 0.02),
                            "Emission Strength": 0.5})
    m["plate"] = principled(
        "veh_plate", **{"Base Color": rgba(0.85, 0.85, 0.82),
                        "Roughness": 0.4})
    m["under"] = principled(
        "veh_under", **{"Base Color": rgba(0.004, 0.004, 0.004),
                        "Roughness": 1.0})
    return m


# --------------------------------------------------------------- helpers

def new_object(col, name, bm, part, slots, smooth_angle=40.0):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for mat in slots:
        mesh.materials.append(mat)
    mesh.shade_smooth()
    try:
        mesh.set_sharp_from_angle(angle=math.radians(smooth_angle))
    except Exception as e:  # pragma: no cover - API guard
        print("set_sharp_from_angle", e)
    ob = bpy.data.objects.new(name, mesh)
    ob["part"] = part
    col.objects.link(ob)
    return ob


def add_shell(ob, thickness, bevel=0.002):
    s = ob.modifiers.new("shell", "SOLIDIFY")
    s.thickness = thickness
    s.offset = -1.0
    if bevel:
        b = ob.modifiers.new("edge", "BEVEL")
        b.width = bevel
        b.segments = 2
        b.limit_method = "ANGLE"
        b.angle_limit = math.radians(50)
        try:
            b.harden_normals = True
        except Exception:
            pass


def lathe(bm, profile, segments, mat_index, y_sign=1.0):
    """Revolves (radius, axial offset) pairs around the Y axis."""
    rings = []
    for i in range(segments):
        a = 2 * math.pi * i / segments
        rings.append([
            bm.verts.new((r * math.cos(a), y_sign * o, r * math.sin(a)))
            if r > 1e-6 else None
            for r, o in profile
        ])
    axis = {
        k: bm.verts.new((0, y_sign * o, 0))
        for k, (r, o) in enumerate(profile) if r <= 1e-6
    }
    for i in range(segments):
        a, b = rings[i], rings[(i + 1) % segments]
        for k in range(len(profile) - 1):
            vs = [a[k] or axis[k], b[k] or axis[k],
                  b[k + 1] or axis[k + 1], a[k + 1] or axis[k + 1]]
            uniq = []
            for v in vs:
                if v not in uniq:
                    uniq.append(v)
            if len(uniq) >= 3:
                bm.faces.new(uniq).material_index = mat_index


# ------------------------------------------------------------------ body

def build_cage():
    bm = bmesh.new()
    keys = ["|under"]

    def slot(part, finish, left):
        if part in SIDED:
            part += "Left" if left else "Right"
        key = f"{part}|{finish}"
        if key not in keys:
            keys.append(key)
        return keys.index(key)

    left, right = [], []
    stations = S.stations
    for x in stations:
        sec = section(x)
        lrow = [bm.verts.new((x, y, z)) for y, z in sec]
        rrow = [lrow[0]] + [
            bm.verts.new((x, -y, z)) for y, z in sec[1:-1]
        ] + [lrow[-1]]
        left.append(lrow)
        right.append(rrow)

    for i in range(len(stations) - 1):
        xm = (stations[i] + stations[i + 1]) / 2
        for j in range(ROWS - 1):
            part, finish = classify(xm, j)
            for grid, is_left in ((left, True), (right, False)):
                f = bm.faces.new((grid[i][j], grid[i + 1][j],
                                  grid[i + 1][j + 1], grid[i][j + 1]))
                f.material_index = slot(part, finish, is_left)

    for i, cap in ((0, "rear"), (len(stations) - 1, "front")):
        x = stations[i]
        centre = {
            j: bm.verts.new((x, 0.0, left[i][j].co.z))
            for j in range(1, ROWS - 1)
        }
        centre[0] = left[i][0]
        centre[ROWS - 1] = left[i][ROWS - 1]
        for j in range(ROWS - 1):
            part, finish = classify(x, j, cap)
            for grid, is_left in ((left, True), (right, False)):
                vs = []
                for v in (grid[i][j], grid[i][j + 1],
                          centre[j + 1], centre[j]):
                    if v not in vs:
                        vs.append(v)
                if len(vs) >= 3:
                    bm.faces.new(vs).material_index = slot(
                        part, finish, is_left)

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm, keys


def bed_cutter(bm, index):
    """Volume removed from the body to open the cargo bed."""
    x0, x1, floor, wall = S.bed
    top = max(z for _, z in S.belt) + 0.5
    n = 12
    rings = []
    for k in range(n + 1):
        x = lerp(x0, x1, k / n)
        w = 0.89 * plan(x) * S.half_width - wall
        rings.append([
            bm.verts.new(p) for p in (
                (x, w, floor), (x, w, top), (x, -w, top), (x, -w, floor))
        ])
    faces = [bm.faces.new(rings[0]), bm.faces.new(rings[-1])]
    for a, b in zip(rings, rings[1:]):
        for i in range(4):
            faces.append(bm.faces.new(
                (a[i], b[i], b[(i + 1) % 4], a[(i + 1) % 4])))
    for f in faces:
        f.material_index = index
    bmesh.ops.recalc_face_normals(bm, faces=faces)


def build_body(col, mats, scene):
    bm, keys = build_cage()
    if S.bed:
        # The boolean keeps the cutter's material index, so the faces it
        # leaves behind become the bed liner, a part of its own.
        keys.append("cargoBed|plastic")
    mesh = bpy.data.meshes.new("veh_cage")
    bm.to_mesh(mesh)
    bm.free()
    for _ in keys:
        mesh.materials.append(mats["under"])
    cage = bpy.data.objects.new("veh_cage", mesh)
    col.objects.link(cage)

    cutter_bm = bmesh.new()
    for cx in S.axles:
        for side in (1, -1):
            m = (Matrix.Translation(
                (cx, side * S.half_width * 0.97, S.wheel_r + 0.02))
                 @ Matrix.Rotation(math.pi / 2, 4, "X"))
            bmesh.ops.create_cone(
                cutter_bm, cap_ends=True, segments=72, radius1=S.arch_r,
                radius2=S.arch_r, depth=0.80, matrix=m)
    if S.bed:
        bed_cutter(cutter_bm, keys.index("cargoBed|plastic"))
    cutter_mesh = bpy.data.meshes.new("veh_cutter")
    cutter_bm.to_mesh(cutter_mesh)
    cutter_bm.free()
    cutter = bpy.data.objects.new("veh_cutter", cutter_mesh)
    col.objects.link(cutter)

    sub = cage.modifiers.new("sub", "SUBSURF")
    sub.levels = 3
    sub.render_levels = 3
    cut = cage.modifiers.new("arches", "BOOLEAN")
    cut.operation = "DIFFERENCE"
    cut.object = cutter
    cut.solver = "EXACT"

    layer = scene.view_layers[0]
    layer.update()
    dense_mesh = bpy.data.meshes.new_from_object(
        cage.evaluated_get(layer.depsgraph))
    for ob, me in ((cage, mesh), (cutter, cutter_mesh)):
        bpy.data.objects.remove(ob)
        bpy.data.meshes.remove(me)

    dense = bmesh.new()
    dense.from_mesh(dense_mesh)
    bpy.data.meshes.remove(dense_mesh)
    dense.faces.ensure_lookup_table()

    # One object per (part, finish) with real panel gaps.
    for k, key in enumerate(keys):
        part, finish = key.split("|")
        if finish == "under":
            continue
        piece = dense.copy()
        bmesh.ops.delete(
            piece,
            geom=[f for f in piece.faces if f.material_index != k],
            context="FACES")
        if not piece.faces:
            piece.free()
            continue
        for f in piece.faces:
            f.material_index = 0
        gap = 0.002 if finish == "glass" else 0.003
        moves = []
        for v in piece.verts:
            if not v.is_boundary:
                continue
            inward = Vector()
            for e in v.link_edges:
                if not e.is_boundary:
                    inward += (e.other_vert(v).co - v.co).normalized()
            if inward.length > 1e-6:
                moves.append((v, inward.normalized() * gap))
        for v, d in moves:
            v.co += d
        ob = new_object(col, f"body_{part}_{finish}", piece,
                        part, [mats[finish]])
        add_shell(ob, 0.018)

    # Dark inner shell: closes the gaps and sits behind the tinted glass.
    inner = new_object(col, "body_inner", dense.copy(), "", [mats["under"]])
    d = inner.modifiers.new("inset", "DISPLACE")
    d.strength = -0.008
    d.mid_level = 0.0
    return dense


# --------------------------------------------------------------- details

def surface_patch(col, mats, bvh, name, part, finish, ray, ns, nt,
                  lift=0.004, thickness=0.012, bevel=0.002):
    """Grid laid on the body by ray casting; ray(s, t) -> (origin, dir)."""
    bm = bmesh.new()
    grid = []
    normals = {}
    for i in range(ns + 1):
        row = []
        for j in range(nt + 1):
            origin, direction = ray(i / ns, j / nt)
            hit, normal, _, _ = bvh.ray_cast(Vector(origin),
                                             Vector(direction).normalized())
            if hit is None:
                row.append(None)
                continue
            v = bm.verts.new(hit + normal * lift)
            normals[v] = normal
            row.append(v)
        grid.append(row)
    for i in range(ns):
        for j in range(nt):
            vs = [grid[i][j], grid[i + 1][j], grid[i + 1][j + 1],
                  grid[i][j + 1]]
            if any(v is None for v in vs):
                continue
            f = bm.faces.new(vs)
            f.normal_update()
            if f.normal.dot(normals[vs[0]]) < 0:
                f.normal_flip()
    if not bm.faces:
        print("patch missed the body:", name)
        bm.free()
        return None
    ob = new_object(col, name, bm, part, [mats[finish]])
    add_shell(ob, thickness + lift, bevel)
    return ob


def end_ray(front, a0, a1, z_lo, z_hi):
    """Rays towards a pivot inside the nose/tail, sweeping around the corner.

    Angles in degrees from straight ahead (or astern), positive = left.
    z_lo / z_hi take s in [0, 1] and return the patch's lower / upper edge.
    """
    sign = 1.0 if front else -1.0

    def ray(s, t):
        a = math.radians(lerp(a0, a1, s))
        z = lerp(z_lo(s), z_hi(s), t)
        c, sn = math.cos(a), math.sin(a)
        return ((sign * (S.pivot + 3 * c), 3 * sn, z),
                (-sign * c, -sn, 0.0))

    return ray


def side_ray(left, point):
    """Rays straight in from the side; point(s, t) -> (x, z)."""
    y = 2.0 if left else -2.0

    def ray(s, t):
        x, z = point(s, t)
        return ((x, y, z), (0.0, -y, 0.0))

    return ray


def build_details(col, mats, bvh):
    for left in (True, False):
        side = "Left" if left else "Right"
        sg = 1.0 if left else -1.0

        for name, part, finish, front, lamp, grid, kw in (
            ("headlight", "headlight", "headlight", True, S.headlight,
             (18, 5), dict(lift=0.003)),
            ("drl", "headlight", "drl", True, S.drl, (18, 1),
             dict(lift=0.006, thickness=0.004, bevel=0)),
            ("taillight", "taillight", "taillight", False, S.taillight,
             (18, 5), dict(lift=0.003)),
        ):
            a0, a1, z_lo, z_hi = lamp
            surface_patch(
                col, mats, bvh, f"{name}_{side}", part + side, finish,
                end_ray(front, sg * a0, sg * a1, z_lo, z_hi), *grid, **kw)

        # Wheel-arch cladding.
        for axle, cx in enumerate(S.axles if S.cladding else ()):
            part = ("fenderFront" if axle == 0 else "quarterRear") + side
            cz = S.wheel_r + 0.02

            def arch(s, t, cx=cx, cz=cz):
                a = math.radians(lerp(-2, 182, s))
                r = lerp(S.arch_r + 0.004, S.arch_r + 0.085, t)
                return cx + r * math.cos(a), cz + r * math.sin(a)

            surface_patch(
                col, mats, bvh, f"arch_{axle}_{side}", part, "plastic",
                side_ray(left, arch), 48, 3, lift=0.007, thickness=0.02,
                bevel=0.004)

        # Door handles.
        for door, (x0, x1) in S.handles.items():
            def handle(s, t, x0=x0, x1=x1):
                x = lerp(x0, x1, s)
                return x, piecewise(S.belt, x) - S.handle_drop + 0.034 * t

            surface_patch(
                col, mats, bvh, f"handle_{door}_{side}", door + side,
                "paint", side_ray(left, handle), 6, 2, lift=0.014,
                thickness=0.02, bevel=0.005)

        build_mirror(col, mats, side, sg)
        if S.roof_rail:
            build_roof_rail(col, mats, bvh, side, sg)

    for name, part, finish, front, half, z_lo, z_hi, grid, kw in S.patches:
        surface_patch(
            col, mats, bvh, name, part, finish,
            end_ray(front, -half, half, const(z_lo), const(z_hi)), *grid,
            **kw)


def build_mirror(col, mats, side, sg):
    bm = bmesh.new()
    mx, my, mz, k = S.mirror
    bmesh.ops.create_cube(
        bm, size=1.0,
        matrix=Matrix.Translation((mx, sg * my, mz))
        @ Matrix.Diagonal((0.15 * k, 0.24 * k, 0.16 * k, 1.0)))
    bmesh.ops.create_cube(
        bm, size=1.0,
        matrix=Matrix.Translation((mx + 0.01, sg * (my - 0.125), mz - 0.05))
        @ Matrix.Diagonal((0.10 * k, 0.30, 0.06 * k, 1.0)))
    ob = new_object(col, f"mirror_{side}", bm, f"mirror{side}",
                    [mats["blackGloss"]], smooth_angle=180)
    sub = ob.modifiers.new("sub", "SUBSURF")
    sub.levels = 3
    sub.render_levels = 3


def build_roof_rail(col, mats, bvh, side, sg):
    bm = bmesh.new()
    n = 24
    rings = []
    x0, x1, yk = S.roof_rail
    for k in range(n + 1):
        x = lerp(x0, x1, k / n)
        y = sg * yk * plan(x)
        hit, _, _, _ = bvh.ray_cast(Vector((x, y, 3.0)), Vector((0, 0, -1)))
        end = min(k, n - k) / 3.0
        z = hit.z + 0.035 * min(1.0, end) - 0.01
        rings.append([
            bm.verts.new((x, y + dy, z + dz))
            for dy, dz in ((-0.017, -0.012), (-0.014, 0.012),
                           (0.014, 0.012), (0.017, -0.012))
        ])
    for a, b in zip(rings, rings[1:]):
        for i in range(4):
            bm.faces.new((a[i], b[i], b[(i + 1) % 4], a[(i + 1) % 4]))
    bm.faces.new(rings[0])
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    ob = new_object(col, f"roof_rail_{side}", bm, "roof", [mats["rim"]],
                    smooth_angle=180)
    sub = ob.modifiers.new("sub", "SUBSURF")
    sub.levels = 2
    sub.render_levels = 2


def build_wheel(col, mats, name, part, cx, sg):
    bm = bmesh.new()
    seg = 72
    tire = [
        (0.232, -0.115), (0.29, -0.124), (0.335, -0.118), (0.354, -0.095),
        (0.36, -0.05), (0.36, 0.05), (0.354, 0.095), (0.335, 0.118),
        (0.29, 0.124), (0.232, 0.115),
    ]
    lathe(bm, tire, seg, 0, sg)
    # Rim lip and barrel, dark backing, brake disc, hub.
    lathe(bm, [(0.232, 0.115), (0.24, 0.10), (0.222, 0.088),
               (0.214, -0.10), (0.232, -0.115)], seg, 1, sg)
    lathe(bm, [(0.214, -0.04), (0.0, -0.04)], seg, 2, sg)
    lathe(bm, [(0.175, 0.01), (0.175, 0.03), (0.06, 0.03)], seg, 3, sg)
    lathe(bm, [(0.062, 0.04), (0.062, 0.092), (0.05, 0.104), (0.0, 0.106)],
          seg, 1, sg)
    # Five tapered spokes.
    for k in range(5):
        a = 2 * math.pi * k / 5 + math.pi / 2
        radial = Vector((math.cos(a), 0, math.sin(a)))
        tangent = Vector((-math.sin(a), 0, math.cos(a)))
        axial = Vector((0, sg, 0))
        corners = []
        for r, w, y0, y1 in ((0.045, 0.030, 0.062, 0.098),
                             (0.226, 0.046, 0.058, 0.088)):
            for u, y in ((-w, y0), (w, y0), (w, y1), (-w, y1)):
                corners.append(bm.verts.new(
                    radial * r + tangent * u + axial * y))
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new((corners[i], corners[j], corners[4 + j],
                          corners[4 + i])).material_index = 1
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    ob = new_object(
        col, name, bm, part,
        [mats["tire"], mats["rim"], mats["under"], mats["steel"]],
        smooth_angle=35)
    ob.location = (cx, sg * S.track, S.wheel_r)
    k = S.wheel_r / 0.36  # the profile above is a 0.36 m wheel
    ob.scale = (k, k, k)
    b = ob.modifiers.new("edge", "BEVEL")
    b.width = 0.004
    b.segments = 2
    b.limit_method = "ANGLE"
    b.angle_limit = math.radians(40)


# ---------------------------------------------------------------- studio

def ground_material(rig):
    """Shadow catcher that fades out before the edges of the frame.

    The fade is an ellipse in the camera rig's space (narrow across the
    picture), so the contact shadow never ends in a visible rectangle.
    """
    mat = bpy.data.materials.get("veh_ground") or bpy.data.materials.new(
        "veh_ground")
    try:
        mat.use_nodes = True
    except Exception:
        pass
    nt = mat.node_tree
    nt.nodes.clear()
    coord = nt.nodes.new("ShaderNodeTexCoord")
    coord.object = rig
    scale = nt.nodes.new("ShaderNodeVectorMath")
    scale.operation = "MULTIPLY"
    scale.inputs[1].default_value = (
        1 / (4.2 * S.view_scale), 1 / (2.85 * S.view_scale), 0.0)
    length = nt.nodes.new("ShaderNodeVectorMath")
    length.operation = "LENGTH"
    fade = nt.nodes.new("ShaderNodeMapRange")
    fade.interpolation_type = "SMOOTHSTEP"
    fade.inputs["From Min"].default_value = 0.72
    fade.inputs["From Max"].default_value = 0.98
    diffuse = nt.nodes.new("ShaderNodeBsdfDiffuse")
    clear = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(coord.outputs["Object"], scale.inputs[0])
    nt.links.new(scale.outputs["Vector"], length.inputs[0])
    nt.links.new(length.outputs["Value"], fade.inputs["Value"])
    nt.links.new(fade.outputs["Result"], mix.inputs["Fac"])
    nt.links.new(diffuse.outputs["BSDF"], mix.inputs[1])
    nt.links.new(clear.outputs["BSDF"], mix.inputs[2])
    nt.links.new(mix.outputs["Shader"], out.inputs["Surface"])
    return mat


def build_studio(col, scene):
    world = bpy.data.worlds.get("veh_studio") or bpy.data.worlds.new(
        "veh_studio")
    try:
        world.use_nodes = True
    except Exception:
        pass
    nt = world.node_tree
    nt.nodes.clear()
    coord = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    rng = nt.nodes.new("ShaderNodeMapRange")
    rng.inputs["From Min"].default_value = -1.0
    rng.inputs["From Max"].default_value = 1.0
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    stops = [(0.0, 0.03), (0.47, 0.10), (0.505, 0.95), (0.60, 0.55),
             (1.0, 0.30)]
    elements = ramp.color_ramp.elements
    while len(elements) < len(stops):
        elements.new(0.5)
    for el, (pos, v) in zip(elements, stops):
        el.position = pos
        el.color = (v, v, v * 1.04, 1.0)
    bg = nt.nodes.new("ShaderNodeBackground")
    bg.inputs["Strength"].default_value = 0.6
    out = nt.nodes.new("ShaderNodeOutputWorld")
    nt.links.new(coord.outputs["Generated"], sep.inputs[0])
    nt.links.new(sep.outputs["Z"], rng.inputs["Value"])
    nt.links.new(rng.outputs["Result"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
    nt.links.new(bg.outputs["Background"], out.inputs["Surface"])
    scene.world = world

    ground_bm = bmesh.new()
    bmesh.ops.create_grid(ground_bm, x_segments=1, y_segments=1, size=30)
    rig = bpy.data.objects.new("rig", None)
    rig.location = (0, 0, S.rig_z)
    col.objects.link(rig)

    ground = new_object(col, "ground", ground_bm, "", [ground_material(rig)])
    ground.is_shadow_catcher = True

    cam_data = bpy.data.cameras.new("vehicle_camera")
    cam_data.lens = 70
    cam = bpy.data.objects.new("vehicle_camera", cam_data)
    col.objects.link(cam)
    cam.parent = rig
    distance, elevation = 11.4 * S.view_scale, math.radians(12)
    cam.location = (distance * math.cos(elevation), 0,
                    distance * math.sin(elevation))
    track = cam.constraints.new("TRACK_TO")
    track.target = rig
    track.track_axis = "TRACK_NEGATIVE_Z"
    track.up_axis = "UP_Y"
    scene.camera = cam

    def softbox(name, location, size, power):
        data = bpy.data.lights.new(name, "AREA")
        data.shape = "RECTANGLE"
        data.size, data.size_y = size
        data.energy = power
        ob = bpy.data.objects.new(name, data)
        col.objects.link(ob)
        ob.parent = rig
        ob.location = location
        ob.rotation_euler = (-Vector(location)).to_track_quat(
            "-Z", "Y").to_euler()
        ob.visible_camera = False
        return ob

    softbox("light_top", (0, 0, 4.2), (7.0, 3.6), 260)
    softbox("light_key", (5.5, -4.5, 3.0), (3.0, 2.0), 170)
    softbox("light_rim", (-5.0, 5.0, 2.4), (3.0, 1.5), 100)

    scene.render.engine = "CYCLES"
    try:
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError as e:
        print("look", e)
    scene.cycles.samples = 96
    scene.cycles.use_denoising = True
    scene.render.film_transparent = True
    scene.render.resolution_x = 800
    scene.render.resolution_y = 420
    scene.render.resolution_percentage = 100
    return rig


# ------------------------------------------------------------------ main

def remove_data(data):
    for store in (bpy.data.meshes, bpy.data.lights, bpy.data.cameras):
        if data.name in store and store[data.name] == data:
            store.remove(data)
            return


def build(kind=None):
    """Builds the vehicle `kind` (a key of SPECS) and returns its parts."""
    global S
    kind = kind or os.environ.get("VEHICLE", "suv")
    S = SPECS[kind]
    scene = bpy.data.scenes.get("Vehicle") or bpy.data.scenes.new("Vehicle")
    col = bpy.data.collections.get("Vehicle")
    if col is None:
        col = bpy.data.collections.new("Vehicle")
    for ob in list(col.objects):
        data = ob.data
        bpy.data.objects.remove(ob)
        if data is not None and data.users == 0:
            remove_data(data)
    if col.name not in scene.collection.children:
        scene.collection.children.link(col)
    wm = bpy.context.window_manager
    for window in (wm.windows if wm else []):
        window.scene = scene

    mats = build_materials()
    dense = build_body(col, mats, scene)
    bvh = BVHTree.FromBMesh(dense)
    build_details(col, mats, bvh)
    dense.free()
    for axle, cx in enumerate(S.axles):
        for side, sg in (("Left", 1.0), ("Right", -1.0)):
            pos = "Front" if axle == 0 else "Rear"
            build_wheel(col, mats, f"wheel_{pos}_{side}",
                        f"wheel{pos}{side}", cx, sg)
    build_studio(col, scene)

    parts = sorted({ob["part"] for ob in col.objects if ob.get("part")})
    print("vehicle", kind, "objects", len(col.objects), "parts", len(parts))
    return parts


if __name__ == "__main__":
    build()
