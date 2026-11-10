#!/usr/bin/env python3
"""Replay the SDFMS sample and the extra cases against the compiled program."""

import re
import subprocess
import sys


def run(lines):
    proc = subprocess.run(
        ["java", "Main"],
        input="\n".join(lines) + "\n",
        text=True,
        capture_output=True,
        cwd="/workspace",
    )
    if proc.returncode != 0:
        sys.stderr.write(proc.stderr)
        raise SystemExit("java Main failed")
    return proc.stdout


def expect(text, *parts):
    pos = 0
    for part in parts:
        found = text.find(part, pos)
        if found < 0:
            sys.stderr.write("MISSING:\n%s\n" % part)
            sys.stderr.write(text[max(0, pos - 240):pos + 480] + "\n")
            raise SystemExit(1)
        pos = found + len(part)


def lists(text):
    return re.findall(r"Undo List\n.*?-- End of redo list --", text, re.S)


def main():
    sample = """c
v
F001
CENTRAL EXPRESS
a
d001, Alex Chan
1
a
d002, Jamie Lee
2
sf
c
r
F102
FROST LINE
sa
a
d101, Morgan Wong
1
a
d102, Taylor Lam
2
sf
s
F001
sa
m
d001
2
sf
d
d002
sf
cn
METRO EXPRESS
sf
l
u
u
u
sf
r
r
r
sf
s
F999
d
d999
q
x""".splitlines()
    out = run(sample)
    expect(
        out,
        "Delivery van fleet is created.",
        "Current fleet is changed to F001.",
        "The current fleet is F001 CENTRAL EXPRESS.",
        "Role (1 = van driver | 2 = courier driver) :- ",
        "Delivery Van Fleet CENTRAL EXPRESS (F001)\nVan Driver:\nd001, Alex Chan\nCourier Driver:\nd002, Jamie Lee",
        "Refrigerated truck fleet is created.",
        "Current fleet is changed to F102.",
        "Delivery Van Fleet CENTRAL EXPRESS (F001)\nRefrigerated Truck Fleet FROST LINE (F102)",
        "Role (1 = refrigerated-truck driver | 2 = cold-chain delivery driver) :- ",
        "Refrigerated Truck Fleet FROST LINE (F102)\nRefrigerated-Truck Driver:\nd101, Morgan Wong\nCold-Chain Delivery Driver:\nd102, Taylor Lam",
        "Changed current fleet to F001.",
        "Driver role is updated.",
        "Delivery Van Fleet CENTRAL EXPRESS (F001)\nVan Driver: NIL\nCourier Driver:\nd001, Alex Chan\nd002, Jamie Lee",
        "Driver is deleted.",
        "Delivery Van Fleet CENTRAL EXPRESS (F001)\nVan Driver: NIL\nCourier Driver:\nd001, Alex Chan\n",
        "Fleet name is updated.",
        "The current fleet is F001 METRO EXPRESS.",
        "Delivery Van Fleet METRO EXPRESS (F001)\nVan Driver: NIL\nCourier Driver:\nd001, Alex Chan",
        """Undo List
Create delivery van fleet, F001, CENTRAL EXPRESS
Add driver, d001, Alex Chan, van driver
Add driver, d002, Jamie Lee, courier driver
Create refrigerated truck fleet, F102, FROST LINE
Add driver, d101, Morgan Wong, refrigerated-truck driver
Add driver, d102, Taylor Lam, cold-chain delivery driver
Modify driver role, d001, courier driver
Delete driver, d002
Change fleet name, F001, METRO EXPRESS
-- End of undo list --
Redo List
-- End of redo list --""",
        "Command (Change fleet name, F001, METRO EXPRESS) is undone.",
        "The current fleet is F001 CENTRAL EXPRESS.",
        "Command (Delete driver, d002) is undone.",
        "Command (Modify driver role, d001, courier driver) is undone.",
        "Delivery Van Fleet CENTRAL EXPRESS (F001)\nVan Driver:\nd001, Alex Chan\nCourier Driver:\nd002, Jamie Lee",
        "Command (Modify driver role, d001, courier driver) is redone.",
        "Command (Delete driver, d002) is redone.",
        "Command (Change fleet name, F001, METRO EXPRESS) is redone.",
        "Delivery Van Fleet METRO EXPRESS (F001)\nVan Driver: NIL\nCourier Driver:\nd001, Alex Chan",
        "Fleet F999 is not found!",
        "Driver d999 is not found in the current fleet!",
        "Invalid command!",
        "Thank you for using SDFMS. System terminated.",
    )
    print("sample session passed")

    out = run("""a
m
d
sf
cn
sa
u
r
c
v

STILL READ
c
v
F001
CENTRAL EXPRESS
c
v
F001
OTHER
c
z
a
d001, Alex Chan
9
a
no-comma
a
, Nameless
a
d001, Alex Chan
1
a
d001, Someone
2
a
d002, Jamie Lee
2
a
d003, Pat Cheung
1
d
d002
u
sf
x""".splitlines())
    expect(
        out,
        "No current fleet!",
        "No fleet record.",
        "Nothing to undo!",
        "Nothing to redo!",
        "Fleet ID cannot be empty!",
        "Delivery van fleet is created.",
        "Fleet F001 already exists!",
        "Invalid fleet type!",
        "Invalid role!",
        "Invalid driver information!",
        "Driver is added.",
        "Driver d001 already exists in the current fleet!",
        "Command (Delete driver, d002) is undone.",
        "Delivery Van Fleet CENTRAL EXPRESS (F001)\nVan Driver:\nd001, Alex Chan\nd003, Pat Cheung\nCourier Driver:\nd002, Jamie Lee",
    )
    print("validation session passed")

    out = run("""c
v
F001
CENTRAL EXPRESS
cn
METRO EXPRESS
c
r
F102
FROST LINE
u
sf
s
F001
u
sf
cn

s
F102
m
d101
d
d000
l
x""".splitlines())
    expect(
        out,
        "Fleet name is updated.",
        "The current fleet is F001 METRO EXPRESS.",
        "Command (Create refrigerated truck fleet, F102, FROST LINE) is undone.",
        "The current fleet is F001 METRO EXPRESS.",
        "Delivery Van Fleet METRO EXPRESS (F001)\nVan Driver: NIL\nCourier Driver: NIL",
        "Command (Change fleet name, F001, METRO EXPRESS) is undone.",
        "The current fleet is F001 CENTRAL EXPRESS.",
        "Fleet name cannot be empty!",
        "Fleet F102 is not found!",
        "Driver d101 is not found in the current fleet!",
        "Driver d000 is not found in the current fleet!",
    )
    missing = out.find("Driver d101 is not found")
    if "Role (" in out[missing:missing + 80]:
        raise SystemExit("role was requested for a missing driver")
    block = lists(out)[-1]
    undo_part, redo_part = block.split("Redo List")
    if "METRO" in undo_part or "F102" in undo_part:
        raise SystemExit("undone commands still on the undo list:\n" + block)
    if "Change fleet name, F001, METRO EXPRESS" not in redo_part:
        raise SystemExit(block)
    if "Create refrigerated truck fleet, F102, FROST LINE" not in redo_part:
        raise SystemExit(block)
    print("cross-fleet undo passed")

    out = run("""c
v
F001
CENTRAL EXPRESS
a
d001, Alex Chan
1
u
l
q
d
d999
l
a
d002, Jamie Lee
2
l
r
x""".splitlines())
    blocks = lists(out)
    if blocks[0] != blocks[1]:
        raise SystemExit("a failed command changed the history")
    if "Add driver, d001, Alex Chan, van driver" not in blocks[0].split("Redo List")[1]:
        raise SystemExit(blocks[0])
    if "d001" in blocks[2]:
        raise SystemExit("redo list was not cleared:\n" + blocks[2])
    if "Add driver, d002, Jamie Lee, courier driver" not in blocks[2]:
        raise SystemExit(blocks[2])
    expect(out, "Nothing to redo!")
    print("redo-clear session passed")

    out = run("""c
V
F001
CENTRAL EXPRESS
a
d001, Alex Chan
1
c
R
F102
FROST LINE
a
d101, Morgan Wong
2
u
u
u
u
sa
sf
u
r
r
r
r
sf
sa
x""".splitlines())
    expect(
        out,
        "Command (Add driver, d101, Morgan Wong, cold-chain delivery driver) is undone.",
        "Command (Create refrigerated truck fleet, F102, FROST LINE) is undone.",
        "Command (Add driver, d001, Alex Chan, van driver) is undone.",
        "Command (Create delivery van fleet, F001, CENTRAL EXPRESS) is undone.",
        "No fleet record.",
        "No current fleet!",
        "Nothing to undo!",
        "Command (Create delivery van fleet, F001, CENTRAL EXPRESS) is redone.",
        "Command (Add driver, d001, Alex Chan, van driver) is redone.",
        "Command (Create refrigerated truck fleet, F102, FROST LINE) is redone.",
        "Command (Add driver, d101, Morgan Wong, cold-chain delivery driver) is redone.",
        "Refrigerated Truck Fleet FROST LINE (F102)\nRefrigerated-Truck Driver: NIL\nCold-Chain Delivery Driver:\nd101, Morgan Wong",
        "Delivery Van Fleet CENTRAL EXPRESS (F001)\nRefrigerated Truck Fleet FROST LINE (F102)",
    )
    print("full undo/redo passed")
    print("all checks passed")


if __name__ == "__main__":
    main()
