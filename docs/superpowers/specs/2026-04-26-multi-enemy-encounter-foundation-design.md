# Multi-Enemy Encounter Foundation Design

日期：2026-04-26

## 目标

为跑图遭遇建立多敌人基础，让普通战和精英战不再隐含“一个节点只有一个敌人”。本阶段只处理遭遇生成和顺序约定，不实现完整战斗 UI、敌人行动结算或多目标选择界面。

本设计优先验证：

- `EncounterGenerator` 可以返回多个敌人 id。
- 同 seed、同节点 id、同节点类型的敌人组合和顺序可复现。
- 普通战、精英战、Boss 有明确的主单位和支援单位规则。
- 精英战可以是纯精英组合，也可以是精英带普通敌人。
- Boss 战可以是 Boss 单体，也可以是 Boss 带普通或精英支援敌人。
- 当前敌人池内容不足时不会崩溃，也不会硬造不存在的敌人。
- 后续敌人轮流进攻可以使用 encounter 数组顺序作为默认行动顺序。

## 范围

包含：

- 扩展 `EncounterGenerator.generate()` 的生成规则，让返回值仍为 `Array[String]`，但长度可大于 1。
- 普通战支持 1-3 名 normal 敌人。
- 精英战支持 1-2 名 elite 主单位，并可追加 0-2 名 normal 支援单位，总数最多 3。
- Boss 战支持 1 名 boss 主单位，并可追加 0-2 名 normal 或 elite 支援单位，总数最多 3。
- 对敌人池不足的情况进行降级：主单位缺失时返回 `[]`，支援单位不足时少返回，不重复填充。
- 为多敌人组合、顺序确定性、空池行为补单元测试。

不包含：

- 新敌人资源制作。
- 敌人行动 AI、意图执行、回合推进或轮流进攻结算。
- 战斗 UI 多目标选择。
- 群体攻击、随机目标、嘲讽或站位系统。
- 存档格式新增字段。

## 设计原则

- 保持接口小：`generate()` 继续返回敌人 id 数组，调用方不需要理解新数据结构。
- 不重复敌人：在敌人池数量不足时返回更少敌人，不复制同一个资源 id。
- 顺序即行动基础：返回数组顺序视为默认敌人行动顺序，后续 Combat 初始化应按该顺序创建 `CombatState.enemies`。
- 主单位优先：精英和 Boss 遭遇的主单位排在数组前部，支援单位排在后部，便于后续 UI 和行动顺序表达威胁层级。
- 可复现优先：敌人数量和敌人选择都来自 `RngService.new(seed_value).fork("encounter:%s" % node_id)`。
- 支援保守：本阶段只支持从现有 tier 池抽支援单位，不新增 encounter group Resource 或固定编队表。

## 生成规则

### 节点类型到敌人池

节点类型决定主单位池和可选支援池：

| node_type | 主单位池 | 支援池 |
| --- | --- | --- |
| `combat` | `normal` | 无 |
| `elite` | `elite` | `normal` |
| `boss` | `boss` | `normal`、`elite` |
| 其他值 | `normal` | 无 |

### 敌人数范围

| node_type | 数量范围 | 当前内容池行为 |
| --- | --- | --- |
| `combat` | 1-3 | 如果 normal 池只有 1 个敌人，只返回 1 个 |
| `elite` | 1-3 | 至少 1 个 elite；可追加 normal 支援 |
| `boss` | 1-3 | 至少 1 个 boss；可追加 normal 或 elite 支援 |

### 选择算法

1. 根据 `node_type` 找到主单位 tier 和支援 tier。
2. 从 `ContentCatalog.get_enemies_by_tier(...)` 读取主单位池和支援池。
3. 如果主单位池为空，返回 `[]`。
4. 使用 encounter fork RNG 决定主单位数量和支援单位数量。
5. 使用 `shuffle_copy(pool)` 分别打乱主单位池和支援池。
6. 先加入主单位，再加入支援单位。
7. 返回前 `max_total_count` 个敌人 id，不重复同一个 id。

本阶段不使用 `encounter_weight`。权重和固定 encounter group 留给敌人池扩展阶段。

### 具体数量规则

- `combat`：从 normal 主单位池抽 1-3 个，受池大小限制。
- `elite`：从 elite 主单位池抽 1-2 个，受池大小限制；再从 normal 支援池抽 0-2 个，总数最多 3。
- `boss`：从 boss 主单位池抽 1 个；再从 normal + elite 支援池抽 0-2 个，总数最多 3。

如果支援池为空，仍可返回只有主单位的遭遇。如果主单位池为空，返回 `[]`，避免 elite 节点没有精英、Boss 节点没有 Boss。

## 后续战斗顺序约定

当前 `CombatState.enemies` 已经是 `Array[CombatantState]`。后续将 encounter id 数组实例化为战斗敌人时，应保持 encounter 数组顺序。敌人轮流进攻的第一版可以按 `CombatState.enemies` 从左到右依次执行意图。

本设计不实现该轮流进攻逻辑，只明确数据顺序约定，避免后续 UI、战斗和存档模块各自发明顺序规则。

## 测试策略

扩展 `tests/unit/test_encounter_generator.gd`：

- `combat` 在有 3 个 normal 敌人的测试 catalog 中返回 1-3 个 normal enemy id。
- `elite` 在有 2 个 elite 和 2 个 normal 的测试 catalog 中返回 1-3 个敌人，且至少包含 1 个 elite。
- `elite` 在多 seed 覆盖中可以生成纯 elite 组合，也可以生成 elite + normal 混合组合。
- `boss` 在有 1 个 boss、normal 和 elite 支援池的测试 catalog 中返回 1-3 个敌人，且第一个敌人是 boss。
- `boss` 在多 seed 覆盖中可以生成 Boss 单体，也可以生成 Boss + 支援单位。
- 同 seed、同节点 id、同节点类型返回完全相同的数组和顺序。
- 不同节点 id 可以生成不同组合或顺序。
- 主单位池为空时返回 `[]`。
- 候选池不足时不重复 id。

测试可以使用手工构造的 `ContentCatalog.enemies_by_id` 和 `EnemyDef`，避免为了测试生成规则而新增正式敌人资源。

## 验收标准

完成后应满足：

- `EncounterGenerator.generate()` 保持原签名并返回 `Array[String]`。
- 旧测试更新为验证主单位存在、数量范围和 tier 合法性，而不是断言固定单敌人数组。
- 新多敌人测试覆盖普通战、精英战和 Boss 战。
- 精英和 Boss 遭遇支持支援单位。
- 生成结果可复现，且不包含不存在的敌人 id。
- Godot headless 测试输出 `TESTS PASSED`。
- Godot headless import check 退出码为 0。

## 非目标

- 不新增正式 normal/elite/boss 敌人资源。
- 不做敌人轮流进攻的执行逻辑。
- 不做 CombatScreen 多目标 UI。
- 不做 encounter group Resource。
- 不做敌人权重选择。
- 不做多 Boss 同场规则；Boss 战本阶段固定 1 个 boss 主单位，可带支援单位。
