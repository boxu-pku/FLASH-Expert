# FLASH 两个问题的回复：①单位制与 log 中的 "none"；②NEI 电离 + Heatexchange 同开时 e-i 平衡时间偏快

> 基于本机 FLASH 4.8 源码与《FLASH 4.8 User's Guide》逐条核对（手册 PDF 页码按书页标注）。
> 所有源码路径均相对 `FLASH4.8/` 根目录，可直接点开核对。

---

## 结论速览

**问题一**：FLASH 没有编译期"单位制开关"，**不指定任何东西就是按 CGS 跑**。你在 log 里看到的 `unitsystem = none` 是 **Hydro 单元自己的一个字符串运行参数 `UnitSystem` 的默认值**（`source/physics/Hydro/HydroMain/Config:33`），它只在 MHD 求解器里影响磁场参考量的换算，纯流体计算完全不读它。`none` 的意思不是"没有单位制"，更不是无量纲——整套物理（物理常数、EOS、Heatexchange、等离子体碰撞公式）都按 CGS 写死。另外：setup 命令行的 `-unit=` / `-with-unit=` 是"选择代码单元（物理模块）"，与单位制无关，容易望文生义。

**问题二**：你的 38 ns 手算**没有错**，FLASH 源码也**忠实实现了**手册公式 (18.270)（我逐行核对过，并复算出 38.2 ns）。偏差主要来自**三个层面的"比较口径不一致"+ 若干配置嫌疑**，按重要性排序：

1. **公式定义差 3 倍（一定存在，这是最大的一项）**：(18.270) 的 τei 是电子温度方程 dTe/dt 的特征时间，而模拟中 **Te−Ti 温差**按 exp(−(1+m)·t/τei) 衰减（手册 (18.268)、源码 `Heatexchange.F90:206`），m = cvele/cvion = z̄ = 2（完全电离 He 理想气体）。所以**正确配置的 Spitzer 模拟里温差衰减时间应是 τei/(1+z̄) ≈ 12.7 ns，而不是 38 ns**。
2. **τei ∝ Te^1.5 的局部温度**：在 Te ≈ 6 eV 的区域（热斑边缘），温差衰减恰好 ≈ 2 ns；且电子从 20 eV 降到平衡温度 13.4 eV 的过程中 τei 也在收缩。
3. **配置项**：`hx_ieTimeCoef`（默认 1.0，若被设 0.1 → 1.3 ns）、Heatexchange 变体没选对（**默认变体是 Constant 不是 Spitzer**！）、表格 EOS 使 cvele 偏大（m ≫ 2）、输出间隔太粗。
4. **可以排除的方向**：库仑对数被 floor 到 1 不会发生（本例自算 lnΛ=7.3，floor 默认 1.0 不触发）；ConstCoulomb 默认 lnΛ=1 反而会把平衡变**慢**（~280 ns）而非变快。

**追问（Multigamma+NEI 时能否"表格 EOS 只供热力学、电离度归 NEI"）**：FLASH 4.8 **没有现成开关**——表插值 z̄ 与传入值取 max 的规则写死在 `eos_tabIonmix.F90:401`。但表格 z̄ **只影响 EOS 自己的电子热力学（cvele 等），不会覆盖 NEI 的物种分数**，Heatexchange 等取 z̄ 走 `Eos_getAbarZbar`（永远物种分数加权）仍由 NEI 控制。你们的 **Multigamma + NEI 正是官方预期组合**（NeiTest 同款）；真要表格+z̄NEI 需改两处源码且有电离能不自洽的物理代价。详见第三节。

详细分析见下文。

---

## 问题一：不指定 -unit，单位制是 CGS 吗？log 里的 "none" 是什么？

### 1.1 "none" 的确切出处

在 flash.log 的 RuntimeParameters 段里（比如本机一个算例的 `cases/Sedov/sedov.log:269`）：

```
unitsystem                  = none
```

它是 **Hydro 单元**声明的字符串参数（名字不区分大小写，log 里转成小写显示）：

```
# source/physics/Hydro/HydroMain/Config:32-33
D UnitSystem  System of Units
PARAMETER UnitSystem  STRING  "none"    # System of Units
```

它被读取后**只用于一件事**：MHD 求解器里磁场参考量 hy_bref 的单位约定（`source/physics/Hydro/HydroMain/unsplit/Hydro_init.F90:566-574`）：

