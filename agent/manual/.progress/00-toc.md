# FLASH 4.8 用户手册 — 完整 TOC

> 来源：`pdftotext -layout -f 1 -l 30` PDF 前 30 页
> 整理日期：2026-07-19
>
> **注意**：以下页码为手册印刷页码。"PDF 实际页码"（用于 `pdftotext -f`）在关键章节已验证并标注。因封面/版权/目录等前置页占 ~30 页，实际 PDF 页码 ≈ 印刷页码 + 30（约）。

---

## 前置页（Front Matter）

| 节 | 标题 | 印刷页 |
|---|---|---|
| 0.1 | Acknowledgments in Publication | i |
| 0.2 | Full License Agreement | i-iv |
| — | Acknowledgments | v |
| — | Contents | v-xvi |

## Part I: Getting Started

| 章 | 标题 | 印刷页 |
|---|---|---|
| **§1** | **Introduction** | **1** |
| 1.1 | What's New in FLASH4 | 2 |
| 1.2 | External Contributions | 11 |
| 1.3 | Known Issues in This Release | 11 |
| 1.4 | About the User's Guide | 13 |
| **§2** | **Quick Start** | **17** |
| 2.1 | System requirements | 17 |
| 2.2 | Unpacking and configuring FLASH for quick start | 18 |
| 2.3 | Alternative Configuration With a Docker Image | 20 |
| 2.4 | Running FLASH | 21 |
| **§3** | **Setting Up New Problems** | **27** |
| 3.1 | Creating a Config file | 28 |
| 3.2 | Creating a Makefile | 28 |
| 3.3 | Creating a Simulation_data.F90 | 29 |
| 3.4 | Creating a Simulation_init.F90 | 29 |
| 3.5 | Creating a Simulation_initBlock.F90 | 31 |
| 3.6 | Creating a Simulation_freeUserArrays.F90 | 35 |
| 3.7 | The runtime parameter file (flash.par) | 36 |
| 3.8 | Running your simulation | 39 |

## Part II: The FLASH Software System

| 章 | 标题 | 印刷页 |
|---|---|---|
| **§4** | **Overview of FLASH Architecture** | **43** |
| 4.1 | FLASH Inheritance | 44 |
| 4.2 | Unit Architecture | 44 |
| 4.3 | Unit Test Framework | 48 |
| **§5** | **The FLASH Configuration Script (setup)** | **49** |
| 5.1 | Setup Arguments | 50 |
| 5.2 | Comprehensive List of Setup Arguments | 51 |
| 5.3 | Using Shortcuts | 65 |
| 5.4 | Setup Variables and Preprocessing Config Files | 66 |
| 5.5 | Config Files | 68 |
| 5.6 | Creating a Site-specific Makefile | 78 |
| 5.7 | Files Created During the setup Process | 79 |
| 5.8 | Setup a hybrid MPI+OpenMP FLASH application | 81 |
| 5.9 | Setup a FLASH+Chombo application | 83 |
| 5.10 | Setup a FLASH application with cmake | 86 |
| **§6** | **The Flash.h File** | **89** |
| 6.1 | UNK, FACE(XYZ) Dimensions | 89 |
| 6.2 | Property Variables, Species and Mass Scalars | 90 |
| 6.3 | Fluxes | 91 |
| 6.4 | Scratch Vars | 91 |
| 6.5 | Fluid Variables Example | 92 |
| 6.6 | Particles | 93 |
| 6.7 | Non-Replicated Variable Arrays | 94 |
| 6.8 | Other Preprocessor Symbols | 96 |

## Part III: Driver Unit

| 章 | 标题 | 印刷页 |
|---|---|---|
| **§7** | **Driver Unit** | **99** |
| 7.1 | Driver Routines | 99 |
| 7.1.1 | Driver_initFlash | 100 |
| 7.1.2 | Driver_evolveFlash | 100 |
| 7.1.3 | Driver_finalizeFlash | 102 |
| 7.1.4 | Driver accessor functions | 102 |
| 7.1.5 | Time Step Limiting | 103 |

