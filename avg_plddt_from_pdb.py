#!/usr/bin/env python3

from Bio.PDB import PDBParser
import sys

def get_all_bfactors(pdb_file):
    parser = PDBParser(QUIET=True)
    structure = parser.get_structure("model", pdb_file)
    return [atom.get_bfactor() for atom in structure.get_atoms()]

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("用法: python avg_plddt_from_pdb.py chainA.pdb chainB.pdb ...")
        sys.exit(1)

    all_plddt = []
    for pdb_file in sys.argv[1:]:
        try:
            b_factors = get_all_bfactors(pdb_file)
            if b_factors:
                avg = sum(b_factors) / len(b_factors)
                print(f"{pdb_file}: {len(b_factors)} atoms, avg pLDDT = {avg:.2f}")
                all_plddt.extend(b_factors)
            else:
                print(f"{pdb_file}: 没有找到 B-factor 值")
        except Exception as e:
            print(f"{pdb_file}: 读取失败 - {str(e)}")

    if all_plddt:
        overall_avg = sum(all_plddt) / len(all_plddt)
        print(f"\nCombined average pLDDT for all chains: {overall_avg:.2f}")
    else:
        print("所有文件中都没有 B-factor 数据")

