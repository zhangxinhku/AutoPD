#!/usr/bin/env python3

import gemmi
import sys

def get_bfactors_from_cif(cif_file):
    doc = gemmi.cif.read_file(cif_file)
    block = doc.sole_block()
    values = block.find_values('_atom_site.B_iso_or_equiv')
    b_factors = []
    for v in values:
        try:
            b_factors.append(float(v))
        except ValueError:
            continue
    return b_factors

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("用法: python avg_plddt_from_cif.py chainA.cif chainB.cif ...")
        sys.exit(1)

    all_plddt = []
    for cif_file in sys.argv[1:]:
        try:
            b_factors = get_bfactors_from_cif(cif_file)
            if b_factors:
                avg = sum(b_factors) / len(b_factors)
                print(f"{cif_file}: {len(b_factors)} atoms, avg pLDDT = {avg:.2f}")
                all_plddt.extend(b_factors)
            else:
                print(f"{cif_file}: 没有找到 B_iso_or_equiv 字段或为空")
        except Exception as e:
            print(f"{cif_file}: 读取失败 - {str(e)}")

    if all_plddt:
        overall_avg = sum(all_plddt) / len(all_plddt)
        print(f"\nCombined average pLDDT for all chains: {overall_avg:.2f}")
    else:
        print("所有文件中都没有 B-factor 数据")