```fortran
if ( hy_units == "SI"  ) then ; hy_bref = hy_vref*sqrt(4.0*PI*hy_dref*1.e-7)  ! Tesla 量纲
else if ( hy_units == "CGS" ) then ; hy_bref = hy_vref*sqrt(4.0*PI*hy_dref)   ! Gauss 量纲
else ;                          hy_bref = hy_vref*sqrt(hy_dref)               ! "none"：吸收掉 4π
```

**纯流体（无 MHD）计算从头到尾不使用这个值**。所以 `unitsystem = none` 只是"没声明磁场单位偏好"，不代表 FLASH 在"无单位"状态下运行。

### 1.2 FLASH 真正的单位制在哪里定义

- **物理常数单元**：`source/PhysicalConstants/PhysicalConstantsMain/Config`：

```
D pc_unitsBase  Base Unit system for Physical Constants -- can be "CGS" or "MKS"
PARAMETER pc_unitsBase  STRING  "CGS"
```

默认 **CGS**（厘米、克、秒、esu、开尔文）。你可以在自己算例的 flash.log 里直接验证：`grep -i "pc_unitsBase" flash.log`，会看到 `pc_unitsBase = CGS`。

- **物理模块按 CGS 写死**：EOS 源码注释直言不讳（`source/physics/Eos/EosMain/multiTemp/Gamma/eos_initPhysData.F90:59,67`）：

```fortran
!! DEV:  NOTE -- We should verify that unitsystem is "cgs" !!
...
eos_amu = eos_avoinv  !!DEV: only valid in "cgs", not "MKS" units!
```

Heatexchange/PlasmaState 的公式同样按 CGS 定死（τei 输出秒、nion 用 cm^-3、mion 用 g）。理论上 `pc_unitsBase` 可设 "MKS"，但几乎没有物理模块为此做过适配，**不建议碰**。

### 1.3 两个容易混淆的概念

| 你看到的 | 实际含义 |
|---|---|
| setup 命令行的 `-unit=` / `-with-unit=` | **选择代码单元（物理模块）**。手册 §18.5 原文示例：`-with-unit=physics/sourceTerms/Heatexchange/HeatexchangeMain/ConstCoulomb`。与单位制无关。 |
| flash.log 里 `FLASH Units used:` 段 | 列出本次模拟**包含的代码单元**（Driver、Grid、physics/...），同样不是物理单位制。 |
| flash.log 里 `unitsystem = none` | Hydro 的磁场单位偏好参数，默认 "none"，纯流体不影响任何结果。 |

### 1.4 实操建议

- **parfile 一律按 CGS 填**：长度 cm、密度 g/cm³、温度 K、能量 erg/g、速度 cm/s、时间 s。
- 个别模块有自己的单位约定，以参数注释为准。最典型的是激光：`ed_power_<p>_<s>` 用 **瓦特 W**（源码 `ed_setupPulses.F90` 内部乘 `ed_Joule2erg` 自动转 erg/s）。
- 如果跑 MHD 且磁场量想按 SI 处理才需要动 `UnitSystem`，并自行核查整个后处理链的一致性——一般直接全 CGS 最省心。

---

## 问题二：He 等离子体 e-i 平衡时间：公式 38 ns vs 模拟 ~2 ns

### 2.1 先把结论摆正：38 ns 手算正确，代码实现也正确

手册 §18.5.1（书页 323）公式 (18.270)：

```
              3 k_B^(3/2) (mion·Tele + mele·Tion)^(3/2)
  τei = -----------------------------------------------------
        8·√(2π)·e⁴·(mele·mion)^(1/2)·z̄²·nion·lnΛei
```

源码实现（两步，与手册**逐项一致**）：

```fortran
! source/physics/utilities/PlasmaState/PlasmaStateMain/PlasmaState_tau.F90:63-67
tau = 3*sqrt(me)*(kB*tele)^1.5 / (4*sqrt(2π)*ll*e^4*zbar^2*nion)      ! Braginskii 碰撞时间

! source/physics/utilities/PlasmaState/PlasmaStateMain/PlasmaState_ieEquilTime.F90:56-58
eqtime = tau/(sqrt(me)*tele^1.5) * (mion*tele + me*tion)^1.5 / (2*sqrt(mion*me))
       ! 代入 tau 化简后 == (18.270)，手册注明与 Atzeni (2004)、NRL Formulary 一致
```

