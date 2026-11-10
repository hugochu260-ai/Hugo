#!/usr/bin/env python3
"""Capture console sessions and draw the class diagrams used in the report."""

import os
import pty
import select
import subprocess
import time

from PIL import Image, ImageDraw, ImageFont

OUT = "/workspace/report/figures"
FONT_MONO = "/usr/share/fonts/truetype/jetbrains-mono/JetBrainsMono-Regular.ttf"
FONT_SANS = "/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf"
FONT_SANS_B = "/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf"
HEADER = "Smart Delivery Fleet Management System (SDFMS)\n"


def capture(inputs, timeout=25):
    master, slave = pty.openpty()
    proc = subprocess.Popen(
        ["java", "Main"],
        stdin=slave,
        stdout=slave,
        stderr=slave,
        cwd="/workspace",
    )
    os.close(slave)
    idx = 0
    data = b""
    deadline = time.time() + timeout
    while time.time() < deadline:
        ready, _, _ = select.select([master], [], [], 0.2)
        if ready:
            try:
                chunk = os.read(master, 8192)
            except OSError:
                break
            if not chunk:
                break
            data += chunk
        if idx < len(inputs) and data.endswith(b":- "):
            os.write(master, (inputs[idx] + "\n").encode())
            idx += 1
        if proc.poll() is not None and not ready:
            break
    try:
        os.close(master)
    except OSError:
        pass
    proc.wait(timeout=5)
    if idx != len(inputs):
        raise SystemExit("only consumed %s of %s inputs" % (idx, len(inputs)))
    text = data.decode("utf-8", "replace").replace("\r\n", "\n").replace("\r", "\n")
    return text


def screens(text):
    parts = text.split(HEADER)
    chunks = []
    for part in parts:
        if part == "" and not chunks:
            continue
        chunks.append(HEADER + part)
    if chunks and chunks[0].startswith(HEADER + HEADER):
        chunks[0] = chunks[0][len(HEADER):]
    return [chunk.strip("\n") + "\n" for chunk in chunks]


def render_console(text, path, title):
    font = ImageFont.truetype(FONT_MONO, 18)
    lines = text.split("\n")
    while lines and lines[-1] == "":
        lines.pop()
    # Keep the capture readable if a case stacks several menus.
    wrapped = []
    limit = 108
    for line in lines:
        if len(line) <= limit:
            wrapped.append(line)
        else:
            wrapped.append(line[:limit])
            rest = line[limit:]
            while rest:
                wrapped.append(rest[:limit])
                rest = rest[limit:]
    line_h = 24
    pad = 18
    bar = 36
    width = 1040
    height = bar + pad * 2 + line_h * max(1, len(wrapped))
    image = Image.new("RGB", (width, height), "#0e1116")
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, 0, width, bar), fill="#1c2430")
    title_font = ImageFont.truetype(FONT_SANS_B, 16)
    draw.text((16, 8), title, font=title_font, fill="#e8eef7")
    y = bar + pad
    for line in wrapped:
        draw.text((pad, y), line, font=font, fill="#d6deeb")
        y += line_h
    image.save(path, optimize=True)


def take_cases(inputs, cases):
    text = capture(inputs)
    chunks = screens(text)
    needed = sum(size for _, _, size in cases)
    if len(chunks) != needed:
        raise SystemExit("expected %s screens, got %s\n%s" % (needed, len(chunks), text))
    cursor = 0
    for filename, title, size in cases:
        body = "\n".join(chunk.rstrip("\n") for chunk in chunks[cursor:cursor + size])
        render_console(body + "\n", os.path.join(OUT, filename), title)
        cursor += size


def font(path, size):
    return ImageFont.truetype(path, size)


def text_width(draw, value, face):
    return draw.textlength(value, font=face)


