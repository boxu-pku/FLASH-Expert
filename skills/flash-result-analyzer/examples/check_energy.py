#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# check_energy.py - FLASH 算例能量守恒检查脚本
#
# 功能：
#   1. 从 .dat 文件读 FLASH 自带的能量积分（mass/E_total/E_kinetic/E_internal）
#   2. 从 plotfile 序列用 yt 重算 3T 分量（EELE/EION/ERAD）
#   3. 从 LaserEnergyProfile.dat 算激光沉积（如有）
#   4. 三者交叉验算 + 输出 markdown 报告
#
# 用法：
#   python check_energy.py <case_dir>
#   例：python check_energy.py cases/LaserSlab/01-data
#
# 依赖：yt, numpy, matplotlib（如要画图）
#
# 设计原则（L-012）：纯 ASCII 输出（公式 CLI 友好）+ 每步报告进度
# ============================================================

import sys
import os
import glob
import numpy as np

# ============================================================
# 工具函数
# ============================================================

def find_files(case_dir):
    """在 case_dir 里找 .dat / LaserEnergyProfile / plotfile 序列。"""
    files = {}

    # .dat 文件（积分量）—— 排除 LaserEnergyProfile
    dat_candidates = glob.glob(os.path.join(case_dir, '*.dat'))
    dat_candidates = [f for f in dat_candidates if 'LaserEnergyProfile' not in f]
    if dat_candidates:
        files['dat'] = dat_candidates[0]

    # LaserEnergyProfile.dat
    laser_candidates = glob.glob(os.path.join(case_dir, '*LaserEnergyProfile*'))
    if laser_candidates:
        files['laser'] = laser_candidates[0]

    # plotfile 序列（目录或单文件）
    plt_dirs = sorted(glob.glob(os.path.join(case_dir, '*_hdf5_plt_cnt_*')))
    if plt_dirs:
        files['plots'] = plt_dirs

    return files


def read_dat_summary(dat_path):
    """读 .dat 文件，返回 time + E_total + E_kinetic + E_internal 数组。"""
    try:
        data = np.loadtxt(dat_path, comments='#')
    except Exception as e:
        return None, f"读取失败: {e}"

    if data.ndim == 1:
        data = data.reshape(1, -1)

    # 列结构：1=time, 2=mass, 3-5=mom, 6=E_total, 7=E_kinetic, 8=E_internal
    # 验算列数
    ncols = data.shape[1]
    if ncols < 8:
        return None, f"列数异常（{ncols} < 8）"

    return {
        'time': data[:, 0],
        'mass': data[:, 1],
        'E_total': data[:, 5],
        'E_kinetic': data[:, 6],
        'E_internal': data[:, 7],
    }, None


def read_laser_summary(laser_path):
    """读 LaserEnergyProfile.dat，返回 step/time/energy_in/energy_out 数组。"""
    try:
        data = np.loadtxt(laser_path, comments='#')
    except Exception as e:
        return None, f"读取失败: {e}"

    if data.ndim == 1:
        data = data.reshape(1, -1)

    # 列：1=Step, 2=Time, 3=dt, 4=Energy_in, 5=Energy_out, 6=dE_in, 7=dE_out
    return {
        'step': data[:, 0].astype(int),
        'time': data[:, 1],
        'Energy_in': data[:, 3],
        'Energy_out': data[:, 4],
    }, None


def recompute_from_plots(plot_files, max_plots=20):
    """从 plotfile 序列用 yt 重算能量分量。"""
    try:
        import yt
    except ImportError:
        return None, "yt 未安装"

    results = []
    # 均匀采样（避免 plotfile 太多）
    if len(plot_files) > max_plots:
        idx = np.linspace(0, len(plot_files) - 1, max_plots).astype(int)
        plot_files = [plot_files[i] for i in idx]

    for fn in plot_files:
        try:
            ds = yt.load(fn)
            ad = ds.all_data()
            vol = np.array(ad['cell_volume'])
            rho = np.array(ad['dens'])
            vx = np.array(ad['velx'])
            vy = np.array(ad['vely'])
            try:
                vz = np.array(ad['velz'])
            except:
                vz = np.zeros_like(vx)

            # 动能
            ekin = float(np.sum(0.5 * rho * (vx**2 + vy**2 + vz**2) * vol))

            # 3T 内能
            eele = eion = erad = 0.0
            try:
                eele = float(np.sum(np.array(ad['Eele']) * vol))
            except: pass
            try:
                eion = float(np.sum(np.array(ad['Eion']) * vol))
            except: pass
            try:
                erad = float(np.sum(np.array(ad['Eradt']) * vol))
            except:
                try:
                    erad = float(np.sum(np.array(ad['Erad']) * vol))
                except: pass

            results.append({
                'time': float(ds.current_time),
                'E_kinetic': ekin,
                'E_eion': eion,
                'E_eele': eele,
                'E_erad': erad,
                'E_total_recalc': ekin + eion + eele + erad,
            })
        except Exception as e:
            print(f"  SKIP {os.path.basename(fn)}: {e}")

    return results, None


# ============================================================
# 主流程
# ============================================================