库仑对数按手册 (18.271)-(18.273)（Brysk 1974）实现（`PlasmaState_logLambda.F90:68-121`）：

```
bmax = 电子德拜长度 = sqrt(kB·Tele/(4π e² nele))
bmin = max( z̄e²/(3kB·Tele) ,  ħ/(2·sqrt(3 kB·Tele·mele)) )
lnΛei = ln(bmax/bmin)，默认强制 ≥ logLambdaFloor = 1.0（useLogLambdaFloor 默认 TRUE）
```

**用你的参数复算**（nion = 1e17 cm^-3，z̄=2，nele = 2e17，A=4，Tele = 20 eV，Tion = 298 K）：

| 量 | 值 |
|---|---|
| 德拜长度 bmax | 7.43e-6 cm |
| bmin（经典 90°） | 4.80e-9 cm（> 量子 1.78e-9，取经典） |
| **lnΛei（代码自算）** | **7.345**（floor=1.0 不触发） |
| **τei (18.270)** | **38.2 ns** ← 和你的 38 ns 对上了 |

所以：**公式、代码、你的手算三者一致**。问题出在"模拟里观察到的弛豫时间"和"τei"不是同一个量，以及若干配置可能。

### 2.2 必然存在的因子 3：耦合系统比单边公式快 (1+m) 倍

手册 (18.266)-(18.268) 写得很清楚：Spitzer 变体解的 ODE 是**双向耦合**的：

```
dTion/dt = (m/τei)(Tele − Tion)        m = cv,ele/cv,ion
dTele/dt = (1/τei)(Tion − Tele)
```

解析解（(18.268)，源码 `Spitzer/Heatexchange.F90:198-207`）：

```
T(t) 的偏离项 ∝ exp( −(1+m)·t/τei )
```

对完全电离 He 的理想气体（multiTemp Gamma EOS，γ=5/3）：**m = cvele/cvion = z̄ = 2**。因此：

```
温差 (Tele − Tion) 的 e 折时间 = τei/(1+m) = 38.2/3 ≈ 12.7 ns
```

物理解释：离子热容只有电子的 1/2（每克 1 个 He²⁺ vs 2 个电子），电子把能量倒给离子的过程中，离子温度涨得快、电子温度降得慢，两边夹逼使**温差**收敛比"电子单方面弛豫"快 3 倍。这不是 bug，是两温系统的正确行为——**你用 38 ns 去对比模拟温差衰减时，应该先除以 (1+z̄)**。

最终平衡温度 A = (Tion + m·Tele)/(1+m) ≈ 13.3 eV（不是 10 eV，因为电子热容大）。

### 2.3 剩余 ~6 倍差距的候选原因（按可能性排序）

**(a) 观察区域的 Te 低于 20 eV。** τei ∝ Te^1.5 极其敏感：

| 观察点 Tele | τei | 温差衰减 τei/3 |
|---|---|---|
| 20 eV | 38.2 ns | 12.7 ns |
| 15 eV | 24.8 ns | 8.3 ns |
| 10 eV | 13.5 ns | 4.5 ns |
| **6 eV** | **6.3 ns** | **2.1 ns** ← |

你的算例是"中心 20 eV"的热斑，必然有空间分布。如果"~2 ns 平衡"是在边缘（Te 只有几个 eV）或事后切片取平均看到的，这个因子就齐了。另外中心电子在平衡过程中从 20 eV 降到 ~13 eV，τei 也在动态收缩。

**(b) parfile 里的缩放旋钮。** `hx_ieTimeCoef`（默认 1.0，`Spitzer/Config`）直接乘 τei：设 0.1 → 温差衰减 1.3 ns。检查 flash.log 里 `hx_ieTimeCoef` 的值。

**(c) Heatexchange 变体没选对。** 这是新人最常踩的坑：

