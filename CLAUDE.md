# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## FLASH Expert Agent 系统

本项目附带一个 **Multi-Skill FLASH 专家 Agent 系统**，由 18 个专门 skill 组成：

- **知识层 (11)**：`flash-laser`, `flash-driver`, `flash-grid`, `flash-hydro`, `flash-eos`, `flash-radtrans`, `flash-material`, `flash-sourceterms`, `flash-io`, `flash-multispecies`, `flash-diffuse`
- **工具层 (5)**：`flash-source-reader`, `flash-pitfall-finder`, `flash-param-query`, `flash-setup-builder`, `flash-manual-search`
- **操作层 (2)**：`flash-case-runner`, `flash-result-analyzer`

### 调用规则（重要）

1. 用户提问涉及 FLASH 物理单元时，**优先**匹配最相关的 skill 而不是从主上下文回答
2. 跨领域问题可以串联调用多个 skill（如：`flash-laser` 给思路 → `flash-pitfall-finder` 找匹配错误 → `flash-source-reader` 验证源码）
3. **不知道答案时老实说**"本 skill 知识库未覆盖"，并提议生成草稿到 `agent/drafts/pending/`
4. **禁止**编造参数、函数名、源码细节

### 项目状态导航

- 当前进度、任务清单、决策记录：见 `agent/PROJECT_PLAN.md`
- 架构规范、skill 调度协议：见 `agent/ARCHITECTURE.md`
- 治理流程、决策修改、审核清单：见 `agent/GOVERNANCE.md`
- Skill / knowledge 模板：见 `agent/TEMPLATES/`

**当用户问"做到哪一步了"或"下一步是什么"时，先读 `agent/PROJECT_PLAN.md` §1 Dashboard 和 §10 下一步行动。**

### Skill 触发提示

每个 skill 在 `.claude/skills/<name>/SKILL.md` 顶部的 `description` 和 `triggers` 字段定义了它何时被调用。当用户的提问包含这些关键词时，应优先考虑调用对应 skill。

---

## What this is

FLASH 4.8 — a modular, block-AMR, multiphysics finite-volume code for compressible/fluid/MHD/plasma/laser-driven flows. The repo holds the **source distribution** plus a few **pre-built problem object directories** under `cases/`. It is not a git repo (`.gitignore` exists only to keep build artifacts out).

## Build model: setup → make → run

FLASH does **not** have a top-level Makefile. The workflow is *configure-per-problem*:

```
./setup <SimulationMain/problem> [opts] -auto -objdir=<path>
cd <path> && make -j<N>          # produces ./flash4
./flash4 -parfile=<name>.par     # runs the simulation
```

`./setup` is a thin wrapper that execs `bin/setup.py`. Real examples for this tree:

- `./setup Sedov -auto -objdir=cases/Sedov`
- `./setup LaserSlab -2d -auto +cylindrical -nxb=16 -nyb=16 +hdf5typeio species=cham,targ +mtmmmt +laser +uhd3t +mgd mgd_meshgroups=6 -objdir=cases/LaserSlab -parfile=example.par`
- `./setup Sunliang_laser_CH -2d -auto +pm4dev -geometry=cylindrical -nxb=16 -nyb=16 +mtmmmt +laser +mgd +uhd3t species=cham,targ1,targ2,targ3 mgd_meshgroups=6 -parfile=example_xubo.par -objdir=cases/Sunliang_laser_CH`

Each built objdir records the original command in `setup_call` and the resolved flags in `setup_flags`, `setup_defines`, `Makefile.h`. To rebuild an existing case you usually just `cd cases/<name> && make -j4`.

### setup-line grammar (the part that bites people)