def draw_class(draw, x, y, w, title, stereotype, rows, fill):
    name_font = font(FONT_SANS_B, 16)
    small = font(FONT_SANS, 13)
    italic = font(FONT_SANS, 14)
    pad = 8
    name_h = 26
    stereo_h = 18 if stereotype else 0
    row_h = 20
    header_h = 8 + stereo_h + name_h
    body_h = 8 + row_h * len(rows) + 6
    h = header_h + body_h
    draw.rounded_rectangle((x, y, x + w, y + h), radius=6, fill="white", outline="#1c2833", width=2)
    draw.rectangle((x + 1, y + 1, x + w - 1, y + header_h), fill=fill)
    cursor = y + 6
    if stereotype:
        stereo = "«%s»" % stereotype
        sw = text_width(draw, stereo, small)
        draw.text((x + (w - sw) / 2, cursor), stereo, font=small, fill="#f4f7fb")
        cursor += stereo_h
    tw = text_width(draw, title, name_font)
    draw.text((x + (w - tw) / 2, cursor), title, font=name_font, fill="white")
    yy = y + header_h + 6
    for row, style in rows:
        face = italic if style == "abstract" else small
        colour = "#1a5276" if style == "abstract" else "#1c2833"
        draw.text((x + pad, yy), row, font=face, fill=colour)
        yy += row_h
    return (x, y, x + w, y + h)


def center_top(box):
    return ((box[0] + box[2]) / 2, box[1])


def center_bottom(box):
    return ((box[0] + box[2]) / 2, box[3])


def center_left(box):
    return (box[0], (box[1] + box[3]) / 2)


def center_right(box):
    return (box[2], (box[1] + box[3]) / 2)


def arrow_head(draw, tip, direction, fill):
    x, y = tip
    if direction == "up":
        pts = [(x, y), (x - 7, y + 12), (x + 7, y + 12)]
    elif direction == "down":
        pts = [(x, y), (x - 7, y - 12), (x + 7, y - 12)]
    elif direction == "left":
        pts = [(x, y), (x + 12, y - 7), (x + 12, y + 7)]
    else:
        pts = [(x, y), (x - 12, y - 7), (x - 12, y + 7)]
    draw.polygon(pts, fill=fill)


def inherit(draw, child, parent):
    x1, y1 = center_top(child)
    x2, y2 = center_bottom(parent)
    mid = (y1 + y2) / 2
    draw.line([(x1, y1), (x1, mid), (x2, mid), (x2, y2 + 12)], fill="#1c2833", width=2)
    # hollow triangle
    draw.polygon([(x2, y2), (x2 - 8, y2 + 14), (x2 + 8, y2 + 14)], fill="white", outline="#1c2833")


def diamond_agg(draw, whole, part, label_whole, label_part):
    x1, y1 = center_right(whole)
    x2, y2 = center_left(part)
    mid = (x1 + x2) / 2
    draw.line([(x1 + 14, y1), (mid, y1), (mid, y2), (x2, y2)], fill="#1c2833", width=2)
    draw.polygon([(x1, y1), (x1 + 12, y1 - 7), (x1 + 24, y1), (x1 + 12, y1 + 7)], fill="white", outline="#1c2833")
    small = font(FONT_SANS_B, 14)
    draw.text((x1 + 28, y1 - 22), label_whole, font=small, fill="#1c2833")
    draw.text((x2 - 24, y2 - 22), label_part, font=small, fill="#1c2833")


def dashed(draw, start, end, label):
    x1, y1 = start
    x2, y2 = end
    # horizontal-then-vertical polyline is handled by caller via end point already chosen
    draw_dashed_line(draw, (x1, y1), (x2, y2))
    if label:
        small = font(FONT_SANS, 13)
        draw.text(((x1 + x2) / 2 - 40, (y1 + y2) / 2 - 18), label, font=small, fill="#333")


def draw_dashed_line(draw, a, b):
    x1, y1 = a
    x2, y2 = b
    steps = 24
    for i in range(0, steps, 2):
        t1 = i / steps
        t2 = min(1, (i + 1) / steps)
        draw.line(
            (x1 + (x2 - x1) * t1, y1 + (y2 - y1) * t1, x1 + (x2 - x1) * t2, y1 + (y2 - y1) * t2),
            fill="#1c2833",
            width=2,
        )