- **默认变体是 Constant，不是 Spitzer**（`HeatexchangeMain/Config:19 DEFAULT Constant`；手册 §18.5 也明说 "Constant implementation is set as the default"）。Constant 的弛豫率由 `hx_couplingConst12`（默认 1.0）直接决定，与 Spitzer 物理无关，给出的"平衡时间"可以是任意值。
- **ConstCoulomb**：固定库仑对数 `hx_coulombLog`（**默认 1.0**）+ `hx_singleSpeciesA/Z`（**默认都是 1.0**）。对 He 必须设 `hx_singleSpeciesA=4, hx_singleSpeciesZ=2`，且 `hx_coulombLog` 建议设 ~7；否则速率差几十倍。注意：lnΛ=1 会把 τei 放大到 ~280 ns（**变慢**），所以你的"偏快"若真来自变体，方向上更可能是 Constant 或参数组合问题，而不是 ConstCoulomb 的 lnΛ 默认值。
- **Immediate**：一步强制 Te=Ti——你的现象不是它（那样是"瞬间"而非 2 ns）。
- **怎么查**：看运行目录 `setup_call` / `setup_flags`（或 Makefile 里的单元列表），确认包含的是 `HeatexchangeMain/Spitzer`；手册建议的写法是 setup 行加 `-with-unit=physics/sourceTerms/Heatexchange/HeatexchangeMain/Spitzer` 或在问题 Config 里 `REQUIRES` 同一路径。

**(d) EOS 的 cv 使 m ≫ 2。** Spitzer 变体每步用 EOS 求 cvele/cvion（`Spitzer/Heatexchange.F90:144-153`）。理想气体下 m=z̄=2；若用含电离自由度的表格 EOS（或 NEI 改变组分后查表），cvele 可以远大于理想值 → m=8 时温差衰减 4.2 ns，m=20 时 1.8 ns。同时"负比热/负能量回退"警告（flash.log 里 `[Heatexchange] Negative ...`）也是表格 EOS 的常见伴生现象。排查：理想 3T Gamma EOS 复跑对照。

**(e) 输出间隔 / 时间步太粗。** 若 dt 或 io 输出间隔在 ns 量级，"第 1~2 个输出时已经平了"会把 5~12 ns 的真实弛豫看成 ~2 ns。检查 flash.log 里实际 dt 和 `io_tstep`/`io_tmax`。

### 2.4 关于"18.2 非平衡电离 + 18.5 Heatexchange 同开"本身

两个模块可以同开（operator-split 顺序：Heatexchange 第 7 位、Ionize 第 9 位，`source/Driver/DriverMain/Driver_sourceTerms.F90:64,66`），但有几个**必须知道的事实**：

1. **Ionize 不碰能量方程**。手册 §18.2 原文（书页 271）：
   > "Note that in the present version, the contribution of the ionization and recombination to the energy equation (the bracketed term in (18.23)) is **not accounted for**."
   
   即电离不扣电子能量、复合不加结合能——它只解各电离态的速率方程（Bader-Deuflhard + MA28，Summers 1974 日冕近似率表 `summers_den_1e8.rates`）。所以**不存在"Ionize 偷偷做了 e-i 能量交换"**。
2. **你的初始态不是电离平衡态，但在前 ~40 ns 内无所谓**。20 eV 下 He 的 Saha 平衡应以 He⁺ 为主（完全电离需要 ~54 eV 量级的碰撞电离）；不过 NEI 用的是日冕近似速率（碰撞电离 + 辐射/双电子复合，无三体复合），辐射复合时标 ~1/(αRR·ne) ≈ 1/(1e-12 × 2e17) ≈ **5 μs ≫ 38 ns**。所以电离态在平衡窗口内基本冻结在 He²⁺（z̄=2），Ionize 在这个时间尺度上是旁观者——两模块同开不是你偏快的直接原因。
3. Ionize 影响 Heatexchange 的**间接通道**是改变质量分数 → abar/z̄/cv → τei(∝1/z̄²) 和 m=z̄。若长时间演化后 z̄ 下降，τei 会**变长**、m 变小（更慢），方向仍与"偏快"相反。
4. 使用注意：NEI 需要 `Simulation/SimulationComposition/Ionize` 组分定义、问题 Config 里选元素子集、以及可执行文件同目录下有 `summers_den_1e8.rates`（Config 的 DATAFILES 会自动拷贝）。

### 2.5 排查清单（建议按序执行）