- Positional first arg = `SimulationMain/<name>` (case-insensitive prefix match).
- `-2d` / `-3d` / `-1d`: dimensionality → drives `NXB/NYB/NZB` and `N_DIM`.
- `-nxb=N -nyb=N -nzb=N`: block size (compile-time, in `setup_defines`).
- `+foo` / `-foo`: turn setup-variable `foo` on/off. `+pm4dev` picks the Paramesh 4-dev Grid backend; `+mtmmmt` selects multi-temp EOS; `+laser`, `+mgd`, `+uhd3t` are shorthand `+unit` aliases.
- `key=value`: set a setup-variable (e.g. `species=cham,targ1,targ2,targ3`, `mgd_meshgroups=6`).
- `-geometry=cylindrical|cartesian|spherical|-zr|-zt|…`.
- `-auto` skips interactive prompts and uses default unit selections.
- `-objdir=PATH` is where `make` runs and `flash4` lands. **Default objdir is `object/`** at the repo root — passing `-objdir=cases/<name>` is a local convention used here.
- `-parfile=foo.par` copies `foo.par` into the objdir as `flash.par`.
- `-debug` swaps `FFLAGS_OPT` → `FFLAGS_DEBUG` (bounds check, `-ffpe-trap`, `-O0`).
- `+hdf5typeio` selects the HDF5 IO backend (vs. default non-HDF5).

The full expansion (which `--unit=...` selections were made) is logged in `setup_call` under "Expanded Command line" — read that when debugging why a unit did or didn't get pulled in.

## Source layout

`source/` is the unit tree. A **unit** is a directory with a `Config` file; units compose via `REQUIRES` / `REQUESTS` / `DEFAULT` / `CHILDORDER` / `LINKIF` directives and `PARAMETER` declarations. Multiple implementations of the same unit live as siblings (e.g. `Hydro/HydroMain/split` vs `unsplit`); setup picks one based on setup-variables and `DEFAULT` statements. Top-level units:

- `Driver/` — top-level time-stepper (`Driver_evolveFlash.F90`, `Driver_initFlash.F90`), owns `flash4`'s `main` via `Simulation/Flash.F90`. Variants under `DriverMain/{Split,Unsplit,multithreaded,INSfracstep}`.
- `Grid/` — AMR/data-structure abstraction. Backends in `GridMain/{paramesh,UG,Chombo,Samrai}` selected by `+pm4dev`/`+ug`/etc. Everything else calls `Grid_*` and stays backend-agnostic.
- `physics/` — `Hydro`, `Eos`, `RadTrans`, `Gravity`, `Diffuse`, `materialProperties/{Conductivity,Opacity,Viscosity,…}`, `sourceTerms/{Burn,Cool,Heat,Stir,Flame,EnergyDeposition,…}`. Each has a `*Main/<variant>/Config` so you can swap solvers without touching callers.
- `Simulation/` — `SimulationMain/<problem>/` is where new problems live. `Config` declares the unit DAG via `REQUIRES`/`REQUESTS`; the per-problem `Simulation_initBlock.F90`, `Simulation_init.F90`, etc. are the user-customization hooks. `Simulation/SimulationMain/Sedov/` and `…/LaserSlab/` are canonical references.
- `IO/`, `Particles/`, `Multispecies/`, `numericalTools/`, `flashUtilities/`, `RuntimeParameters/`, `monitors/`, `multiprocessorTools/` — supporting units.

The Driver calls into physics units through `Driver_sourceTerms.F90` and the per-unit `*_init` / `*_computeDt` / `Driver_stepSee` hooks; adding a new physics effect means (1) creating a unit with a `Config`, (2) `REQUESTS`-ing it from `SimulationMain/<problem>/Config`, (3) optionally wiring it into the driver loop.

## Site configuration (this machine)

Compiler/library paths live in `sites/<hostname>/Makefile.h`. `setup` copies the matching site file into the objdir as `Makefile.h`. **This tree has no `sites/ares/`** — the host-specific configs are baked into the existing objdirs (`cases/*/Makefile.h`) and pin:

- `MPI_PATH   = /home/ubuntu/local/flash/myFLASH4.8/mpich`
- `HDF5_PATH  = /home/ubuntu/local/flash/myFLASH4.8/hdf5`
- `HYPRE_PATH = /home/ubuntu/local/flash/myFLASH4.8/hypre`
- `FCOMP`/`CCOMP`/`LINK` = `${MPI_PATH}/bin/mpif90` / `mpicc` / `mpif90`
- gfortran-style flags: `-fdefault-real-8 -fdefault-double-8`; OpenMP via `-fopenmp` (`OPENMP` macro).