def caption(draw, text, y, width):
    face = font(FONT_SANS, 14)
    draw.text((24, y), text, font=face, fill="#333")


def save_diagram(image, path):
    image.save(path, optimize=True)


def domain_diagram():
    image = Image.new("RGB", (1500, 980), "#f4f7fb")
    draw = ImageDraw.Draw(image)
    fleet = draw_class(
        draw, 40, 30, 560, "VehicleFleet", "abstract originator",
        [
            ("- fleetID: String", ""),
            ("- fleetName: String", ""),
            ("- drivers: AbstractList<Driver>", ""),
            ("+ VehicleFleet(fleetID)", ""),
            ("+ getFleetID(): String", ""),
            ("+ getName(): String", ""),
            ("+ setName(name): void", ""),
            ("+ addDriver(driver): void", ""),
            ("+ dropDriver(driver): void", ""),
            ("+ getDrivers(): Iterator<Driver>", ""),
            ("+ updateDriverRole(): void", "abstract"),
            ("+ showFleet(): void", "abstract"),
            ("+ createNameMemento(): FleetNameMemento", ""),
            ("+ setNameMemento(memento): void", ""),
        ],
        "#1b4f72",
    )
    driver = draw_class(
        draw, 980, 30, 470, "Driver", "originator",
        [
            ("- driverID: String", ""),
            ("- driverName: String", ""),
            ("- role: int", ""),
            ("+ Driver(driverID)", ""),
            ("+ getDriverID(): String", ""),
            ("+ getRole(): int", ""),
            ("+ setRole(role): void", ""),
            ("+ getName(): String", ""),
            ("+ setName(name): void", ""),
            ("+ createRoleMemento(): DriverRoleMemento", ""),
            ("+ setRoleMemento(memento): void", ""),
        ],
        "#1b4f72",
    )
    van = draw_class(
        draw, 40, 620, 460, "DeliveryVanFleet", None,
        [
            ("- VAN_DRIVER_ROLE = 1", ""),
            ("- COURIER_DRIVER_ROLE = 2", ""),
            ("+ DeliveryVanFleet(fleetID)", ""),
            ("+ updateDriverRole(): void", ""),
            ("+ showFleet(): void", ""),
        ],
        "#1a5276",
    )
    truck = draw_class(
        draw, 540, 620, 520, "RefrigeratedTruckFleet", None,
        [
            ("- REFRIGERATED_TRUCK_DRIVER_ROLE = 1", ""),
            ("- COLD_CHAIN_DELIVERY_DRIVER_ROLE = 2", ""),
            ("+ RefrigeratedTruckFleet(fleetID)", ""),
            ("+ updateDriverRole(): void", ""),
            ("+ showFleet(): void", ""),
        ],
        "#1a5276",
    )
    inherit(draw, van, fleet)
    inherit(draw, truck, fleet)
    diamond_agg(draw, fleet, driver, "1", "*")
    save_diagram(image, os.path.join(OUT, "domain.png"))


def command_box(draw, x, y, name, undoable):
    note = "undoable" if undoable else "not stored"
    return draw_class(
        draw, x, y, 300, name, note,
        [("+ execute(): boolean", ""), ("+ undo(): void", ""), ("+ redo(): void", "")],
        "#0e6655" if undoable else "#1a5276",
    )


