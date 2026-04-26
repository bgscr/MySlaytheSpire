# Multi-Enemy Encounter Foundation Design

日期：2026-04-26

## 目标

为跑图遭遇建立多敌人基础，让普通战和精英战不再隐含“一个节点只有一个敌人”。本阶段只处理遭遇生成和顺序约定，不实现完整战斗 UI、敌人行动结算或多目标选择界面。

本设计优先验证：

- `EncounterGenerator` 可以返回多个敌人 id。
- 同 seed、同节点 id、同节点类型的敌人组合和顺序可复现。
- 普通战、精英战、Boss 有明确的敌人数范围。
- 当前敌人池内容不足时不会崩溃，也不会硬造不存在的敌人。
- 后续敌人轮流进攻可以使用 encounter 数组顺序作为默认行动顺序。

## 范围

包含：

- 扩展 `EncounterGenerator.generate()` 的生成规则，让返回值仍为 `Array[String]`，但长度可大于 1。
- 普通战支持 1-3 名 normal 敌人。
- 精英战支持 1-2 名 elite 敌人。
- Boss 战保持 1 名 boss 敌人。
- 对敌人池不足的情况进行降级：最多返回池内可选敌人数，不重复填充。
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
- 可复现优先：敌人数量和敌人选择都来自 `RngService.new(seed_value).fork("encounter:%s" % node_id)`。
- Boss 保守：Boss 暂时单体，避免过早设计 Boss 随从和特殊编队。

## 生成规则

### 节点类型到 tier

沿用现有映射：

| node_type | enemy tier |
| --- | --- |
| `combat` | `normal` |
| `elite` | `elite` |
| `boss` | `boss` |
| 其他值 | `normal` |

### 敌人数范围

| node_type | 数量范围 | 当前内容池行为 |
| --- | --- | --- |
| `combat` | 1-3 | 如果 normal 池只有 1 个敌人，只返回 1 个 |
| `elite` | 1-2 | 如果 elite 池只有 1 个敌人，只返回 1 个 |
| `boss` | 1 | 返回 1 个 boss |

### 选择算法

1. 根据 `node_type` 找到 tier。
2. 从 `ContentCatalog.get_enemies_by_tier(tier)` 读取候选池。
3. 如果候选池为空，返回 `[]`。
4. 使用 encounter fork RNG 先决定目标数量。
5. 使用 `shuffle_copy(pool)` 打乱候选池。
6. 返回打乱后前 `min(target_count, pool.size())` 个敌人 id。

本阶段不使用 `encounter_weight`。权重和固定 encounter group 留给敌人池扩展阶段。

## 后续战斗顺序约定

当前 `CombatState.enemies` 已经是 `Array[CombatantState]`。后续将 encounter id 数组实例化为战斗敌人时，应保持 encounter 数组顺序。敌人轮流进攻的第一版可以按 `CombatState.enemies` 从左到右依次执行意图。

本设计不实现该轮流进攻逻辑，只明确数据顺序约定，避免后续 UI、战斗和存档模块各自发明顺序规则。

## 测试策略

扩展 `tests/unit/test_encounter_generator.gd`：

- `combat` 在有 3 个 normal 敌人的测试 catalog 中返回 1-3 个 normal enemy id。
- `elite` 在有 2 个 elite 敌人的测试 catalog 中返回 1-2 个 elite enemy id。
- `boss` 仍只返回 1 个 boss enemy id。
- 同 seed、同节点 id、同节点类型返回完全相同的数组和顺序。
- 不同节点 id 可以生成不同组合或顺序。
- 空敌人池返回 `[]`。
- 候选池不足时不重复 id。

测试可以使用手工构造的 `ContentCatalog.enemies_by_id` 和 `EnemyDef`，避免为了测试生成规则而新增正式敌人资源。

## 验收标准

完成后应满足：

- `EncounterGenerator.generate()` 保持原签名并返回 `Array[String]`。
- 单敌人旧测试仍通过。
- 新多敌人测试覆盖普通战和精英战。
- Boss 仍是单敌人。
- 生成结果可复现，且不包含不存在的敌人 id。
- Godot headless 测试输出 `TESTS PASSED`。
- Godot headless import check 退出码为 0。

## 非目标

- 不新增正式 normal/elite/boss 敌人资源。
- 不做敌人轮流进攻的执行逻辑。
- 不做 CombatScreen 多目标 UI。
- 不做 encounter group Resource。
- 不做敌人权重选择。