If you `./setup` a fresh problem it will look for a `sites/$(hostname)/Makefile.h`. When missing, copy the block from `cases/LaserSlab/Makefile.h` (or whichever case matches the intended backend) into a new `sites/<hostname>/Makefile.h` rather than editing the generated objdir copy — the latter gets regenerated on every `./setup`.

### libmpi.so.40 conflict (this machine only)

Documented in `note.txt` and `cases/NOTE.txt`: the system provides `libmpi.so.40`, which conflicts with the local `mpich` build that `libHYPRE.so` links against. Build-time workaround:

```bash
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40 /lib/x86_64-linux-gnu/libmpi.so.40.bak
make -j4
sudo mv /lib/x86_64-linux-gnu/libmpi.so.40.bak /lib/x86_64-linux-gnu/libmpi.so.40
```

Expect the warning otherwise; it's only fatal at runtime if `libmpi.so.40` ends up on the loader path.

## Local additions

- `source/Simulation/SimulationMain/Sunliang_laser_CH/` is a user-added problem (a multi-species CH/CHBr laser-slab variant derived from `LaserSlab`). It ships its own EOS/opacity tables (`.cn4` / `.imx` / `.ses` / `AU.ionmix`) and parfiles (`example*.par`, `3Din2D.par`, `coldstart_*.par`). The matching objdir is `cases/Sunliang_laser_CH`.
- `cases/` is purely an objdir scratch area — files there (`*.o`, `*.F90`, `Makefile.*`, `setup_*`) are **generated** by `./setup` from `source/`. Do not hand-edit; modify `source/Simulation/SimulationMain/<problem>/` and re-run `./setup`.
- `lib/` holds the **internal** library glue (`pfft`, `ma28`, `dummyMPI`, …) — see `lib/HOWTO.txt` for the `Config` / `libinfo.py` / `build.csh` contract. External libs (mpi, hdf5, hypre) live outside the repo at `/home/ubuntu/local/flash/myFLASH4.8/*` and are referenced from `Makefile.h`.

## Tooling & post-processing

- `bin/setup.py` and friends (`genFiles.py`, `linkFiles.py`, `unitCfg.py`, `rpStructs.py`) implement the unit-DAG expansion and runtime-parameter codegen. Reading `bin/setup.py main()` is the fastest way to understand what `./setup` actually does.
- `tools/scripts/codeCheck.py`, `tools/scripts/checklinks.sh`, `tools/scripts/cleanPM.py` — sanity checks.
- `tools/sfocu/sfocu` — F90 unit-test framework; `tools/fidlr3.0/` — IDL plotting (Flash users typically use the Python tools instead).
- `tools/flmake` — alternate Python front-end (driven by `setup_alt`).
- `docs/designDocs/` — per-unit design notes; `RELEASE-NOTES` — changelog.

## Adding a new problem (short version)

1. `cp -r source/Simulation/SimulationMain/Sedov source/Simulation/SimulationMain/<MyProblem>` (Sedov for hydro-only; LaserSlab for laser+radiation).
2. Edit `Config` (declare `REQUIRES`/`REQUESTS`/`PARAMETER`s) and the `Simulation_initBlock.F90` / `Simulation_init.F90` stubs.
3. Drop a `flash.par` template (copy from a sibling problem and rename to `<name>.par` so `-parfile=` finds it).
4. `./setup <MyProblem> [opts] -auto -objdir=cases/<MyProblem>`.
5. `cd cases/<MyProblem> && make -j4 && ./flash4 -parfile=flash.par`.

Runtime parameters declared in `Config` (via `PARAMETER <name> TYPE [CONSTANT] [default]`) become namelist entries in `flash.par`; constants are baked in at compile time, non-constants are read at startup.