1. `grep -i "hx_ieTimeCoef\|hx_dtFactor\|hx_coulombLog\|hx_couplingConst" flash.log` —— 确认缩放系数都是默认/预期值。
2. 看 `setup_call`（"Expanded Command line"）或 `setup_flags`：Heatexchange 变体是否 `HeatexchangeMain/Spitzer`；不是就加 `-with-unit=physics/sourceTerms/Heatexchange/HeatexchangeMain/Spitzer` 重 setup。
3. 用 TELE/TION 的时间序列（同一 cell、取中心 20 eV 处）拟合 exp，得到**温差**的 e 折时间 τ_gap；与 τei/(1+z̄) 对比（你的参数：38.2/3 = 12.7 ns）。若 τ_gap ≈ 12.7 → 一切正常，之前的 38 ns 只是口径问题。
4. 若仍偏快：换理想 3T Gamma EOS（`+mtmmmt` 默认路径）复跑，排除表格 EOS 的 cvele 效应（m≫2）。
5. 确认观察位置的温度：在 Te=6 eV 的边缘，2 ns 反而是**正确**答案。
6. 检查输出时间序列够不够密（dt 与 io 间隔 vs 预期 ns 级弛豫）。
7. 想要独立验证：把该 cell 的 (ρ, Te, Ti, z̄) 代进 2.1 的公式自算 τei，或写个 0D 单区小算例（关 Ionize/hydro，只留 Heatexchange）标定。

### 2.6 一个便于手算的标度式

```
τei ≈ 38 ns × (Tele/20eV)^1.5 × (7.35/lnΛ) × (z̄=2 时的 z̄²nion 不变)
温差 e 折时间 ≈ τei / (1 + m)，理想气体 m = z̄（完全电离 He 为 2）
```

---

## 附：本文引用的源码/手册锚点

| 内容 | 位置 |
|---|---|
| UnitSystem 参数声明 | `source/physics/Hydro/HydroMain/Config:32-33` |
| hy_bref 三种单位分支 | `source/physics/Hydro/HydroMain/unsplit/Hydro_init.F90:566-574` |
| pc_unitsBase（默认 CGS） | `source/PhysicalConstants/PhysicalConstantsMain/Config` |
| EOS "only valid in cgs" 注释 | `source/physics/Eos/EosMain/multiTemp/Gamma/eos_initPhysData.F90:59,67` |
| 手册 §18.2 Ionization Unit | UG 书页 270-271（PDF 页 288-289） |
| 手册 §18.5 Heatexchange / (18.263)-(18.275) | UG 书页 320-323（PDF 页 338-341） |
| Heatexchange 默认变体 Constant | `source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Config:19` |
| Spitzer 主循环（cv→lnΛ→τei→解析解） | `source/physics/sourceTerms/Heatexchange/HeatexchangeMain/Spitzer/Heatexchange.F90:124-212` |
| ConstCoulomb 公式与默认参数 | `.../ConstCoulomb/Heatexchange.F90:141-165`、`.../ConstCoulomb/Config` |
| 库仑对数（Spitzer 模式） | `source/physics/utilities/PlasmaState/PlasmaStateMain/PlasmaState_logLambda.F90:68-121` |
| lnΛ floor 默认值 | `source/physics/utilities/PlasmaState/PlasmaStateMain/Config:9-12`（TRUE / 1.0） |
| τei 公式（=18.270） | `source/physics/utilities/PlasmaState/PlasmaStateMain/PlasmaState_ieEquilTime.F90:53-58` |
| sourceTerms 调用顺序 | `source/Driver/DriverMain/Driver_sourceTerms.F90:64,66` |
| Ionize 默认 Nei + 速率表 | `source/physics/sourceTerms/Ionize/IonizeMain/Config:17,23` |

> 复算脚本：见本文 2.1/2.3 的数值表，可用任意 python 复现（CGS 常数：kB=1.380649e-16, me=9.1094e-28, e=4.8032e-10 esu, ħ=1.0546e-27, NA=6.0221e23；20 eV = 232090 K）。

---

## 三、追问：实际用的是 Multigamma + NEI，能否"表格 EOS 只供热力学、电离度归 NEI"？

> 结论先行：**FLASH 4.8 没有现成的运行参数能让 Tabulated EOS 跳过表中的 z̄ 列**（合并规则写死在源码里）；但表格 EOS 的 z̄ **并不会覆盖 NEI 的电离度**——它只影响 EOS 自己算出来的电子热力学（cvele/eele 等）。你们的参数区间（20 eV、1e17 cm^-3 He）下，**Multigamma + NEI 就是正确且官方预期的组合**（官方 NeiTest 算例正是这么配的）；真要"表格热力学 + NEI z̄"需要小改两处源码，且有物理自洽性代价。

