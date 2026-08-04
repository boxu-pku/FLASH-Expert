# flash-laser examples/

可直接 `cp` 使用的 parfile 片段。每个文件是**纯激光段配置**，不含 IO/网格/辐射等其他段。

## 使用方法

1. 选一个最接近你需求的 `.par` 文件
2. 把内容复制到 `<your_case>/flash.par` 的 `##### LASER PARAMETERS #####` 段（替换原有激光段）
3. 按文件顶部注释里的 setup 命令运行
4. `make -j4 && ./flash4 -parfile=flash.par`

## 文件清单

| 文件 | 配置名 | 适用场景 |
|---|---|---|
| `minimal-gaussian.par` | Recipe 1：最小可运行 | 第一次配置 FLASH 激光；验证 setup/make/run 流程 |
| `icf-supergaussian.par` | Recipe 2：ICF 直接驱动 super-Gaussian | 实际科研主力；平顶光斑 + LaserIO 可视化 |
| `multi-beam-6.par` | Recipe 4：6 束对称打靶 | ICF 直接驱动；多束球对称加热 |

## 不在这 3 个文件里的场景

| 想要的 | 怎么办 |
|---|---|
| 椭圆光斑 + 偏心 + 扭转（Recipe 3） | 从 `icf-supergaussian.par` 复制，按 `knowledge/recipes.md §5` 改 target/gaussian 参数 |
| 环形分布（gaussianInverse2D） | 从 `icf-supergaussian.par` 复制，改 `crossSectionFunctionType = "gaussianInverse2D"`，详见 `knowledge/recipes.md §7` |
| 自定义截面函数（如 flattopGaussian） | 改源码（见 `knowledge/recipes.md §5`），然后用 `icf-supergaussian.par` 作起点 |
| 不同波长的激光（如 351 nm 三倍频） | 直接改 `ed_wavelength_<i>`（注意是 μm，所以 351 nm 写 `0.351`） |
| 1D 或真 3D 几何 | 这 3 个文件是 2D RZ 专用；1D/3D 需要不同的 setup 选项和 gridType |

## 参数单位速查（每个文件顶部都有）

| 参数 | 单位 | 容易错 |
|---|---|---|
| `ed_wavelength_<i>` | **μm** | cm 或 nm |
| `ed_lens*/target*` | **cm** | mm 或 μm |
| `ed_gaussianRadius/Center` | **cm** | μm |
| `ed_time` | **s** | ns（直接写 `0.1` 是 100 ms！） |
| `ed_power` | **W** | erg/s（源码自动转，但用户易混） |
| `ed_*TorsionAngle` | **度** | 弧度 |

## 调试

跑不通时先看 `knowledge/pitfalls.md`，按 abort 信息查对应章节。

最常见的 3 个错误：
1. `Not enough beam runtime parameters` → setup 漏了 `ed_maxBeams=N`
2. `depo 全为 0` → 单位错了 / pulse 时段没覆盖 / lens 落域外
3. 吸收率偏低 → 2D RZ 没开 `ed_laser3Din2D=.true.`
