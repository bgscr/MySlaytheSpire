# Phase 2 Content Capacity Design

日期：2026-04-26

## 目标

建立第二阶段的内容承载能力，让后续扩充两名角色的卡池、遗物、敌人、Boss、事件和商店时主要新增 Godot Resource，而不是反复改核心流程。

本阶段优先解决这些问题：

- 内容资源能被集中加载、按 id 查询，并被测试覆盖。
- 角色卡池、奖励池、遭遇池和 Boss 池能基于 seed 可复现生成。
- 资源一致性错误能在本地测试中暴露，而不是运行时才发现。
- 新增卡牌和遗物所需的最小效果类型能被战斗逻辑承载。
- 后续批量内容制作可以像填表一样进行，不需要先重构基础设施。

## 范围

本设计覆盖内容承载核心，不覆盖批量正式内容制作。

包含：

- ContentCatalog：集中索引卡牌、角色、敌人、遗物。
- RewardGenerator：生成可复现的卡牌、金币和遗物奖励候选。
- EncounterGenerator：根据地图节点类型生成普通战、精英战和 Boss 遭遇。
- 资源 schema 小幅扩展：补齐内容池、权重、层级和角色归属字段。
- EffectExecutor 最小扩展：支持抽牌、能量、状态施加和金币类效果的数据承载与逻辑测试。
- 资源一致性测试：id 唯一、引用存在、本地化 key 存在、生成器可复现。

不包含：

- 一次性补齐 40 张卡、15-20 个遗物、10+ 敌人、2 个 Boss。
- 最终事件文本、商店 UI、正式美术、音频和动画。
- 复杂状态系统、遗物触发系统完整实现、商业级平衡。
- Steamworks、CI、发布流水线或多语言完整翻译。

## 设计原则

- 资源优先：新内容默认通过 `.tres` 增加，核心代码只提供通用承载能力。
- 显式索引优先：早期使用固定资源路径列表，避免递归扫描的不确定性和导出差异。
- 可复现优先：奖励和遭遇生成必须通过 `RngService` 派生随机流。
- 兼容优先：现有 Phase 1 `.tres` 不应因为新增字段失效。
- 测试优先：每个新承载能力先有失败测试，再实现。

## 架构

### ContentCatalog

新增 `scripts/content/content_catalog.gd`。

职责：

- 维护卡牌、角色、敌人、遗物的资源路径列表。
- 加载资源并建立 id -> Resource 字典。
- 提供查询接口：
  - `get_card(card_id: String) -> CardDef`
  - `get_character(character_id: String) -> CharacterDef`
  - `get_enemy(enemy_id: String) -> EnemyDef`
  - `get_relic(relic_id: String) -> RelicDef`
  - `get_cards_for_character(character_id: String) -> Array[CardDef]`
  - `get_cards_by_rarity(character_id: String, rarity: String) -> Array[CardDef]`
  - `get_enemies_by_tier(tier: String) -> Array[EnemyDef]`
  - `get_relics_by_tier(tier: String) -> Array[RelicDef]`
- 提供校验接口 `validate() -> Array[String]`，返回错误字符串列表。

Catalog 不负责随机选择，也不修改 RunState 或 CombatState。

### RewardGenerator

新增 `scripts/reward/reward_generator.gd`。

职责：

- 接收 `ContentCatalog`、`seed_value`、`character_id` 和奖励上下文。
- 使用 `RngService.new(seed_value).fork("reward:%s" % context_key)` 创建可复现随机流。
- 生成奖励候选：
  - 卡牌奖励：从角色卡池按稀有度权重抽取 3 张不重复卡。
  - 金币奖励：普通战低，精英战高，Boss 可配置。
  - 遗物奖励：按 tier 选择候选。
- 返回普通 Dictionary 数据，便于存档和 UI 使用。

RewardGenerator 不直接写入 RunState。奖励应用由后续奖励处理器或 UI 调用决定。

### EncounterGenerator

新增 `scripts/run/encounter_generator.gd`。

职责：