## Part IV: Infrastructure Units

| 章 | 标题 | 印刷页 |
|---|---|---|
| **§8** | **Grid Unit** | **107** |
| 8.1 | Overview | 109 |
| 8.2 | GridMain Data Structures | 111 |
| 8.3 | Computational Domain | 112 |
| 8.4 | Boundary Conditions | 113 |
| 8.5 | Uniform Grid | 117 |
| 8.6 | Adaptive Mesh Refinement (AMR) with Paramesh | 118 |
| 8.7 | Chombo | 125 |
| 8.8 | GridMain Usage | 127 |
| 8.9 | GridParticles | 128 |
| 8.10 | GridSolvers | 135 |
| 8.11 | Grid Geometry | 162 |
| 8.12 | Unit Test | 168 |
| **§9** | **IO Unit** | **171** |
| 9.1 | IO Implementations | 173 |
| 9.2 | Output Files | 175 |
| 9.3 | Restarts and Runtime Parameters | 181 |
| 9.4 | Output Scalars | 181 |
| 9.5 | Output User-defined Arrays | 181 |
| 9.6 | Output Scratch Variables | 182 |
| 9.7 | Face-Centered Data | 182 |
| 9.8 | Output Filenames | 182 |
| 9.9 | Output Formats | 183 |
| 9.10 | Working with Output Files | 190 |
| 9.11 | Unit Test | 190 |
| 9.12 | Chombo | 191 |
| 9.13 | Derived data type I/O | 191 |
| **§10** | **Runtime Parameters Unit** | **193** |
| 10.1 | Defining Runtime Parameters | 193 |
| 10.2 | Identifying Valid Runtime Parameters | 193 |
| 10.3 | Routine Descriptions | 194 |
| 10.4 | Example Usage | 195 |
| **§11** | **Multispecies Unit** | **197** |
| 11.1 | Defining Species | 197 |
| 11.2 | Initializing Species in Simulation_initSpecies | 198 |
| 11.3 | Specifying Constituent Elements of a Species | 200 |
| 11.4 | Alternative Method for Defining Species | 200 |
| 11.5 | Routine Descriptions | 201 |
| 11.6 | Example Usage | 203 |
| 11.7 | Unit Test | 203 |
| **§12** | **Physical Constants Unit** | **205** |
| 12.1 | Available Constants and Units | 206 |
| 12.2 | Applicable Runtime Parameters | 206 |
| 12.3 | Routine Descriptions | 206 |
| 12.4 | Unit Test | 207 |
| **§13** | **Cpp & Python Units** | **209** |
| 13.1 | Cpp | 209 |
| 13.2 | Python | 210 |

## Part V: Physics Units