def command_diagram():
    image = Image.new("RGB", (1360, 1180), "#f4f7fb")
    draw = ImageDraw.Draw(image)
    main_box = draw_class(
        draw, 40, 24, 280, "Main", "invoker",
        [("+ main(args): void", "")],
        "#1b4f72",
    )
    factory = draw_class(
        draw, 520, 24, 320, "CommandFactory", "simple factory",
        [("+ create(token, context): Command", "")],
        "#1a5276",
    )
    command = draw_class(
        draw, 980, 24, 340, "Command", "interface",
        [
            ("+ execute(): boolean", "abstract"),
            ("+ undo(): void", "abstract"),
            ("+ redo(): void", "abstract"),
            ("+ isUndoable(): boolean", "abstract"),
            ("+ getRecord(): String", "abstract"),
        ],
        "#196f3d",
    )
    names = [
        ("CreateFleetCommand", True),
        ("AddDriverCommand", True),
        ("DeleteDriverCommand", True),
        ("ModifyDriverRoleCommand", True),
        ("ChangeFleetNameCommand", True),
        ("SetCurrentFleetCommand", False),
        ("ShowFleetCommand", False),
        ("DisplayAllFleetsCommand", False),
        ("UndoCommand", False),
        ("RedoCommand", False),
        ("ListHistoryCommand", False),
    ]
    boxes = []
    for i, (name, undoable) in enumerate(names):
        col = i % 4
        row = i // 4
        boxes.append(command_box(draw, 30 + col * 330, 280 + row * 210, name, undoable))
    caretaker = draw_class(
        draw, 30, 940, 420, "Caretaker", "command history",
        [("- undoList: List<Command>", ""), ("- redoList: List<Command>", ""),
         ("+ record / pollUndo / pollRedo", "")],
        "#6c3483",
    )
    manager = draw_class(
        draw, 860, 940, 440, "FleetManager", "receiver",
        [("- fleets: List<VehicleFleet>", ""), ("- currentFleet: VehicleFleet", ""),
         ("+ add / remove / find / setCurrent", "")],
        "#1b4f72",
    )
    draw.line((*center_right(main_box), *center_left(factory)), fill="#1c2833", width=2)
    arrow_head(draw, center_left(factory), "right", "#1c2833")
    draw.text((350, 78), "asks", font=font(FONT_SANS, 13), fill="#333")
    draw.line((*center_right(factory), *center_left(command)), fill="#1c2833", width=2)
    arrow_head(draw, center_left(command), "right", "#1c2833")
    draw.text((860, 78), "creates", font=font(FONT_SANS, 13), fill="#333")
    draw.text((30, 230), "Every concrete command implements Command. The caretaker stores only the undoable ones.", font=font(FONT_SANS, 15), fill="#1c2833")
    save_diagram(image, os.path.join(OUT, "command.png"))


def factory_diagram():
    image = Image.new("RGB", (1400, 860), "#f4f7fb")
    draw = ImageDraw.Draw(image)
    provider = draw_class(
        draw, 470, 24, 440, "FleetFactoryProvider", None,
        [("+ register(factory): void", ""), ("+ getFactory(typeCode): FleetComponentFactory", ""),
         ("+ buildTypePrompt(): String", "")],
        "#1b4f72",
    )
    interface = draw_class(
        draw, 470, 280, 440, "FleetComponentFactory", "abstract factory",
        [("+ getTypeCode(): String", "abstract"), ("+ createFleet(id): VehicleFleet", "abstract"),
         ("+ createDriver(id): Driver", "abstract")],
        "#196f3d",
    )
    van = draw_class(
        draw, 40, 560, 420, "DeliveryVanFleetFactory", None,
        [("+ createFleet(id): VehicleFleet", ""), ("+ createDriver(id): Driver", "")],
        "#1a5276",
    )
    truck = draw_class(
        draw, 500, 560, 460, "RefrigeratedTruckFleetFactory", None,
        [("+ createFleet(id): VehicleFleet", ""), ("+ createDriver(id): Driver", "")],
        "#1a5276",
    )
    drivers = draw_class(
        draw, 1020, 560, 340, "DriverFactory", "simple factory",
        [("+ createDriver(id): Driver", "")],
        "#1a5276",
    )
    commands = draw_class(
        draw, 40, 40, 360, "CommandFactory", "simple factory",
        [("+ create(token, context): Command", "")],
        "#1a5276",
    )
    inherit(draw, van, interface)
    inherit(draw, truck, interface)
    draw.line((*center_bottom(provider), *center_top(interface)), fill="#1c2833", width=2)
    arrow_head(draw, center_top(interface), "down", "#1c2833")
    draw.text((760, 200), "looks up", font=font(FONT_SANS, 13), fill="#333")
    draw.line((*center_right(truck), *center_left(drivers)), fill="#1c2833", width=2)
    arrow_head(draw, center_left(drivers), "right", "#1c2833")
    draw.text((700, 760), "both fleet factories delegate driver creation", font=font(FONT_SANS, 14), fill="#333")
    save_diagram(image, os.path.join(OUT, "factory.png"))


