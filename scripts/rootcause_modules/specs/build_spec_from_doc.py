#!/usr/bin/env python3
r"""Parse a *_DETECTION.md 'what it detects' numbered list into a catalog spec.

Extracts lines like:
    12. **Title of the detection** (`XYZ-012`) — description text...
into root causes (synthetic sequential IDs SEC-SQL-<AREA>-NNN-RC01), with
detect=None for all vendors (catalog registration; detection SQL is filled in
later, or generated from the module's knowledge JSON when available).

Usage:
    python build_spec_from_doc.py <doc.md> <module_name> <AREA> > specs/<module>.json
"""
import json
import re
import sys

LINE = re.compile(r"^\s*\d+\.\s+\*\*(.+?)\*\*\s*(.*)$")
TRAIL_ID = re.compile(r"\s*\(`?[A-Z]{2,5}-\d{2,3}`?\)\s*$")


def slugify(s):
    s = re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")
    return s[:60]


def parse(path, module, area):
    rcs = []
    n = 0
    with open(path, "r", encoding="utf-8") as f:
        for raw in f:
            m = LINE.match(raw)
            if not m:
                continue
            title = m.group(1).strip()
            rest = m.group(2).strip()
            # title may carry a trailing (`ID`); pull it off
            title = TRAIL_ID.sub("", title).strip()
            # description = text after a leading dash/emdash, else the rest
            desc = re.sub(r"^[—\-:\s]+", "", rest).strip()
            desc = TRAIL_ID.sub("", desc).strip()
            if not title:
                continue
            n += 1
            rcs.append({
                "rc": f"SEC-SQL-{area}-{n:03d}-RC01",
                "issue": f"SEC-SQL-{area}-{n:03d}",
                "name": title[:200],
                "slug": f"{area.lower()}-{n:03d}-" + slugify(title),
                "description": (desc or title)[:1000],
                "topics": [module, area.lower()],
                "risk_level": "high",
                "resolution": "TODO: see "
                              + module.upper() + "_DETECTION.md / the module knowledge JSON.",
                "expected": {"condition": "row_count > 0", "description": title[:200]},
                "columns": [],
                "detect": {"postgresql": None, "sqlserver": None, "oracle": None, "mysql": None},
            })
    return {
        "module": module, "area_code": area,
        "source": path, "vendors": ["postgresql", "sqlserver", "oracle", "mysql"],
        "_coverage_note": f"{len(rcs)} root causes parsed from the doc's enumerated "
                          "detections; detection SQL is TODO (fill specs or generate from "
                          "the knowledge JSON). The module's JSON may list more RCs than the prose enumerates.",
        "root_causes": rcs,
    }


if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("usage: build_spec_from_doc.py <doc.md> <module> <AREA>", file=sys.stderr)
        sys.exit(2)
    sys.stdout.write(json.dumps(parse(sys.argv[1], sys.argv[2], sys.argv[3]), indent=2))
    sys.stdout.write("\n")
