# Combat Session Targeting Design

日期：2026-04-26

## 目标

把多敌人遭遇接入真实战斗流程，建立可扩展、可测试的第一版战斗循环。玩家从地图进入战斗后，应看到 encounter 生成的多个敌人，使用真实手牌和能量，先点卡牌再点目标，并在结束回合后由敌人按顺序执行意图。

本设计优先验证：

- 地图节点进入战斗时使用 `EncounterGenerator` 生成敌人列表。
- `CombatState.enemies` 按 encounter id 顺序创建。
- 战斗开始使用当前 run 的角色、HP 和 deck 初始化。
- 玩家回合支持真实抽牌、能量、出牌、弃牌和目标选择。
- 非敌方目标卡也进入可取消的确认状态。
- 敌人按数组顺序执行 `intent_sequence`。
- 胜利进入奖励，失败进入总结。

## 范围

包含：

- 新增 `CombatSession` 作为战斗流程状态机。
- 将 map combat/elite/boss 节点进入战斗时的 encounter 初始化接入 session。
- 用完整基础牌堆规则管理 draw pile、hand、discard pile、exhausted pile。
- 支持先点卡牌，再点敌人或确认玩家目标。
- 支持右键、Esc 和可见取消按钮取消 pending 选牌。
- 支持卡牌费用检查、能量扣除、效果结算、出牌进弃牌。
- 支持结束回合：手牌进弃牌，敌人按顺序行动，再开启下一玩家回合。
- 支持敌人 `attack_N` 和 `block_N` 意图解析。
- 支持击杀敌人、全敌击败胜利、玩家 HP 归零失败。
- 为 session 规则补单元测试，为 UI 流程补 smoke 测试。

不包含：

- 动画、粒子、音效、镜头震动。
- 完整美术化战斗 UI。
- 群体目标、随机目标、嘲讽、站位或多目标选择规则。
- 新敌人资源、新卡牌资源或新遗物资源。
- 遗物触发、事件、商店、奖励生成细化。
- 保存战斗中牌堆状态；战斗仍是单场内存状态。

## 架构

### `CombatSession`

新增 `scripts/combat/combat_session.gd`，`class_name CombatSession`，继承 `RefCounted`。它负责战斗流程规则，不直接创建 Godot UI 节点。

主要职责：

- 持有 `CombatState`、`ContentCatalog`、`CombatEngine`。
- 从 `RunState.current_node_id` 找到当前 map node。
- 调用 `EncounterGenerator.generate(catalog, run.seed_value, node.id, node.node_type)`。
- 根据 encounter id 和 `EnemyDef.max_hp` 创建敌方 `CombatantState`。
- 根据 `RunState.current_hp/max_hp` 创建玩家 `CombatantState`。
- 使用 `RunState.deck_ids` 初始化并洗牌 draw pile。
- 管理 `phase`、pending card、pending hand index。
- 处理选牌、取消、确认敌方目标、确认玩家目标、结束回合。
- 处理胜利和失败，并把结算结果写回 `RunState`。

建议 phase 字符串：

| phase | 含义 |
| --- | --- |
| `player_turn` | 可以选择手牌或结束回合 |
| `selecting_enemy_target` | 已选中需要敌方目标的卡 |
| `confirming_player_target` | 已选中只作用于玩家/自身的卡 |
| `enemy_turn` | 敌人行动结算中 |
| `won` | 全部敌人被击败 |
| `lost` | 玩家 HP 归零 |
| `invalid` | 战斗初始化失败，UI 显示错误并允许返回地图或总结 |

`CombatScreen` 可以根据 phase 渲染按钮状态，不应自己判断战斗规则。

### `CombatState`

现有 `CombatState` 继续作为战斗数据容器。它已经拥有：

- `player`
- `enemies`
- `draw_pile`
- `hand`
- `discard_pile`
- `exhausted_pile`
- `energy`
- `turn`
- `pending_draw_count`
- `gold_delta`

本阶段允许为 `CombatantState` 增加最小的敌人回合状态，例如 `intent_index`，用于记录每个敌人下一次读取 `intent_sequence` 的位置。该状态只影响战斗内存，不进入 save 格式。