### 3.1 先把"表格 EOS 赋值电离度"的实际影响面说清楚（三条通道）

FLASH 里 z̄ 有三个消费通道，行为完全不同：

| 通道 | z̄ 来源 | 受表格 EOS 影响吗 |
|---|---|---|
| ① EOS 内部热力学（eele、cvele、pele、det…） | eos_tab 物种：表插值 z̄(T,N_ion)，与传入值取 max | **是**——"赋值电离度"的确切位置就是这里 |
| ② 物理单元取 z̄（Heatexchange 的 τei/lnΛ、激光临界密度等） | `Eos_getAbarZbar` → **永远从物种质量分数加权** | **否**——NEI 物种分数说了算 |
| ③ 物种质量分数本身（电离态的"真身"） | NEI 速率方程演化（xin→xout） | **否**——表格不回写物种分数 |

源码依据：

- 通道 ①：`source/physics/Eos/EosMain/multiTemp/Multitype/eos_multiTypeByTemp.F90:342`——EOS_TAB 物种传入的 z̄ 只是 `max(MS_ZMIN, 0.0)`（物种声明里的 z̄ 下限，不是 NEI 混合 z̄）；随后 `source/physics/Eos/EosMain/Tabulated/eos_tabIonmix.F90:401`（IONMIX4 表在 `:416`）：

```fortran
eosData(zbar+i) = max(eosData(zbar+i), &
                      tabData(EOS_TABINT_DERIV_0,EOS_TABVT_ZF,EOS_TAB_FOR_ELE))
```

  即**表插值的平衡电离 z̄_eq(T,ρ) 只会向上顶**，混合后按各材料数目分数加权（`eos_accumData`，`eos_multiTypeByTemp.F90:469`）。
- 通道 ②：`source/physics/Eos/EosMain/Eos_getAbarZbar.F90:130-151`——只要编译带 Multispecies（NEI 必带），z̄ = ā·Σ(X_i·Z_i/A_i)，**从当前质量分数实时计算，从不查表**。（例外：若用 Gamma/Ye EOS 且定义了 SUMY/YE 质量标量，则走标量；NEI 组分路径不涉及。）
- 通道 ③：`source/physics/sourceTerms/Ionize/IonizeMain/Ionize.F90:116-126`——NEI 解完刚性 ODE 后直接写回物种分数；Multitype/Tabulated 全目录 grep 无任何 ZBAR_VAR/物种分数回写。

**所以你们观察到的"读表格会赋值电离度"，确切含义是**：表格按它自己的平衡电离算电子热力学；NEI 的电离度本身、以及 Heatexchange 用的 z̄（进而 τei、lnΛ、m=cvele/cvion 里的 z̄ 部分）**从未被表格接管**。

### 3.2 有没有"只读其他状态量、z̄ 归 NEI"的方法？

**(a) 现成开关：没有。** `Tabulated/Config` 只有两个参数（`eos_useLogTables`、`eos_tabUseGeoSpace`）；手册 §17.4.3（书页 255）明说表格式（IONMIX1/IONMIX4/SESAME）本身就把 z̄(T,N_ion) 与 Ei/Ee/Pi/Pe 一起作为标准列读入，且 Tabulated 只配合 Multitype 使用（§17.4.4）。

**(b) 现成的"表格热力学 + z̄ 由物种控制"的 EOS 是 Helmholtz**（`multiTemp/Helmholtz`，即 mtmmmt 家族的 e± 费米-狄拉克表）：表只按 (T, ρ·Ye) 查，z̄/ā 从物种分数来（手册 §17.3："对任意成分有效，按 Ye 缩放"）。**但**它是完全电离假设、不含束缚态/电离能物理；20 eV、1e17 的 He 电子简并度可忽略（费米温度比 kT 小几个量级），Helmholtz ≈ 理想气体——对你们的算例相比 Multigamma 没有任何增益。

**(c) 真要 Tabulated + NEI z̄：改两处源码**（建议复制变体目录后再改，不动主干）：