def memento_diagram():
    image = Image.new("RGB", (1400, 720), "#f4f7fb")
    draw = ImageDraw.Draw(image)
    modify = draw_class(
        draw, 40, 180, 420, "ModifyDriverRoleCommand", "caretaker",
        [("- beforeRole: DriverRoleMemento", ""), ("- afterRole: DriverRoleMemento", ""),
         ("+ undo() restores beforeRole", ""), ("+ redo() restores afterRole", "")],
        "#6c3483",
    )
    role = draw_class(
        draw, 520, 40, 360, "DriverRoleMemento", "memento",
        [("- role: int", "")],
        "#9a4d0f",
    )
    driver = draw_class(
        draw, 980, 40, 380, "Driver", "originator",
        [("+ createRoleMemento()", ""), ("+ setRoleMemento(memento)", "")],
        "#1b4f72",
    )
    change = draw_class(
        draw, 40, 460, 420, "ChangeFleetNameCommand", "caretaker",
        [("- beforeName: FleetNameMemento", ""), ("- afterName: FleetNameMemento", ""),
         ("+ undo() restores beforeName", ""), ("+ redo() restores afterName", "")],
        "#6c3483",
    )
    name = draw_class(
        draw, 520, 460, 360, "FleetNameMemento", "memento",
        [("- name: String", "")],
        "#9a4d0f",
    )
    fleet = draw_class(
        draw, 980, 430, 380, "VehicleFleet", "originator",
        [("+ createNameMemento()", ""), ("+ setNameMemento(memento)", ""),
         ("+ setName(name): void", "")],
        "#1b4f72",
    )
    draw.line((*center_right(modify), *center_left(role)), fill="#1c2833", width=2)
    arrow_head(draw, center_left(role), "right", "#1c2833")
    draw.line((*center_right(role), *center_left(driver)), fill="#1c2833", width=2)
    arrow_head(draw, center_left(driver), "right", "#1c2833")
    draw.line((*center_right(change), *center_left(name)), fill="#1c2833", width=2)
    arrow_head(draw, center_left(name), "right", "#1c2833")
    draw.line((*center_right(name), *center_left(fleet)), fill="#1c2833", width=2)
    arrow_head(draw, center_left(fleet), "right", "#1c2833")
    small = font(FONT_SANS, 13)
    draw.text((470, 150), "stores", font=small, fill="#333")
    draw.text((900, 20), "created and restored by", font=small, fill="#333")
    draw.text((470, 430), "stores", font=small, fill="#333")
    draw.text((900, 400), "created and restored by", font=small, fill="#333")
    save_diagram(image, os.path.join(OUT, "memento.png"))


