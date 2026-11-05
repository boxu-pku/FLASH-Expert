---
title: setup 生成的 Makefile.<Unit> 漏掉对象文件 → 链接 undefined reference（.mod 有 .o 不进链接）
category: 编译/链接期
machine: ares (本机)
severity: fatal（make 链接阶段 collect2: error）
first_seen: 2026-08-14
last_verified: 2026-08-14
verifier: claude
status: stable
tags:
  - setup
  - make
  - 链接
  - undefined-reference
  - mtmmmt
  - makefile-unit
---

# setup 生成的 Makefile.<Unit> 漏对象文件 → 链接 undefined reference

## 错误现象

新建算例 setup 后 `make`，编译期 .o/.mod 都正常生成，但链接阶段报一串
`undefined reference to '__simulation_data_MOD_sim_*'` / `eos_initphysdata_` 等。

**关键特征**：符号确实有定义（`nm Simulation_data.o` 能看到 `__simulation_data_MOD_*`），
.mod 也生成了，但链接器就是找不到——因为**该 .o 根本没进链接命令**。

## 原因

FLASH 的对象列表是分散生成的：

- `Makefile` 里 `ALL_OBJ_FILES = ... $(Simulation) ... $(Eos) ...`，各 unit 的对象变量定义在
  对应的 `Makefile.<Unit>`（如 `Makefile.Simulation`、`Makefile.Eos`）里；
- `Makefile.<Unit>` 由 `setup` 生成。setup 扫描 unit 源文件生成 `Unit += xxx.o` 列表。

两类成因都会让某个 .o 漏出对象列表：

1. **setup 选项遗漏导致整个 unit 变体没被包含**。本例：3T 表格 EOS 算例 setup 漏了
   `+mtmmmt`，于是 `EosMain/Tabulated`（eos_tab*.o）和 `multiTemp` 的数据文件
   （eos_initPhysData.o、eos_vecData.o 等）完全没进 `Makefile.Eos`，objdir 里连符号链接都没建。

2. **setup 生成 `Makefile.Simulation` 的 bug**：主体的 `Simulation += ...` 列表里不含
   `Simulation_data.o`，需要在末尾单独追加一行 `Simulation += Simulation_data.o`。
   本机对 `ICF1D_CH` 漏了这一行（`ICF3D_CH` 的 Makefile.Simulation 里有，可能是历史 setup/手动补的）。

## 诊断（通用方法）

```bash
cd cases/<case>
# 1. 符号确实有定义吗?
nm Simulation_data.o | grep -i "simulation_data"     # 有 → 编译 OK, 是链接漏了
# 2. .o 在链接命令里吗?
make -n | grep -oE "Simulation_[a-z]+\.o" | sort -u   # 对比"能工作的同类 case"
# 3. 定位对象列表文件
grep -n "Simulation_data.o" Makefile.Simulation       # 缺则确认根因
diff ../<known_good_case>/Makefile.Simulation Makefile.Simulation
```

判断依据：`.o 含符号 + .mod 生成 + 但 make -n 链接列表没有它` = 对象列表漏了该文件。

## 修复

```bash
# 成因2(setup bug): 手动补进 Makefile.Simulation（注意: 会被下次 setup 覆盖, 需重加）
echo 'Simulation += Simulation_data.o' >> Makefile.Simulation

# 成因1(选项遗漏): 重新 setup 并补上正确选项
./setup <Case> ... +mtmmmt ...   # 3T 表格 EOS 必带 +mtmmmt
```

## 预防 / 经验教训

- **3T 表格 EOS（IONMIX4/Tabulated）算例的 setup 命令必须带 `+mtmmmt`**，
  否则 Tabulated EOS 整个不编入，报 `eos_tab*` / `eos_initphysdata_` 未定义。
  参照可用模板：ICF3D_CH / LaserSlab / Sunliang_laser_CH 的 setup_call。
- 从已有算例抄 setup 命令时，逐项核对所有 `+xxx`，别在改维度/几何时把 `+mtmmmt` 这类
  看似无关的选项弄丢。
- 每次 setup 后检查 `Makefile.<Unit>` 是否包含 `*_data.o`（尤其 `Simulation_data.o`）。
- 手动改 `Makefile.<Unit>` 是治标——重新 setup 会覆盖，重 setup 后需重加。

## 源码/配置锚点

- 对象列表来源：`cases/<case>/Makefile` 的 `ALL_OBJ_FILES`（~283 行）+ `include Makefile.<Unit>`
- unit 对象变量定义：`cases/<case>/Makefile.<Unit>`
- module 依赖/编译规则：`cases/<case>/Makefile.Depend`（`DATA_OBJS +=` 行）
- 参考正常 case：`cases/ICF3D_CH/`
