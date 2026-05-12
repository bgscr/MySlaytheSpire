extends RefCounted

const ContentCatalog := preload("res://scripts/content/content_catalog.gd")
const EnemyIntentDisplayResolver := preload("res://scripts/presentation/enemy_intent_display_resolver.gd")

func test_resolver_parses_attack_block_and_status_intents() -> bool:
	var original_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var resolver := EnemyIntentDisplayResolver.new()
	var attack_zh_label := tr("intent.attack.label")
	var attack_zh := resolver.resolve("attack_5", catalog)
	TranslationServer.set_locale("en")
	var attack_en := resolver.resolve("attack_5", catalog)
	var block := resolver.resolve("block_6", catalog)
	var poison := resolver.resolve("apply_status_poison_2_player", catalog)
	var passed: bool = attack_zh.get("display_id") == "attack" \
		and attack_zh.get("kind") == "attack" \
		and attack_zh.get("amount") == 5 \
		and attack_zh.get("target") == "player" \
		and attack_zh.get("label") == attack_zh_label \
		and attack_zh.get("is_known") == true \
		and attack_en.get("label") == "Attack" \
		and block.get("display_id") == "block" \
		and block.get("kind") == "block" \
		and block.get("amount") == 6 \
		and block.get("target") == "self" \
		and block.get("label") == "Block" \
		and poison.get("display_id") == "status.poison" \
		and poison.get("kind") == "apply_status" \
		and poison.get("status_id") == "poison" \
		and poison.get("amount") == 2 \
		and poison.get("target") == "player" \
		and poison.get("label") == "Poison"
	TranslationServer.set_locale(original_locale)
	assert(passed)
	return passed

func test_resolver_handles_status_ids_with_underscores() -> bool:
	var original_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var resolver := EnemyIntentDisplayResolver.new()
	var broken := resolver.resolve("apply_status_broken_stance_2_player", catalog)
	var focus := resolver.resolve("self_status_sword_focus_1", catalog)
	var passed: bool = broken.get("display_id") == "status.broken_stance" \
		and broken.get("kind") == "apply_status" \
		and broken.get("status_id") == "broken_stance" \
		and broken.get("amount") == 2 \
		and broken.get("target") == "player" \
		and broken.get("label") == "Broken Stance" \
		and focus.get("display_id") == "status.sword_focus" \
		and focus.get("kind") == "self_status" \
		and focus.get("status_id") == "sword_focus" \
		and focus.get("amount") == 1 \
		and focus.get("target") == "self" \
		and focus.get("label") == "Sword Focus"
	TranslationServer.set_locale(original_locale)
	assert(passed)
	return passed

func test_resolver_returns_unknown_for_malformed_intents() -> bool:
	var original_locale := TranslationServer.get_locale()
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var resolver := EnemyIntentDisplayResolver.new()
	TranslationServer.set_locale("zh_CN")
	var unknown_label := tr("intent.unknown.label")
	var malformed_attack := resolver.resolve("attack_bad", catalog)
	var malformed_status := resolver.resolve("apply_status_poison_player", catalog)
	var unknown := resolver.resolve("wait", catalog)
	TranslationServer.set_locale("en")
	var passed: bool = malformed_attack.get("display_id") == "unknown" \
		and malformed_attack.get("kind") == "unknown" \
		and malformed_attack.get("is_known") == false \
		and malformed_attack.get("label") == unknown_label \
		and malformed_status.get("display_id") == "unknown" \
		and malformed_status.get("is_known") == false \
		and unknown.get("display_id") == "unknown" \
		and unknown.get("label") == unknown_label \
		and unknown.get("show_amount") == false \
		and unknown.get("show_target") == false
	TranslationServer.set_locale(original_locale)
	assert(passed)
	return passed

func test_default_enemy_intents_resolve_to_known_displays() -> bool:
	var catalog := ContentCatalog.new()
	catalog.load_default()
	var resolver := EnemyIntentDisplayResolver.new()
	for enemy in catalog.enemies_by_id.values():
		for intent in enemy.intent_sequence:
			var display := resolver.resolve(intent, catalog)
			if not bool(display.get("is_known", false)):
				push_error("Enemy intent has no known display: %s %s" % [enemy.id, intent])
				assert(false)
				return false
	assert(true)
	return true