def main():
    os.makedirs(OUT, exist_ok=True)
    sample = [
        "c", "v", "F001", "CENTRAL EXPRESS",
        "a", "d001, Alex Chan", "1",
        "a", "d002, Jamie Lee", "2",
        "sf",
        "c", "r", "F102", "FROST LINE",
        "sa",
        "a", "d101, Morgan Wong", "1",
        "a", "d102, Taylor Lam", "2",
        "sf",
        "s", "F001",
        "sa",
        "m", "d001", "2",
        "sf",
        "d", "d002",
        "sf",
        "cn", "METRO EXPRESS",
        "sf",
        "l",
        "u", "u", "u",
        "sf",
        "r", "r", "r",
        "sf",
        "s", "F999",
        "d", "d999",
        "q",
        "x",
    ]
    sample_cases = [
        ("tc01.png", "TC01  Create a delivery van fleet", 1),
        ("tc02.png", "TC02  Add drivers to the delivery van fleet", 2),
        ("tc03.png", "TC03  Show the delivery van fleet", 1),
        ("tc04.png", "TC04  Create a refrigerated truck fleet", 1),
        ("tc05.png", "TC05  Display all fleets", 1),
        ("tc06.png", "TC06  Add drivers to the refrigerated truck fleet", 2),
        ("tc07.png", "TC07  Show the refrigerated truck fleet", 1),
        ("tc08.png", "TC08  Set the current fleet to F001", 1),
        ("tc09.png", "TC09  Display all fleets after switching", 1),
        ("tc10.png", "TC10  Modify driver d001 to courier driver", 1),
        ("tc11.png", "TC11  Show the fleet after the role change", 1),
        ("tc12.png", "TC12  Delete driver d002", 1),
        ("tc13.png", "TC13  Show the fleet after the delete", 1),
        ("tc14.png", "TC14  Change the fleet name", 1),
        ("tc15.png", "TC15  Show the fleet after the rename", 1),
        ("tc16.png", "TC16  List undo and redo", 1),
        ("tc17.png", "TC17  Undo the last three commands", 3),
        ("tc18.png", "TC18  Show the fleet after undo", 1),
        ("tc19.png", "TC19  Redo the three commands", 3),
        ("tc20.png", "TC20  Show the fleet after redo", 1),
        ("tc21.png", "TC21  Unknown fleet id", 1),
        ("tc22.png", "TC22  Unknown driver id", 1),
        ("tc23.png", "TC23  Invalid command", 1),
        ("tc24.png", "TC24  Exit", 1),
    ]
    take_cases(sample, sample_cases)

    take_cases(
        ["a", "m", "d", "sf", "cn", "sa", "u", "r", "x"],
        [("tc25.png", "TC25  Commands when no fleet exists", 9)],
    )
    take_cases(
        ["c", "v", "", "STILL READ", "c", "v", "F001", "CENTRAL EXPRESS",
         "c", "v", "F001", "OTHER", "c", "z",
         "a", "d001, Alex Chan", "9", "a", "no-comma", "a", ", Nameless",
         "a", "d001, Alex Chan", "1", "a", "d001, Someone", "2", "x"],
        [("tc26.png", "TC26  Reject invalid fleet and driver input", 10)],
    )
    take_cases(
        ["c", "v", "F001", "CENTRAL EXPRESS",
         "a", "d001, Alex Chan", "1", "a", "d002, Jamie Lee", "2", "a", "d003, Pat Cheung", "1",
         "d", "d002", "u", "sf", "x"],
        [("tc27.png", "TC27  Undo delete restores driver order", 8)],
    )
    take_cases(
        ["c", "v", "F001", "CENTRAL EXPRESS", "cn", "METRO EXPRESS",
         "c", "r", "F102", "FROST LINE", "u", "sf", "s", "F001", "u", "sf", "x"],
        [("tc28.png", "TC28  Undo create and undo rename", 9)],
    )
    take_cases(
        ["c", "v", "F001", "CENTRAL EXPRESS", "a", "d001, Alex Chan", "1",
         "u", "l", "q", "d", "d999", "l", "a", "d002, Jamie Lee", "2", "l", "r", "x"],
        [("tc29.png", "TC29  Failed commands and clearing redo", 11)],
    )
    take_cases(
        ["c", "V", "F001", "CENTRAL EXPRESS", "a", "d001, Alex Chan", "1",
         "c", "R", "F102", "FROST LINE", "a", "d101, Morgan Wong", "2",
         "u", "u", "u", "u", "sa", "sf", "u", "r", "r", "r", "r", "sf", "sa", "x"],
        [("tc30.png", "TC30  Undo every command, then redo them", 18)],
    )
    domain_diagram()
    command_diagram()
    factory_diagram()
    memento_diagram()
    print("figures written to", OUT)


if __name__ == "__main__":
    main()
