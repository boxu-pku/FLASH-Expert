#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
flash_plot_all.py — FLASH 4.8 plotfile 一键可视化

用法:
  python flash_plot_all.py <plotfile_or_dir> [options]

选项:
  --fields dens,tele,tion    指定物理量（默认全部主流变量）
  --outdir ./plots           输出目录（默认当前目录）
  --dpi 150                  图片分辨率

例子:
  # 画单个 plotfile 的所有主流变量
  python flash_plot_all.py cases/LaserSlab/01-data/lasslab_hdf5_plt_cnt_0050

  # 只画密度和电子温度
  python flash_plot_all.py cases/LaserSlab/01-data/lasslab_hdf5_plt_cnt_0050 --fields dens,tele

  # 批量画整个目录的所有 plotfile
  python flash_plot_all.py cases/LaserSlab/01-data/ --fields dens,tele

  # X 射线诊断可视化
  python flash_plot_all.py cases/Sunliang_Xray/01-data/lasslab_XrayDetectorFile01 --xray
"""

import sys
import os
import glob
import argparse

def plot_plotfile(fname, fields, outdir, dpi):
    """用 yt 画 FLASH plotfile 的物理量切片图"""
    import yt

    ds = yt.load(fname)
    sim_time = float(ds.current_time)
    basename = os.path.basename(fname)

    # 默认主流变量
    if fields is None:
        all_fields = [f[1] for f in ds.field_list if f[0] == 'flash']
        fields = []
        for f in ['dens', 'tele', 'tion', 'trad', 'pres', 'depo', 'velx', 'vely',
                   'eion', 'eele', 'erad', 'gamc', 'shok']:
            if f in all_fields:
                fields.append(f)

        # 加 species 质量分数
        for f in all_fields:
            if f.startswith(('cham', 'tar', 'targ')) and f not in fields:
                fields.append(f)

    print(f"  加载: {basename} (t={sim_time:.3e} s)")
    print(f"  画 {len(fields)} 个变量: {fields}")

    for field in fields:
        try:
            slc = yt.SlicePlot(ds, "theta", ("flash", field))

            # 设置颜色
            if field in ['dens', 'tele', 'tion', 'trad', 'pres', 'depo']:
                slc.set_log(field, True)
            else:
                slc.set_log(field, False)

            cmaps = {
                'dens': 'viridis', 'tele': 'plasma', 'tion': 'inferno',
                'trad': 'magma', 'pres': 'coolwarm', 'depo': 'hot',
                'velx': 'RdBu_r', 'vely': 'RdBu_r',
            }
            slc.set_cmap(field, cmaps.get(field, 'viridis'))

            slc.set_xlabel("R (cm)")
            slc.set_ylabel("Z (cm)")
            slc.annotate_title(f"{field} — {basename} (t={sim_time:.2e} s)")
            slc.set_figure_size(5)

            outname = f"{basename}_{field}.png"
            outpath = os.path.join(outdir, outname)
            slc.save(outpath)
            print(f"    ✓ {field} → {outname}")
        except Exception as e:
            print(f"    ✗ {field}: {e}")


def plot_xray(fname, outdir, dpi):
    """画 X 射线探测器文件的投影像"""
    import numpy as np
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt

    data = np.loadtxt(fname)
    x, y, transmission = data[:, 0], data[:, 1], data[:, 2]
    basename = os.path.basename(fname)

    print(f"  X 射线: {basename} ({len(x)} 根)")

    fig, axes = plt.subplots(1, 2, figsize=(12, 5))

    # 散点图
    ax1 = axes[0]
    sc = ax1.scatter(x, y, c=transmission, cmap='gray', s=0.05, vmin=0, vmax=1)
    ax1.set_xlabel("Detector X (cm)")
    ax1.set_ylabel("Detector Y (cm)")
    ax1.set_title(f"X-ray scatter ({basename})")
    ax1.set_aspect('equal')
    plt.colorbar(sc, ax=ax1, label='Transmission')

    # 像素化投影像
    ax2 = axes[1]
    H, xedges, yedges = np.histogram2d(x, y, bins=100, weights=transmission)
    extent = [xedges[0], xedges[-1], yedges[0], yedges[-1]]
    im = ax2.imshow(H.T, extent=extent, origin='lower', cmap='hot', aspect='equal')
    ax2.set_xlabel("Detector X (cm)")
    ax2.set_ylabel("Detector Y (cm)")
    ax2.set_title(f"X-ray image 100x100 ({basename})")
    plt.colorbar(im, ax=ax2, label='Transmission (summed)')

    plt.tight_layout()
    outpath = os.path.join(outdir, f"{basename}_xray.png")
    plt.savefig(outpath, dpi=dpi)
    plt.close()
    print(f"  ✓ → {basename}_xray.png")


def main():
    parser = argparse.ArgumentParser(description="FLASH plotfile 一键可视化")
    parser.add_argument("target", help="plotfile 文件 / plotfile 目录 / X 射线探测器文件")
    parser.add_argument("--fields", default=None, help="逗号分隔的物理量名（如 dens,tele）")
    parser.add_argument("--outdir", default=".", help="输出目录")
    parser.add_argument("--dpi", type=int, default=150, help="图片分辨率")
    parser.add_argument("--xray", action="store_true", help="X 射线诊断可视化模式")
    args = parser.parse_args()

    os.makedirs(args.outdir, exist_ok=True)

    # X 射线模式
    if args.xray or "XrayDetector" in args.target:
        plot_xray(args.target, args.outdir, args.dpi)
        return

    # 解析物理量
    fields = args.fields.split(',') if args.fields else None

    # 单个文件 vs 目录
    if os.path.isdir(args.target):
        # 批量：目录下所有 plotfile
        plots = sorted(glob.glob(os.path.join(args.target, "*hdf5_plt*")))
        if not plots:
            print(f"✗ 在 {args.target} 下没找到 plotfile")
            return
        print(f"找到 {len(plots)} 个 plotfile")
        for p in plots:
            plot_plotfile(p, fields, args.outdir, args.dpi)
    else:
        # 单个文件
        if not os.path.exists(args.target):
            print(f"✗ 文件不存在: {args.target}")
            return
        plot_plotfile(args.target, fields, args.outdir, args.dpi)

    print(f"\n完成！图片在 {args.outdir}/")


if __name__ == "__main__":
    main()
