#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# plot_quick.py - FLASH plotfile 快速可视化
#
# 功能：
#   1. 加载 plotfile（yt 自动识别 AMR）
#   2. 画主流变量切片（dens/tele/tion/trad/pres）
#   3. 叠加速度矢量（可选）
#   4. 画时间演化图（如给 plotfile 序列）
#
# 用法：
#   python plot_quick.py <plotfile>
#   python plot_quick.py <plotfile_dir>
#   python plot_quick.py cases/LaserSlab/01-data/lasslab_hdf5_plt_cnt_0050
#
# 依赖：yt, matplotlib
#
# 设计原则（L-012）：每个画图步骤报告进度 + 失败时给出诊断提示
# ============================================================

import sys
import os
import yt


# ============================================================
# 单 plotfile 画图
# ============================================================

def plot_single(fn, output_dir='figures'):
    """对单个 plotfile 画主流变量切片。"""
    os.makedirs(output_dir, exist_ok=True)

    print(f"Loading: {fn}")
    try:
        ds = yt.load(fn)
    except Exception as e:
        print(f"加载失败: {e}")
        print("诊断建议：")
        print("  1. ls -la 确认 plotfile 存在")
        print("  2. h5dump -H 看 plotfile 结构")
        print("  3. python -c 'import yt; print(yt.__version__)'")
        return False

    t = float(ds.current_time)
    print(f"Time: {t:.3e} s")
    print(f"Available fields: {len(ds.field_list)}")

    # 主流量
    # (field_name, cmap, log_scale, colorbar_label)
    fields = [
        ('dens', 'viridis', True, 'Density (g/cm^3)'),
        ('tele', 'hot', True, 'TELE (K)'),
        ('tion', 'hot', True, 'TION (K)'),
        ('trad', 'hot', True, 'TRAD (K)'),
        ('pres', 'plasma', True, 'Pressure (dyne/cm^2)'),
    ]

    # 看哪些字段实际可用
    available = set(f[0] if isinstance(f, tuple) else f for f in ds.field_list)
    available |= set(str(f[1]).lower() for f in ds.field_list)

    print(f"\n画切片...")
    saved = []
    for field, cmap, log, label in fields:
        # yt field 一般 lowercase
        if field not in available and field.upper() not in available:
            print(f"  SKIP {field}: 不在 plotfile")
            continue

        try:
            p = yt.SlicePlot(ds, 'z', field)
            p.set_log(field, log)
            p.set_cmap(field, cmap)
            p.set_colorbar_label(field, label)

            # 标题（加时间）
            p.annotate_title(f't = {t:.3e} s')

            out = os.path.join(output_dir, f'{field}_t{t:.3e}.png')
            p.save(out)
            saved.append(out)
            print(f"  Saved {out}")
        except Exception as e:
            print(f"  FAIL {field}: {e}")

    # 速度矢量叠加
    try:
        if 'velx' in available:
            p = yt.SlicePlot(ds, 'z', 'dens')
            p.set_log('dens', True)
            p.annotate_velocity(factor=16)  # factor 控制箭头密度
            p.annotate_title(f't = {t:.3e} s  (with velocity)')
            out = os.path.join(output_dir, f'dens_vel_t{t:.3e}.png')
            p.save(out)
            saved.append(out)
            print(f"  Saved {out}")
    except Exception as e:
        print(f"  SKIP velocity overlay: {e}")

    print(f"\n完成。{len(saved)} 张图保存在 {output_dir}/")
    return True


# ============================================================
# plotfile 序列画图
# ============================================================

def plot_sequence(case_dir, output_dir='frames', max_plots=20):
    """遍历 plotfile 序列画时间演化。"""
    import glob

    plots = sorted(glob.glob(os.path.join(case_dir, '*_hdf5_plt_cnt_*')))
    if not plots:
        print(f"未在 {case_dir} 找到 plotfile")
        return False

    print(f"找到 {len(plots)} 个 plotfile")

    # 均匀采样
    if len(plots) > max_plots:
        import numpy as np
        idx = np.linspace(0, len(plots) - 1, max_plots).astype(int)
        plots = [plots[i] for i in idx]
        print(f"采样 {max_plots} 个均匀分布的 plotfile")

    os.makedirs(output_dir, exist_ok=True)
    print(f"输出: {output_dir}/")
    print()

    for i, fn in enumerate(plots):
        print(f"[{i+1}/{len(plots)}] {os.path.basename(fn)}")
        try:
            ds = yt.load(fn)
            t = float(ds.current_time)

            # 只画 dens 和 tele（最主流）
            for field, cmap, label in [
                ('dens', 'viridis', 'Density (g/cm^3)'),
                ('tele', 'hot', 'TELE (K)'),
            ]:
                try:
                    p = yt.SlicePlot(ds, 'z', field)
                    p.set_log(field, True)
                    p.set_cmap(field, cmap)
                    p.set_colorbar_label(field, label)
                    p.annotate_title(f't = {t:.3e} s')
                    out = os.path.join(output_dir, f'{field}_{i:04d}.png')
                    p.save(out)
                except Exception as e:
                    print(f"  FAIL {field}: {e}")
        except Exception as e:
            print(f"  SKIP: {e}")

    print(f"\n完成。可以做 GIF:")
    print(f"  python -c \"import imageio.v2 as iio; import glob; \\")
    print(f"    with iio.get_writer('movie.gif', mode='I', duration=0.2) as w: \\")
    print(f"      [w.append_data(iio.imread(f)) for f in sorted(glob.glob('{output_dir}/dens_*.png'))]\"")
    return True


# ============================================================
# 主流程
# ============================================================

def main():
    if len(sys.argv) < 2:
        print("用法：")
        print("  python plot_quick.py <plotfile>            # 单 plotfile")
        print("  python plot_quick.py <plotfile_dir> -seq   # plotfile 序列")
        print()
        print("例：")
        print("  python plot_quick.py cases/LaserSlab/01-data/lasslab_hdf5_plt_cnt_0050")
        print("  python plot_quick.py cases/LaserSlab/01-data -seq")
        sys.exit(1)

    target = sys.argv[1]
    is_seq = len(sys.argv) > 2 and sys.argv[2] == '-seq'

    if is_seq or os.path.isdir(target):
        # 目录模式：找 plotfile 序列
        plot_sequence(target)
    else:
        # 单文件模式
        plot_single(target)


# ============================================================
# 入口
# ============================================================

if __name__ == '__main__':
    main()

# ============================================================
# 变更日志
# 2026-08-02: 初始版本（beta）。支持单 plotfile 和序列两种模式。
# ============================================================
