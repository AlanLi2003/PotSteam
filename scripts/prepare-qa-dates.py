#!/usr/bin/env python3
"""Prepare relative dates only on the explicitly reserved QA 100 Simulator."""
import datetime
import json
import os
from pathlib import Path
import subprocess

QA_DEVICE = "734C746B-F86E-436C-97B3-ABB2F39E06DD"
BUNDLE = "com.cnrecipe.app"

def simctl(*args, **kwargs):
    return subprocess.run(["xcrun", "simctl", *args], **kwargs)

devices = json.loads(simctl("list", "devices", "--json", check=True,
                           capture_output=True, text=True).stdout)
device = next((d for group in devices["devices"].values() for d in group
               if d["udid"] == QA_DEVICE), None)
if not device or device["name"] != "CNrecipe iPhone 16 QA 100" or device["state"] != "Booted":
    raise SystemExit("Expected the booted, dedicated CNrecipe iPhone 16 QA 100; no data changed.")
container = Path(simctl("get_app_container", QA_DEVICE, BUNDLE, "data", check=True,
                       capture_output=True, text=True).stdout.strip())
if QA_DEVICE not in str(container):
    raise SystemExit("Unexpected container path; no data changed.")
# The App must not race an atomic fixture write. Never use `booted` as the target.
simctl("terminate", QA_DEVICE, BUNDLE, capture_output=True)
folder = container / "Library/Application Support/CNrecipe"
file = folder / "state-v2-device.json"
folder.mkdir(parents=True, exist_ok=True)
state = {"version": 2, "entities": [], "outbox": [], "conflicts": [], "cursor": 0}
if file.exists():
    raw = file.read_bytes()
    state = json.loads(raw)
    if state.get("version") != 2:
        raise SystemExit("Unexpected saved version; no data changed.")
    backup = Path("artifacts/native-tests/fixture-backups")
    backup.mkdir(parents=True, exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    (backup / (stamp + "-state-v2-device.json")).write_bytes(raw)
today = datetime.date.today()
reserved = {"qa-tracked-near", "qa-tracked-expired"}
if any(e["entityId"] in reserved for e in state["outbox"]):
    raise SystemExit("QA date fixtures have pending edits; resolve them before reseeding.")
state["entities"] = [e for e in state["entities"] if e["id"] not in reserved]
for id, name, group, offset in [
    ("qa-tracked-near", "Tomatoes", "Produce", 1),
    ("qa-tracked-expired", "Eggs", "Dairy & Eggs", -1),
]:
    state["entities"].append({"id": id, "kind": "inventory", "revision": 0, "deleted": False,
        "data": {"name": name, "qty": "2 items", "group": group, "storage": "Fridge",
                 "type": "Review on", "added": str(today - datetime.timedelta(days=3)),
                 "until": str(today + datetime.timedelta(days=offset))}})
temporary = file.with_suffix(".fixture-tmp")
temporary.write_text(json.dumps(state, ensure_ascii=False), encoding="utf-8")
os.replace(temporary, file)
print("Prepared two relative-date fixtures on QA 100 only; existing state backed up.")