| 章 | 标题 | 印刷页 |
|---|---|---|
| **§14** | **3T Capabilities for HEDP** | **213** |
| **§15** | **Hydrodynamics Units** | **217** |
| 15.1 | Gas hydrodynamics | 219 |
| 15.2 | Relativistic hydrodynamics (RHD) | 228 |
| 15.3 | Magnetohydrodynamics (MHD) | 230 |
| 15.4 | Radiation-Flux-Limiter Aware Hydrodynamics | 245 |
| **§16** | **Incompressible Navier-Stokes Unit** | **247** |
| **§17** | **Equation of State Unit** | **249** |
| 17.1 | Introduction | 249 |
| 17.2 | Gamma Law and Multigamma | 250 |
| 17.3 | Helmholtz | 251 |
| 17.4 | Multitemperature extension for Eos | 253 |
| 17.5 | MultiFluid | 259 |
| 17.6 | Usage | 259 |
| 17.7 | Unit Test | 261 |
| **§18** | **Local Source Terms** | **263** |
| 18.1 | Burn Unit | 264 |
| 18.2 | Ionization Unit | 270 |
| 18.3 | Stir Unit | 272 |
| 18.4 | Energy Deposition Unit | 276 |
| 18.5 | Heatexchange | 320 |
| 18.6 | Flame | 324 |
| 18.7 | Turbulence Measurement | 326 |
| 18.8 | Circuit | 326 |
| **§19** | **Diffusive Terms** | **329** |
| 19.1 | Diffuse Unit | 329 |
| **§20** | **Gravity Unit** | **341** |
| 20.1 | Introduction | 341 |
| 20.2 | Externally Applied Fields | 342 |
| 20.3 | Self-gravity | 342 |
| 20.4 | Usage | 345 |
| 20.5 | Unit Tests | 347 |
| **§21** | **Particles Unit** | **349** |
| 21.1 | Time Integration | 351 |
| 21.2 | Mesh/Particle Mapping | 359 |
| 21.3 | Using the Particles Unit | 362 |
| 21.4 | Sink Particles | 366 |
| **§22** | **Cosmology Unit** | **371** |
| 22.1 | Algorithms and Equations | 371 |
| 22.2 | Using the Cosmology unit | 373 |
| 22.3 | Unit Test | 374 |
| **§23** | **Material Properties Units** | **375** |
| 23.1 | Thermal Conductivity | 376 |
| 23.2 | Magnetic Resistivity | 377 |
| 23.3 | Viscosity | 379 |
| 23.4 | Thermoelectric Coefficients | 379 |
| 23.5 | Opacity | 380 |
| 23.6 | Mass Diffusivity | 386 |
| **§24** | **Physics Utilities** | **387** |
| 24.1 | PlasmaState | 387 |
| **§25** | **Radiative Transfer Unit** | **389** |
| 25.1 | Multigroup Diffusion | 390 |

## Part VI: Monitor Units

| 章 | 标题 | 印刷页 |
|---|---|---|
| **§26** | **Logfile Unit** | **399** |
| 26.1 | Meta Data | 400 |
| 26.2 | Runtime Parameters, Physical Constants, Multispecies Data | 400 |
| 26.3 | Accessor Functions and Timestep Data | 402 |
| 26.4 | Performance Data | 403 |
| 26.5 | Example Usage | 404 |
| **§27** | **Timer and Profiler Units** | **405** |
| 27.1 | Timers | 405 |
| 27.2 | Profiler | 407 |

## Part VII: Diagnostic Units

| 章 | 标题 | 印刷页 |
|---|---|---|
| **§28** | **Proton Imaging Unit** | **411** |
| §28.0.1-7 | Proton Deflection / Setup / Screens / Usage / Test | 412-421 |
| **§29** | **Proton Emission Unit** | **429** |
| §29.0.1-4 | Proton Generation / Screens / Boxes / Usage | 429-432 |
| **§30** | **Thomson Scattering Unit** | **435** |
| 30.1 | Thomson Scattering with Ray Tracing | 435 |
| 30.2 | Simple Thomson Scattering without Ray Tracing | 443 |
| **§31** | **X-ray Imaging Unit** | **449** |
| §31.0.1-5 | X-ray Paths / Tracing / Screens / Usage / Test | 449-453 |

## Part VIII: Numerical Tools Units

| 章 | 标题 | 印刷页 |
|---|---|---|
| **§32** | **Interpolate Unit** | **457** |
| 32.1 | Introduction | 457 |
| 32.2 | Piecewise Cubic Interpolation | 457 |
| 32.3 | Usage | 459 |
| **§33** | **Roots Unit** | **461** |
| 33.1 | Introduction | 461 |
| 33.2 | Roots of Quadratic Polynomials | 461 |
| 33.3 | Roots of Cubic Polynomials | 462 |
| 33.4 | Roots of Quartic Polynomials | 462 |
| 33.5 | Usage | 462 |
| 33.6 | Unit Tests | 462 |
| **§34** | **RungeKutta Unit** | **467** |
| 34.1 | Introduction | 467 |
| 34.2 | Runge Kutta Integration | 467 |
| 34.3 | Usage | 470 |
| 34.4 | Unit Tests | 471 |

## Part IX: Simulation Units

