#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# laser_coupling.py - FLASH 激光算例吸收率分析
#
# 功能：
#   1. 从 LaserEnergyProfile.dat 读 Energy_in / Energy_out
#   2. 算累积/瞬时吸收率
#   3. 输出 ASCII 报告 + 可选 matplotlib 图
#
# 用法：
#   python laser_coupling.py <LaserEnergyProfile.dat>
#   python laser_coupling.py cases/LaserSlab/01-data/lasslab_LaserEnergyProfile.dat
#   python laser_coupling.py <file> --plot    # 同时画图
#
# 依赖：numpy（必装）；matplotlib（可选，画图时）
#
# 文件结构（source/.../EnergyDeposition_init.F90:L431）：
#   #Step  Time(s)  dt(s)  Energy_in(erg)  Energy_out(erg)  dE_in(erg)  dE_out(erg)
#   #                                           （第 2 行是空 # 注释）
#       1  1.0E-15  1.0E-15  ...
#
# 设计原则（L-012）：纯 ASCII 输出 + 报告进度
# ============================================================

import sys
import os
import numpy as np


def read_laser_profile(fn):
    """读 LaserEnergyProfile.dat。"""
    try:
        # comments='#' 跳过两行 # 开头的注释
        data = np.loadtxt(fn, comments='#')
    except Exception as e:
        return None, f"读取失败: {e}"

    if data.ndim == 1:
        data = data.reshape(1, -1)

    # 列：1=Step, 2=Time, 3=dt, 4=Energy_in, 5=Energy_out, 6=dE_in, 7=dE_out
    if data.shape[1] < 5:
        return None, f"列数异常（{data.shape[1]} < 5）"

    return {
        'step': data[:, 0].astype(int),
        'time': data[:, 1],
        'dt': data[:, 2],
        'Energy_in': data[:, 3],
        'Energy_out': data[:, 4],
        'dE_in': data[:, 5] if data.shape[1] > 5 else None,
        'dE_out': data[:, 6] if data.shape[1] > 6 else None,
    }, None


def analyze(data):
    """算累积/瞬时吸收率。"""
    ein = data['Energy_in']
    eout = data['Energy_out']

    # 累积吸收率
    cumul_abs = np.where(ein > 0, (ein - eout) / ein * 100, 0)

    # 瞬时吸收率
    if data['dE_in'] is not None:
        dein = data['dE_in']
        deout = data['dE_out']
        inst_abs = np.where(dein > 0, (dein - deout) / dein * 100, 0)
    else:
        # 从累积值反推（差分）
        dein = np.diff(ein, prepend=0)
        deout = np.diff(eout, prepend=0)
        inst_abs = np.where(dein > 0, (dein - deout) / dein * 100, 0)

    return cumul_abs, inst_abs