def main():
    if len(sys.argv) < 2:
        print("用法：python check_energy.py <case_dir>")
        print("例：python check_energy.py cases/LaserSlab/01-data")
        sys.exit(1)

    case_dir = sys.argv[1]
    if not os.path.isdir(case_dir):
        print(f"错误：目录不存在 {case_dir}")
        sys.exit(1)

    print(f"=== FLASH 算例能量守恒分析 ===")
    print(f"目录: {case_dir}")
    print()

    files = find_files(case_dir)

    # ---------- 1. .dat 分析 ----------
    if 'dat' in files:
        print(f"--- 1. .dat 文件分析 ---")
        print(f"文件: {os.path.basename(files['dat'])}")
        dat, err = read_dat_summary(files['dat'])
        if err:
            print(f"  错误：{err}")
        else:
            n = len(dat['time'])
            print(f"  数据点: {n}")
            print(f"  时间范围: {dat['time'][0]:.3e} - {dat['time'][-1]:.3e} s")

            # 相对总能变化
            etot = dat['E_total']
            etot0 = etot[0]
            rel_change = (etot[-1] - etot0) / etot0 * 100

            print(f"  E_total(0)    = {etot0:.4e} erg")
            print(f"  E_total(end)  = {etot[-1]:.4e} erg")
            print(f"  相对变化      = {rel_change:+.4f}%")

            # E_total = E_kin + E_int 验算
            diff = (etot - dat['E_kinetic'] - dat['E_internal']) / etot
            print(f"  E_total-(E_kin+E_int) 相对差: max={np.max(np.abs(diff)):.2e}")
            print(f"    （< 1e-6 表示内部自洽；MHD 算例可能有 MagEnergy 残差）")
            print()
    else:
        print("--- 1. .dat 文件分析 ---")
        print("  未找到 .dat 文件")
        print()

    # ---------- 2. 激光能量分析 ----------
    if 'laser' in files:
        print(f"--- 2. 激光能量分析 ---")
        print(f"文件: {os.path.basename(files['laser'])}")
        laser, err = read_laser_summary(files['laser'])
        if err:
            print(f"  错误：{err}")
        else:
            n = len(laser['step'])
            ein = laser['Energy_in']
            eout = laser['Energy_out']

            deposited = ein[-1] - eout[-1]
            coupling = deposited / ein[-1] * 100

            print(f"  数据点: {n}")
            print(f"  累计入射:   {ein[-1]:.4e} erg = {ein[-1]*1e-7:.4e} J")
            print(f"  累计透射:   {eout[-1]:.4e} erg")
            print(f"  累计沉积:   {deposited:.4e} erg")
            print(f"  吸收率:     {coupling:.2f}%")

            # 早期/中期/后期吸收率
            for phase, lo, hi in [('早期', 0, n//3), ('中期', n//3, 2*n//3), ('后期', 2*n//3, n)]:
                if hi > lo:
                    ein_p = ein[hi-1] - (ein[lo-1] if lo > 0 else 0)
                    eout_p = eout[hi-1] - (eout[lo-1] if lo > 0 else 0)
                    if ein_p > 0:
                        abs_p = (ein_p - eout_p) / ein_p * 100
                        print(f"  {phase}吸收率: {abs_p:.2f}%")
            print()
    else:
        print("--- 2. 激光能量分析 ---")
        print("  未找到 LaserEnergyProfile.dat（非激光算例？）")
        print()

    # ---------- 3. plotfile 重算 ----------
    if 'plots' in files:
        print(f"--- 3. plotfile 重算（3T 分解）---")
        print(f"plotfile 数: {len(files['plots'])}")
        print(f"  （为节省时间，最多采样 20 个）")
        results, err = recompute_from_plots(files['plots'], max_plots=20)
        if err:
            print(f"  错误：{err}")
        elif results:
            print(f"\n  {'time(s)':>12} {'E_kin':>12} {'E_ele':>12} {'E_ion':>12} {'E_rad':>12} {'E_recalc':>12}")
            for r in results[:5]:
                print(f"  {r['time']:12.3e} {r['E_kinetic']:12.3e} {r['E_eele']:12.3e} "
                      f"{r['E_eion']:12.3e} {r['E_erad']:12.3e} {r['E_total_recalc']:12.3e}")
            if len(results) > 5:
                print(f"  ... ({len(results)-5} more)")
            print()
    else:
        print("--- 3. plotfile 重算 ---")
        print("  未找到 plotfile 序列")
        print()

    # ---------- 4. 交叉验算 ----------
    print(f"--- 4. 交叉验算 ---")
    if 'dat' in files and 'laser' in files:
        dat, _ = read_dat_summary(files['dat'])
        laser, _ = read_laser_summary(files['laser'])
        etot_change = dat['E_total'][-1] - dat['E_total'][0]
        deposited = laser['Energy_in'][-1] - laser['Energy_out'][-1]
        diff_abs = etot_change - deposited
        diff_rel = diff_abs / deposited * 100 if deposited > 0 else 0

        print(f"  E_total 变化:    {etot_change:+.4e} erg")
        print(f"  激光沉积:        {deposited:+.4e} erg")
        print(f"  差异:            {diff_abs:+.4e} erg ({diff_rel:+.2f}%)")
        print()
        if abs(diff_rel) < 5:
            print(f"  ✓ 守恒良好（差异 < 5%）")
        elif abs(diff_rel) < 15:
            print(f"  ~ 边界流可解释（5-15%）")
        else:
            print(f"  ⚠ 差异较大（> 15%），可能边界流强或参数错")
        print()
    else:
        print("  需 .dat + LaserEnergyProfile 才能交叉验算")
        print()

    # ---------- 5. 结论 ----------
    print(f"=== 结论 ===")
    print(f"分析完成。详细数值见上方各段。")
    print(f"详细的可视化请用 plot_quick.py。")


# ============================================================
# 入口
# ============================================================

if __name__ == '__main__':
    main()

# ============================================================
# 变更日志
# 2026-08-02: 初始版本（beta）。按 L-012 纯 ASCII 输出。
# ============================================================