| 章 | 标题 | 印刷页 |
|---|---|---|
| **§35** | **The Supplied Test Problems** | **479** |
| 35.1 | Hydrodynamics Test Problems | 479 |
| 35.2 | Magnetohydrodynamics Test Problems | 514 |
| 35.3 | Gravity Test Problems | 532 |
| 35.4 | Particles Test Problems | 544 |
| 35.5 | Burn Test Problem | 548 |
| 35.6 | RadTrans Test Problems | 552 |
| 35.7 | Other Test Problems | 554 |
| 35.8 | 3T Shock Simulations | 573 |
| 35.9 | Matter+Radiation Simulations | 579 |

## Part X: Tools

| 章 | 标题 | 印刷页 |
|---|---|---|
| **§36** | **VisIt** | **585** |
| **§37** | **sfocu** (Serial FLASH Output Comparison) | **587** |
| 37.1 | Building sfocu | 587 |
| 37.2 | Using sfocu | 587 |
| **§38** | **Drift** | **589** |
| 38.1 | Introduction | 589 |
| 38.2 | Enabling drift | 590 |
| 38.3 | Typical workflow | 590 |
| 38.4 | Caveats and Annoyances | 591 |
| **§39** | **FLASH IDL Routines (fidlr3.0)** | **593** |
| 39.1 | Installing and Running fidlr3.0 | 593 |
| 39.2 | xflash3: Widget Interface | 594 |
| 39.3 | Comparing two datasets | 600 |
| **§40** | **convertspec3d** | **603** |
| 40.1 | Installation | 603 |
| 40.2 | Usage | 604 |

## Part XI: Going Further with FLASH

| 章 | 标题 | 印刷页 |
|---|---|---|
| **§41** | **Adding New Solvers** | **609** |
| **§42** | **Porting FLASH to Other Machines** | **611** |
| 42.1 | Writing a Makefile.h | 611 |
| **§43** | **Multithreaded FLASH** | **615** |
| 43.1 | Overview | 615 |
| 43.2 | Threading strategies | 615 |
| 43.3 | Running multithreaded FLASH | 616 |
| 43.4 | Verifying correctness | 617 |
| 43.5 | Performance results | 617 |
| 43.6 | Conclusion | 621 |

## Back Matter

| 条目 | 印刷页 |
|---|---|
| References | 625 |
| Runtime Parameters (full list) | 633 |
| API Index | 639 |
| Index | 641 |

---

## 优先级映射

| 优先级 | 对应章节（按 handoff §5.2） |
|---|---|
| ★★★ | §18.4 Energy Deposition（p.276-296, PDF已验证）、§2 Setup（p.17-25）、§3 New Problems（p.27-39）、§5 setup script（p.49-87） |
| ★★ | §18.1 Burn（p.264-270）、§18.2 Ionization（p.270-271）、§18.3 Stir（p.272-276）、§23 Material Properties（p.375-386）、§18.5 Heatexchange（p.320-324） |
| ★ | §4, §6-17, §19-22, §24-34, §18.6-8, §35-43, Appendices |

## 已知备注

1. **印刷页码 vs PDF 页码**：前置页占 ~30 PDF 页（封面/版权 iv 页 + 目录 xvi 页 + 致谢等）。中文 §18.4 Energy Deposition 已验证偏移：印刷 p.276 = PDF `-f 276`，说明 PDF 页码 ≈ 印刷页码（TOC 页不计入）。实测转章时需通过 `pdftotext` 全文搜章节标题确认。
2. **§18.4 子节详细页**：18.4.1 (276)、18.4.2 (277)、18.4.3 (279)、18.4.4 (279)、18.4.5 (283)、18.4.6 (283)、18.4.7 (286)、18.4.8 (291)、18.4.9 (297)、18.4.10 (302)、18.4.11 (306)、18.4.12 (311)、18.4.13 (318)
3. **§1 Introduction 不含子节**：1.1 What's New 部分非常长（p.2-10），包含多版本变更记录，可考虑独立拆为子页。
4. **§35 Test Problems 详度**：该章 ~100 页，但有可能是"每个问题 1-3 页"的 recipe 格式，转时宜按问题拆分为独立文件。