def report(data, cumul_abs, inst_abs, fn):
    """输出 ASCII 报告。"""
    n = len(data['step'])
    ein = data['Energy_in']
    eout = data['Energy_out']

    print(f"=== 激光吸收率分析 ===")
    print(f"文件: {os.path.basename(fn)}")
    print(f"数据点: {n}")
    print()

    # 总体
    total_ein = ein[-1]
    total_eout = eout[-1]
    total_deposited = total_ein - total_eout
    total_coupling = total_deposited / total_ein * 100 if total_ein > 0 else 0

    print(f"--- 总体 ---")
    print(f"总入射能量:     {total_ein:.4e} erg = {total_ein*1e-7:.4e} J")
    print(f"总透射能量:     {total_eout:.4e} erg")
    print(f"总沉积能量:     {total_deposited:.4e} erg")
    print(f"累积吸收率:     {total_coupling:.2f}%")
    print()

    # 时间演化（前 5 + 后 5）
    print(f"--- 时间演化 ---")
    print(f"{'Step':>6} {'Time(s)':>12} {'dt(s)':>10} {'E_in':>12} {'E_out':>12} {'瞬时%':>8} {'累积%':>8}")

    show_idx = list(range(min(5, n))) + (list(range(max(5, n-5), n)) if n > 5 else [])
    show_idx = sorted(set(show_idx))

    for i in show_idx:
        marker = '  '
        if i == 5 and n > 10:
            print(f"{'...':>6} {'...':>12} {'...':>10} {'...':>12} {'...':>12} {'...':>8} {'...':>8}")
        print(f"{data['step'][i]:6d} {data['time'][i]:12.3e} {data['dt'][i]:10.3e} "
              f"{ein[i]:12.4e} {eout[i]:12.4e} {inst_abs[i]:8.2f} {cumul_abs[i]:8.2f}")
    print()

    # 阶段分析（早/中/晚）
    print(f"--- 阶段分析 ---")
    for phase, lo, hi in [('早期', 0, n//3), ('中期', n//3, 2*n//3), ('后期', 2*n//3, n)]:
        if hi > lo:
            ein_p = ein[hi-1] - (ein[lo-1] if lo > 0 else 0)
            eout_p = eout[hi-1] - (eout[lo-1] if lo > 0 else 0)
            if ein_p > 0:
                abs_p = (ein_p - eout_p) / ein_p * 100
                print(f"{phase}: {abs_p:6.2f}%")
    print()

    # 异常判断
    print(f"--- 异常判断 ---")
    if total_coupling < 30:
        print(f"⚠ 吸收率偏低（< 30%），可能原因：")
        print(f"  - 激光波长过短（如 351 nm vs 527 nm）→ parfile ed_wavelength")
        print(f"  - 临界密度过低（密度太小）→ plotfile dens 是否 < 0.01 g/cm^3")
        print(f"  - 不透明度表错 → 检查 .imx 表 cross-section")
    elif total_coupling > 95:
        print(f"⚠ 吸收率过高（> 95%），可能原因：")
        print(f"  - 域太小（激光没机会出去）→ 看 domain 范围")
        print(f"  - 不透明度表过大")
    else:
        print(f"✓ 吸收率在正常范围（30-95%）")
    print()

    # 配合建议
    print(f"--- 后续分析 ---")
    print(f"  1. 验算能量守恒：")
    print(f"     awk 'NR>2 {{et=$6; if(NR==3)et0=et}} END {{printf \"E_total 变化 = %.4f%%\\n\", (et-et0)/et0*100}}' \\")
    print(f"       $(dirname {fn})/$(basename {fn} _LaserEnergyProfile.dat).dat")
    print(f"  2. 期望：E_total 变化 ≈ 激光沉积（差异由边界流/辐射逃逸解释）")


def plot_coupling(data, cumul_abs, inst_abs, output='coupling.png'):
    """画吸收率时间演化图。"""
    try:
        import matplotlib.pyplot as plt
    except ImportError:
        print(f"matplotlib 未安装，跳过画图")
        return

    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 8), sharex=True)

    # 上图：累积能量
    ax1.semilogx(data['time'], data['Energy_in'], 'b-', label='Energy_in', linewidth=2)
    ax1.semilogx(data['time'], data['Energy_out'], 'r--', label='Energy_out', linewidth=1.5)
    ax1.semilogx(data['time'], data['Energy_in'] - data['Energy_out'],
                 'g-.', label='Deposited', linewidth=2)
    ax1.set_ylabel('Cumulative energy (erg)')
    ax1.legend(loc='upper left')
    ax1.grid(True, which='both', alpha=0.3)
    ax1.set_title('Laser energy profile')

    # 下图：吸收率
    ax2.semilogx(data['time'], cumul_abs, 'b-', label='Cumulative', linewidth=2)
    ax2.semilogx(data['time'], inst_abs, 'r-', alpha=0.5, label='Instantaneous', linewidth=1)
    ax2.axhline(cumul_abs[-1], color='b', linestyle=':', alpha=0.5,
                label=f'Final: {cumul_abs[-1]:.2f}%')
    ax2.set_xlabel('Time (s)')
    ax2.set_ylabel('Coupling efficiency (%)')
    ax2.legend(loc='lower right')
    ax2.grid(True, which='both', alpha=0.3)
    ax2.set_ylim(0, 100)

    plt.tight_layout()
    plt.savefig(output, dpi=150, bbox_inches='tight')
    plt.close()
    print(f"\n图已保存: {output}")


# ============================================================
# 主流程
# ============================================================

def main():
    if len(sys.argv) < 2:
        print("用法：python laser_coupling.py <LaserEnergyProfile.dat> [--plot]")
        print("例：python laser_coupling.py cases/LaserSlab/01-data/lasslab_LaserEnergyProfile.dat --plot")
        sys.exit(1)

    fn = sys.argv[1]
    do_plot = '--plot' in sys.argv

    if not os.path.isfile(fn):
        print(f"错误：文件不存在 {fn}")
        sys.exit(1)

    data, err = read_laser_profile(fn)
    if err:
        print(f"错误：{err}")
        sys.exit(1)

    cumul_abs, inst_abs = analyze(data)
    report(data, cumul_abs, inst_abs, fn)

    if do_plot:
        plot_coupling(data, cumul_abs, inst_abs)


# ============================================================
# 入口
# ============================================================

if __name__ == '__main__':
    main()

# ============================================================
# 变更日志
# 2026-08-02: 初始版本（beta）。纯 ASCII 报告 + 可选画图。
# ============================================================
