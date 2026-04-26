# Dual Starter Card Pools Design

日期：2026-04-26

## 目标

在已完成的 Phase 2 内容承载基础上，为剑修和丹修各新增 4 张基础卡牌，让两个角色的卡池从示例状态进入可测试的小型内容池。

本设计优先验证：

- 新卡牌主要通过 Godot Resource 增加，而不是改核心流程。
- `ContentCatalog` 能加载更多角色专属卡牌。
- 两个角色的奖励池能保持隔离，不互相混入。
- 新卡牌只使用现有最小效果类型，避免在内容扩充时引入新的战斗规则风险。

## 范围

包含：

- 剑修新增 4 张卡牌 Resource。
- 丹修新增 4 张卡牌 Resource。
- 更新两个角色的 `card_pool_ids`。
- 更新 `ContentCatalog.DEFAULT_CARD_PATHS`。
- 添加卡牌本地化 key。
- 扩展内容目录、奖励生成和资源一致性测试。

不包含：

- 新战斗 effect 类型。
- 新卡牌 UI、卡图、美术、音效或动画。
- 升级牌、删牌、商店、事件、遗物或敌人扩展。
- 正式商业数值平衡。

## 卡牌设计

### 剑修

剑修表达主动进攻、连斩、破势和短时爆发。第一批卡牌只用基础效果体现方向。

| id | 名称 | 费用 | 类型 | 稀有度 | 效果 |
| --- | --- | --- | --- | --- | --- |
| `sword.guard` | 凝气护身 | 1 | `skill` | `common` | 获得 7 护体 |
| `sword.flash_cut` | 流光斩 | 1 | `attack` | `common` | 造成 4 伤害，抽 1 张牌 |
| `sword.qi_surge` | 剑气回流 | 0 | `skill` | `uncommon` | 获得 1 能量 |
| `sword.break_stance` | 破势一剑 | 2 | `attack` | `uncommon` | 造成 10 伤害，施加 1 层 `broken_stance` |

### 丹修

丹修表达炼丹、药性、毒雾、回复和资源转化。第一批卡牌只用基础效果体现准备和持续收益。

| id | 名称 | 费用 | 类型 | 稀有度 | 效果 |
| --- | --- | --- | --- | --- | --- |
| `alchemy.healing_draught` | 回春丹露 | 1 | `skill` | `common` | 回复 5 生命 |
| `alchemy.poison_mist` | 淬毒烟岚 | 1 | `skill` | `common` | 对敌人施加 3 层 `poison` |
| `alchemy.inner_fire_pill` | 内火丹 | 0 | `skill` | `uncommon` | 获得 1 能量，抽 1 张牌 |
| `alchemy.cauldron_burst` | 丹炉迸火 | 2 | `attack` | `uncommon` | 造成 7 伤害，获得 4 护体 |

## 架构

新增内容沿用 Phase 2 承载层：

```text
resources/cards/<character>/*.tres
-> ContentCatalog.DEFAULT_CARD_PATHS
-> CharacterDef.card_pool_ids
-> ContentCatalog.validate()
-> RewardGenerator.generate_card_reward()
```

每张卡牌是一个 `CardDef` Resource，使用一个或多个内嵌 `EffectDef` sub-resource。`character_id` 必须匹配所属角色，`pool_tags` 记录 `"starter"`，`reward_weight` 保持 100。

`ContentCatalog` 继续使用显式路径列表。本次不引入递归扫描，以保持导出行为可预测。

## 资源命名

新增资源路径：

```text
resources/cards/sword/guard.tres
resources/cards/sword/flash_cut.tres
resources/cards/sword/qi_surge.tres
resources/cards/sword/break_stance.tres
resources/cards/alchemy/healing_draught.tres
resources/cards/alchemy/poison_mist.tres
resources/cards/alchemy/inner_fire_pill.tres
resources/cards/alchemy/cauldron_burst.tres
```

本地化 key 使用：

```text
card.<id>.name
card.<id>.desc
```

示例：`card.sword.guard.name` 和 `card.sword.guard.desc`。

## 测试策略

扩展现有测试，不新增测试框架：

- `tests/unit/test_content_catalog.gd`
  - 默认 catalog 加载 10 张卡牌。
  - 剑修卡池包含 5 张，丹修卡池包含 5 张。
  - 两个卡池互不包含对方卡牌。
  - 新增卡牌的本地化 key 通过 `validate()`。

- `tests/unit/test_reward_generator.gd`
  - 剑修卡牌奖励只从剑修卡池产生。
  - 丹修卡牌奖励只从丹修卡池产生。
  - 请求 3 张卡时，在当前 5 张角色卡池中返回 3 张不重复卡。

- `tests/unit/test_combat_engine.gd`
  - 新增多效果卡牌可通过现有 `play_card_in_state()` 承载。
  - 覆盖一张攻击加抽牌卡和一张能量加抽牌卡，避免资源效果组合误配。

## 验收标准

完成后应满足：

- 默认 `ContentCatalog` 加载 10 张卡牌、2 个角色、3 个敌人和 1 个遗物。
- 剑修和丹修各有 5 张可查询卡牌。
- 所有新增卡牌资源有唯一 id、角色归属、本地化 key 和可执行效果。
- 奖励生成仍按角色隔离卡池。
- Godot headless 测试输出 `TESTS PASSED`。
- Godot headless import check 退出码为 0。

## 非目标

- 不做卡牌升级和稀有度掉落曲线。
- 不做复杂状态结算，例如毒的回合衰减或破势的独立规则。
- 不把这些卡牌接入正式 UI 选牌体验之外的新界面。
- 不新增美术资源。