### `CombatScreen`

`scripts/ui/combat_screen.gd` 负责展示和输入转发：

- 创建当前节点的 `CombatSession`。
- 显示玩家 HP、block、energy、turn。
- 显示 draw/discard/exhausted 数量。
- 显示多个敌人按钮，包含 id、HP、block、当前 intent。
- 显示手牌按钮，包含 card id、cost、类型。
- 点手牌调用 `session.select_card(hand_index)`。
- 点敌人调用 `session.confirm_enemy_target(enemy_index)`。
- 点玩家确认按钮调用 `session.confirm_player_target()`。
- 点取消按钮、右键或 Esc 调用 `session.cancel_selection()`。
- 点结束回合调用 `session.end_player_turn()`。
- 当 session phase 为 `won` 时跳转奖励；为 `lost` 时标记 run failed 并跳转总结。

UI 可以保持朴素按钮布局，不做卡牌美术或复杂排版。

## 数据流

### 进入战斗

1. `MapScreen._enter_node(node)` 设置 `run.current_node_id = node.id`。
2. combat/elite/boss 节点跳转到 `CombatScreen`。
3. `CombatScreen._ready()` 创建 `ContentCatalog` 并 `load_default()`。
4. `CombatScreen` 创建 `CombatSession` 并调用初始化方法。
5. `CombatSession` 找到当前 map node。
6. `EncounterGenerator` 生成 encounter enemy ids。
7. `CombatSession` 按 encounter 顺序创建敌人。
8. `CombatSession` 洗 draw pile 并抽 5。
9. `CombatScreen` 渲染玩家、敌人和手牌。

如果当前节点不存在、角色不存在、deck 为空、或 encounter 主单位池为空，session 应进入 `lost` 以外的错误安全状态并让 UI 显示错误文本；不应崩溃。实施计划可以用 `phase = "invalid"` 或错误字符串实现，但必须测试缺失当前节点的情况。

### 目标选择

卡牌目标分类按 effects 计算：

- 如果任一 effect 的 `target` 是 `enemy` 或 `target`，卡牌需要敌方目标。
- 如果没有敌方目标 effect，卡牌需要玩家目标确认。
- 混合卡牌，例如同时有 `damage enemy` 和 `block player`，需要敌方目标；结算时敌方效果作用于选中敌人，玩家效果仍通过 `EffectExecutor` 作用于玩家。

交互流程：

1. 玩家点手牌。
2. session 检查 phase、hand index、费用。
3. 费用不足时不进入 pending 状态，并暴露错误文本。
4. 费用足够时记录 pending card 和 hand index。
5. 敌方目标卡进入 `selecting_enemy_target`。
6. 玩家目标卡进入 `confirming_player_target`。
7. 玩家可用右键、Esc 或取消按钮取消 pending 状态。
8. 确认目标后扣能量、执行效果、从 hand 移除卡牌并加入 discard pile。
9. 如果 `pending_draw_count > 0`，session 立即按抽牌规则抽对应数量，然后清零。
10. 结算后检查胜利/失败，否则回到 `player_turn`。

### 牌堆规则

- 战斗开始：`draw_pile = run.deck_ids.duplicate()`，用战斗 RNG 洗牌。
- 开局抽 5 张；如果 deck 少于 5 张，能抽多少抽多少。
- 抽牌时从 `draw_pile` 末尾或开头取牌都可以，但必须稳定、可测试。
- 抽牌堆空且弃牌堆不空时，洗 `discard_pile` 成新的 `draw_pile`，清空弃牌堆，然后继续抽。
- 抽牌堆和弃牌堆都空时停止抽牌。
- 出牌后，该卡 id 进入 `discard_pile`。
- 玩家结束回合时，所有剩余 hand 进入 `discard_pile`，hand 清空。
- 新玩家回合开始时 energy 重置为 3，玩家 block 清零，抽 5。

本阶段不实现 exhaust 卡牌规则；`exhausted_pile` 保留为空或只由未来效果使用。

### 敌人回合

敌人按 `CombatState.enemies` 顺序行动，跳过已击败敌人。

支持意图格式：