1. `eos_multiTypeByTemp.F90:342`：EOS_TAB 分支把传入 z̄ 从 `max(curZMin,0)` 改为**该元素各电荷态物种按数目分数 Y_i 加权的 z̄**（NEI 物种自带 Z=0/1/2，正好可用 `Ymat` 加权）；
2. `eos_tabIonmix.F90:401`（及 ionmix4 的 `:416`）：把 `max(传入, 表值)` 改为保留传入值。

但要清楚**物理代价**：表里的 Ee(T,ρ)、cvele(T,ρ) 是按平衡电离生成的（含平衡电离能的分布）；用 NEI 的 z̄ 去读同一张表，热力学与真实 NEI 状态不自洽——恰好 20 eV 的 He 电离度离平衡很远（Saha 平衡应以 He⁺ 为主），不自洽会很严重。想做得干净还得按 NEI 电离度重构电离能项（并补上 Ionize 未实现的能量方程贡献），工作量相当于自研一个"NEI-aware EOS"。

**(d) 概念层面的错位要指出**：Multitype/Tabulated 的世界观是"**每种材料一张元素级表，电离度藏在表里**"；NEI 的世界观是"**每个电荷态一个物种、理想气体、电离度就是组分**"。两者天然不对位——这不是参数没调对，而是表示方法冲突。官方立场可从 NeiTest 的 Config 直接看出（`source/Simulation/SimulationMain/NeiTest/Config`）：

```
REQUIRES physics/Eos/EosMain/Multigamma
REQUIRES physics/sourceTerms/Ionize
REQUIRES Simulation/SimulationComposition/Ionize
```

**(e) 如果对表格的真实需求是输运系数而非热力学**：走 LaserSlab 系列的用法——EOS 保持 Multigamma/简单形式，**不透明度用 IONMIX 表**（`physics/materialProperties/Opacity/OpacityMain/method/Tabulated`，查表只要 (T,ρ)，不碰 z̄），`.imx/.cn4` 文件即此用途。这条路与 NEI 零冲突。

### 3.3 这个信息如何反馈到问题二的排查

- 既然确认是 Multigamma + NEI：2.3(d) "表格 EOS 使 cvele 偏大（m≫2）" 的嫌疑**可以划掉**——Multigamma 的 cvele/cvion = z̄（理想气体、无电离自由度），m = z̄ 由 NEI 演化。而且 NEI 若让 z̄ 从 2 降到 1，τei ∝ 1/z̄² 会变长、m 变小——方向上只会更慢，解释不了偏快。
- 偏快的剩余嫌疑集中在：**观察位置的局部温度**（τei ∝ Te^1.5，热斑边缘 6 eV 处温差衰减正好 ~2 ns）、**hx_ieTimeCoef** 是否被设小、**输出间隔/比较口径**（应与 τei/(1+z̄) 比，而不是 τei）。
- 顺带：Ionize 不做能量修正（手册 §18.2 原文），所以 NEI 电离度变化不会通过电离能干扰 EELE/EION——两模块在同开时是解耦的，问题二的结论不受影响。

### 3.4 本节引用锚点

| 内容 | 位置 |
|---|---|
| 表 z̄ 合并规则 max(传入, 表值) | `source/physics/Eos/EosMain/Tabulated/eos_tabIonmix.F90:401`、`eos_tabIonmix4.F90:416` |
| EOS_TAB 物种传入 z̄ = max(ZMIN,0) | `source/physics/Eos/EosMain/multiTemp/Multitype/eos_multiTypeByTemp.F90:337-358`（:342） |
| 混合 z̄ 按数目分数加权 | `eos_multiTypeByTemp.F90:469`（eos_accumData） |
| z̄ 从物种分数实时计算（物理单元通道） | `source/physics/Eos/EosMain/Eos_getAbarZbar.F90:130-151` |
| NEI 写回物种分数 | `source/physics/sourceTerms/Ionize/IonizeMain/Ionize.F90:116-126` |
| Tabulated EOS 读 z̄(T,Nion) 列 / 仅配合 Multitype | 手册 §17.4.3（书页 255，PDF 页 273） |
| Multitype 组合方式（分压相加、部分密度传入） | 手册 §17.4.4（书页 258，PDF 页 276） |
| Helmholtz 表按 Ye 缩放、成分无关 | 手册 §17.3（书页 252，PDF 页 270） |
| 官方 NEI 算例 = Multigamma + Ionize | `source/Simulation/SimulationMain/NeiTest/Config` |