- 接收 `ContentCatalog`、`seed_value` 和地图节点信息。
- 根据节点类型生成遭遇：
  - `combat` -> normal 敌人池。
  - `elite` -> elite 敌人池。
  - `boss` -> boss 敌人池。
- 使用 `RngService` 派生 `encounter:%s` 随机流，保证同 seed 和同节点 id 结果一致。
- 返回敌人 id 列表，不实例化 UI 或场景。

### Resource Schema

扩展现有 Resource，保持默认值兼容 Phase 1。

`CardDef` 新增：

- `character_id: String = ""`
- `pool_tags: Array[String] = []`
- `reward_weight: int = 100`

`EnemyDef` 新增：

- `tier: String = "normal"`
- `encounter_weight: int = 100`
- `gold_reward_min: int = 8`
- `gold_reward_max: int = 14`

`RelicDef` 新增：

- `tier: String = "common"`
- `reward_weight: int = 100`

`EffectDef` 新增或约定：

- `effect_type = "draw_card"` 使用 `amount` 表示抽牌数。
- `effect_type = "gain_energy"` 使用 `amount` 表示获得能量。
- `effect_type = "apply_status"` 使用 `status_id` 和 `amount`。
- `effect_type = "gain_gold"` 使用 `amount`，主要用于奖励/事件承载。

### Combat State Support

为了承载新效果，`CombatState` 需要支持：

- `pending_draw_count: int`
- `gold_delta: int`

`CombatantState.statuses` 已存在，可用于 `apply_status` 的最小实现：同名状态叠加数值，非正数不改变状态。

`gain_energy` 修改 `CombatState.energy`，因此 `CombatEngine.play_card` 需要一个能接收 `CombatState` 的新入口，例如：

- `play_card_in_state(card: CardDef, state: CombatState, source: CombatantState, target: CombatantState) -> void`

原有 `play_card(card, source, target)` 保留，用于兼容已有测试和简单效果。

## 数据流

```text
Resource files
-> ContentCatalog.load_default()
-> ContentCatalog.validate()
-> RewardGenerator / EncounterGenerator
-> UI or Run flow receives plain Dictionary / enemy id list
-> later tasks apply rewards or start combat
```

## 测试策略

新增或扩展测试：

- `tests/unit/test_content_catalog.gd`
  - 加载默认资源。
  - id 唯一。
  - 角色卡池引用都能解析。
  - 本地化 key 在 `localization/zh_CN.po` 中存在。
  - 按角色、稀有度、敌人 tier、遗物 tier 查询正确。

- `tests/unit/test_reward_generator.gd`
  - 同 seed、同上下文生成相同奖励。
  - 不同上下文能派生不同结果。
  - 卡牌奖励只来自对应角色卡池。
  - 空池返回明确错误或空候选，不崩溃。

- `tests/unit/test_encounter_generator.gd`
  - `combat` 生成 normal 敌人。
  - `elite` 生成 elite 敌人。
  - `boss` 生成 boss 敌人。
  - 同 seed 和节点 id 结果可复现。

- `tests/unit/test_combat_engine.gd`
  - `draw_card` 增加 pending draw。
  - `gain_energy` 增加能量。
  - `apply_status` 叠加状态。
  - `gain_gold` 写入 `gold_delta`。

所有新增行为必须先写失败测试，再实现。

## 验收标准

本阶段完成后应满足：

- 默认 ContentCatalog 能加载现有资源并通过一致性校验。
- 奖励和遭遇生成器可复现，并有本地单元测试覆盖。
- 资源 schema 支持 Phase 2 批量内容所需的角色归属、层级和权重字段。
- 最小新增 effect 类型可在逻辑层测试通过。
- Godot headless 测试入口仍输出 `TESTS PASSED`。
- Godot headless import 检查退出码为 0，且没有新增资源路径错误。

## 后续工作

完成内容承载能力后，再进入批量内容制作计划：

1. 剑修基础卡池扩展。
2. 丹修基础卡池扩展。
3. 遗物池扩展。
4. 普通/精英/Boss 敌人池扩展。
5. 事件和商店 Resource 化。