| intent | 行为 |
| --- | --- |
| `attack_N` | 对玩家造成 N 点伤害，走 `CombatantState.take_damage()` |
| `block_N` | 敌人获得 N 点 block |

每个敌人使用自己的 `intent_index` 读取 `EnemyDef.intent_sequence`。行动后 `intent_index += 1`，下次按 sequence size 取模。如果敌人没有 intent，则跳过行动。

敌人回合流程：

1. 先清空所有未击败敌人的 block。
2. 敌人按 `CombatState.enemies` 顺序行动，跳过已击败敌人。
3. 每个敌人执行当前 intent 后推进自己的 `intent_index`。

敌人回合结束后：

- 如果玩家 HP 归零，phase = `lost`。
- 否则进入新玩家回合。

敌人 block 因此会保留给玩家下一回合处理，但不会跨过敌人的下一次行动永久累积。玩家 block 继续在玩家结束回合时清零。

### 战斗结束

胜利：

- 所有敌人 `is_defeated()` 时 phase = `won`。
- 写回 `run.current_hp = state.player.current_hp`。
- 如果 `state.gold_delta > 0`，写回 `run.gold += state.gold_delta`。
- `CombatScreen` 跳转 `RewardScreen`。

失败：

- 玩家 HP 为 0 时 phase = `lost`。
- 写回 `run.current_hp = 0`。
- 设置 `run.failed = true`。
- `CombatScreen` 跳转 `RunSummaryScreen`。

不在本阶段保存战斗中状态。离开战斗后，draw/hand/discard 仅属于这场 session。

## 测试策略

### 单元测试

新增 `tests/unit/test_combat_session.gd`，覆盖：

- 从 run 当前节点生成 encounter，并按顺序创建 enemies。
- 玩家 HP、deck、energy、turn 初始化正确。
- 开局抽 5，deck 不足时少抽。
- 出牌扣能量、移出 hand、进入 discard pile。
- 费用不足不出牌，并保留 hand/energy。
- 敌方目标卡先进入 `selecting_enemy_target`，确认后只伤害选中敌人。
- 玩家目标卡进入 `confirming_player_target`，确认后作用于玩家。
- pending 状态可以取消，取消后不扣能量、不移动卡牌、不造成效果。
- 混合目标卡选敌后，同时对敌人和玩家生效。
- 回合结束时手牌进弃牌，敌人按顺序执行 `attack_N` / `block_N`。
- 敌人 block 会保留到玩家下一回合，并在下一次敌人回合开始时清零。
- 抽牌堆空时洗弃牌堆继续抽。
- 全敌击败进入 `won` 并写回 run HP/gold。
- 玩家死亡进入 `lost` 并设置 run failed。

### Smoke 测试

扩展 `tests/smoke/test_scene_flow.gd`：

- 从 App 创建 run，进入 map，点击 combat 节点后 CombatScreen 创建 session。
- CombatScreen 存在玩家状态、至少一个敌人按钮、手牌按钮、结束回合按钮。
- 点一张敌方目标卡后出现取消按钮或 pending 状态文本。
- 取消后回到可出牌状态。

Smoke 测试不要求打完整场战斗，完整战斗规则由 session 单元测试覆盖。

## 验收标准

完成后应满足：

- `CombatSession` 可独立单元测试，不依赖 Godot UI 节点。
- map combat/elite/boss 节点进入战斗时使用 `EncounterGenerator`。
- 多敌人按 encounter 顺序显示并参与战斗。
- 玩家使用真实 hand、energy、draw/discard pile。
- 先点卡牌，再点敌人或确认玩家目标；结算前可以取消。
- 卡牌费用、目标路由、混合效果、抽牌效果都可工作。
- 敌人按 intent 顺序行动。
- 胜利进入 reward，失败进入 summary。
- 不新增 save 字段，不新增正式内容资源。
- Godot headless 测试输出 `TESTS PASSED`。
- Godot headless import check 退出码为 0。

## 非目标

- 不做正式战斗视觉表现。
- 不做完整敌人 AI 设计。
- 不做群体攻击、随机目标或多目标 UI。
- 不做遗物、事件、商店或奖励池扩展。
- 不做战斗中存档恢复。
- 不做动画时序；所有规则可以即时结算。
