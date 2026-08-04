# RuntimeParameters_get — 读 runtime parameter（泛型接口）

> **状态**：beta | **最后核对**：2026-07-12 | **源码版本**：FLASH 4.8

## 定义位置

| 类型 | 文件:行号 |
|---|---|
| **泛型 interface 声明** | `source/RuntimeParameters/RuntimeParameters_interface.F90:62` |
| **getReal 实现** | `source/RuntimeParameters/RuntimeParameters_get.F90:50` |
| **getInt 实现** | `source/RuntimeParameters/RuntimeParameters_get.F90:56` |
| **getStr 实现** | `source/RuntimeParameters/RuntimeParameters_get.F90:62` |
| **getLog 实现** | `source/RuntimeParameters/RuntimeParameters_get.F90:68` |
| **RuntimeParametersMain 真实实现** | `source/RuntimeParameters/RuntimeParametersMain/RuntimeParameters_get.F90`（含 dispatch 逻辑） |

## 关键事实：**这不是单个 subroutine**

`RuntimeParameters_get` 是**泛型接口**（generic interface），编译器根据第二个参数的类型自动 dispatch 到 4 个具体实现：

```fortran
! source/RuntimeParameters/RuntimeParameters_interface.F90:62-87
interface RuntimeParameters_get
   subroutine RuntimeParameters_getReal (name, value)       ! value 是 real
     character(len=*), intent(in)  :: name
     real,             intent(out) :: value
   end subroutine

   subroutine RuntimeParameters_getInt (name, value)        ! value 是 integer
     character(len=*), intent(in)  :: name
     integer,          intent(out) :: value
   end subroutine

   subroutine RuntimeParameters_getStr (name, value)        ! value 是 character
     character(len=*), intent(in)  :: name
     character(len=*), intent(out) :: value
   end subroutine

   subroutine RuntimeParameters_getLog (name, value)        ! value 是 logical
     character(len=*), intent(in)  :: name
     logical,          intent(out) :: value
   end subroutine
end interface
```

→ 你**不需要**指定 getReal / getInt，编译器看 value 类型自动选。

## 调用形式

```fortran
! 实际用法（编译器自动 dispatch）：
real    :: wavelength
integer :: maxBeams
character(len=80) :: crossSecType
logical :: useLaser

call RuntimeParameters_get("ed_wavelength_1", wavelength)        ! → getReal
call RuntimeParameters_get("ed_numberOfBeams", maxBeams)         ! → getInt
call RuntimeParameters_get("ed_crossSectionFunctionType_1", crossSecType)  ! → getStr
call RuntimeParameters_get("useEnergyDeposition", useLaser)      ! → getLog
```

## 工作机制（运行时）

1. 用户在 parfile 写 `ed_wavelength_1 = 1.053`
2. `RuntimeParameters_read` 在启动时把 (name, value, type) 三元组存到一个全局表
3. `RuntimeParameters_getReal` 接收 name = "ed_wavelength_1"
4. 在表里查 name → 取出 value → 写到调用者的 value 参数
5. 找不到名字 → 通常返回默认值或 abort（取决于实现）

## 何时调用

### 启动时（init 阶段）

每个单元的 `*_init.F90` 大量调 `RuntimeParameters_get` 把 parfile 值读到模块全局变量：

```fortran
! source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/EnergyDeposition_init.F90:79-144
call RuntimeParameters_get("useEnergyDeposition", ed_useEnergyDeposition)
call RuntimeParameters_get("basenm",             ed_baseName)
call RuntimeParameters_get("ed_gradOrder",       ed_gradOrder)
call RuntimeParameters_get("ed_laser3Din2D",     ed_laser3Din2D)
! ... 几十个调用 ...
```

→ 这些值存在 `EnergyDeposition_data` 模块里，运行时整个单元共享。

### 运行时（每步）

某些参数动态查（如 beam 的 wavelength）：

```fortran
! source/physics/sourceTerms/EnergyDeposition/EnergyDepositionMain/Laser/LaserBeams/ed_setupBeams.F90:170-300
do beam = 1, ed_numberOfBeams
   write (parameterString, '(a,i0)') "ed_wavelength_", beam     ! 拼名字
   call RuntimeParameters_get(parameterString, wavelength)       ! 动态查
   ! ...
end do
```

→ 这是 `ed_<prop>_<i>` 参数能被生成的关键：用字符串拼接 + 动态查找。

## 相关 API

| 接口 | 作用 |
|---|---|
| `RuntimeParameters_get` | 读参数 |
| `RuntimeParameters_set` | 改参数（运行时改 parfile 值，谨慎用） |
| `RuntimeParameters_add` | 在 Config 里声明新参数（genLines 替代方案） |
| `RuntimeParameters_getNum` | 查询总参数数 |
| `RuntimeParameters_getAll` | 取所有参数 |
| `RuntimeParameters_read` | 启动时从 parfile 读所有 |
| `RuntimeParameters_bcast` | MPI 广播参数到所有 processor |

## 常被问到的问题

**Q: 字符串名字拼错会怎样？**
A: 通常 abort（"[RuntimeParameters_get] Unknown parameter name"）。但有的实现只是返回默认值或 0，看具体实现。

**Q: 能在运行时改参数吗？**
A: 用 `RuntimeParameters_set`，但要小心：
- 模块全局变量（`ed_*`）已经在 init 时缓存，set 不会更新它们
- 必须重新 init 或手动改模块变量

**Q: parfile 没写的参数会用默认值吗？**
A: 是。Config 里的 `PARAMETER <name> <type> <default>` 决定默认值。

**Q: 参数类型必须匹配吗？**
A: 必须严格匹配。`integer :: v; call RuntimeParameters_get("ed_wavelength_1", v)` 会编译错（编译器认出 dispatch 到 getInt，但参数声明是 real）。

## 跨 skill 引用

- 想了解 `ed_*` 参数的生成机制 → `flash-laser/knowledge/internals.md §6 Config genLines`
- 想了解参数声明语法 → `flash-param-query` skill（待 Phase 1 Week 2 建）

## 变更日志

| 日期 | 改动 | 改动人 |
|---|---|---|
| 2026-07-12 | 初始创建（泛型接口机制 + dispatch 规则 + 典型用法） | claude |
