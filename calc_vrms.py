#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Silent VRMS REMARK writer:
- Compute VRMS from a source PDB (pattern allowed, must match exactly one file)
  by residue-averaging pLDDT (> threshold) taken from the penultimate whitespace
  column of ATOM/HETATM records.
- Insert or replace a REMARK line with VRMS at the first line of one or more target PDBs.

Usage:
  python calc_vrms_write_remark_silent.py "AF_*.pdb" "pdb_*.pdb"
  # optional params
  python calc_vrms_write_remark_silent.py "AF_*.pdb" "pdb_*.pdb" --threshold 70 --slope 1.0 --intercept 0.25
"""

import argparse
import math
from pathlib import Path
from collections import defaultdict
import glob
import sys

def parse_atom_line(line: str):
    """Extract (chain, resseq, icode, plddt) from an ATOM/HETATM line."""
    if not (line.startswith("ATOM") or line.startswith("HETATM")):
        return None
    parts = line.split()
    if len(parts) < 2:
        return None
    try:
        plddt = float(parts[-2])  # penultimate column
    except ValueError:
        return None
    try:
        chain = line[21].strip()
        resseq = line[22:26].strip()
        icode = line[26].strip()
        if not resseq:
            raise ValueError
    except Exception:
        if len(parts) >= 6:
            chain = parts[4]
            resseq = parts[5]
            icode = ""
        else:
            return None
    return chain, resseq, icode, plddt

def residue_avg_plddt(pdb_path: Path, threshold: float = 70.0):
    """Residue-average pLDDT, then average across residues with mean pLDDT > threshold."""
    per_residue_vals = defaultdict(list)
    with pdb_path.open("r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            if not (line.startswith("ATOM") or line.startswith("HETATM")):
                continue
            parsed = parse_atom_line(line)
            if parsed:
                chain, resseq, icode, plddt = parsed
                per_residue_vals[(chain, resseq, icode)].append(plddt)
    if not per_residue_vals:
        return 0, None
    per_residue_avgs = {k: sum(v) / len(v) for k, v in per_residue_vals.items()}
    selected = [v for v in per_residue_avgs.values() if v > threshold]
    if not selected:
        return 0, None
    return len(selected), sum(selected) / len(selected)

def plddt_to_vrms(avg_plddt: float, slope: float = 1.0, intercept: float = 0.25):
    """Convert average pLDDT to VRMS."""
    frac = avg_plddt / 100.0
    rmsd_est = 1.5 * math.exp(4.0 * (0.7 - frac))
    vrms = slope * rmsd_est + intercept
    return rmsd_est, vrms

def write_remark_with_vrms(source_pdb: Path, target_pdb: Path,
                           threshold: float, slope: float, intercept: float):
    """Compute VRMS from source and insert/replace REMARK at first line of target."""
    _, avg_plddt = residue_avg_plddt(source_pdb, threshold)
    if avg_plddt is None:
        remark_text = f"REMARK   VRMS=N/A; pLDDT>{int(threshold)}"
    else:
        _, vrms = plddt_to_vrms(avg_plddt, slope, intercept)
        remark_text = f"REMARK   VRMS={vrms:.3f} A; pLDDT>{int(threshold)}"
    lines = target_pdb.read_text(encoding="utf-8", errors="ignore").splitlines(True)
    if lines and lines[0].startswith("REMARK   VRMS="):
        lines[0] = remark_text + "\n"
    else:
        lines.insert(0, remark_text + "\n")
    target_pdb.write_text("".join(lines), encoding="utf-8")

def main():
    ap = argparse.ArgumentParser(
        description="Silent VRMS REMARK writer: source PDB pattern must match exactly one; targets can be many."
    )
    ap.add_argument("source_pdb", help="Source PDB filename or pattern (must match exactly one), e.g., 'AF_*.pdb'.")
    ap.add_argument("target_pattern", help="Target PDB filename pattern, e.g., 'pdb_*.pdb'.")
    ap.add_argument("--threshold", type=float, default=70.0, help="Residue-average pLDDT threshold (default: 70)")
    ap.add_argument("--slope", type=float, default=1.0, help="vrms_from_rmsd_slope (default: 1.0)")
    ap.add_argument("--intercept", type=float, default=0.25, help="vrms_from_rmsd_intercept in Å (default: 0.25)")
    args = ap.parse_args()

    src_matches = glob.glob(args.source_pdb)
    if len(src_matches) != 1:
        print(f"[Error] Source pattern '{args.source_pdb}' matched {len(src_matches)} files: {src_matches}", file=sys.stderr)
        sys.exit(1)
    src = Path(src_matches[0])

    target_matches = glob.glob(args.target_pattern)
    if not target_matches:
        print(f"[Error] Target pattern '{args.target_pattern}' matched 0 files.", file=sys.stderr)
        sys.exit(2)
    targets = [Path(p) for p in sorted(set(target_matches))]

    for tgt in targets:
        if tgt.is_file():
            write_remark_with_vrms(src, tgt, args.threshold, args.slope, args.intercept)

if __name__ == "__main__":
    main()

