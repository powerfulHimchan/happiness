#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
game_root="$project_root/game"
check_shard_count="${GODOT_CHECK_SHARD_COUNT:-1}"
check_shard_index="${GODOT_CHECK_SHARD_INDEX:-0}"
check_timeout_multiplier="${GODOT_CHECK_TIMEOUT_MULTIPLIER:-1}"
if [[ ! "$check_timeout_multiplier" =~ ^[1-4]$ ]]; then
  echo "Godot check timeout multiplier must be an integer from 1 to 4." >&2
  exit 1
fi
if [[ ! "$check_shard_count" =~ ^[1-9][0-9]?$ || ! "$check_shard_index" =~ ^[0-9]{1,2}$ ]]; then
  echo "Invalid Godot check shard." >&2
  exit 1
fi
check_shard_count=$((10#$check_shard_count))
check_shard_index=$((10#$check_shard_index))
if (( check_shard_count > 16 || check_shard_index >= check_shard_count )); then
  echo "Godot check shard index must be smaller than count (1–16)." >&2
  exit 1
fi

required_files=(
  "$game_root/scripts/ui/supply_shop_motion.gd"
  "$game_root/scripts/ui/supply_shop_detail_art.gd"
  "$game_root/tests/gp1031_1050_presentation_runtime_test.gd"
  "$game_root/scripts/ui/task_board_motion.gd"
  "$game_root/scripts/ui/task_board_detail_art.gd"
  "$game_root/tests/gp1011_1030_presentation_runtime_test.gd"
  "$game_root/scripts/economy/partnership_run_tasks.gd"
  "$game_root/tests/gp961_1010_runtime_test.gd"
  "$game_root/scripts/stage/windmill_meadow.gd"
  "$game_root/scripts/stage/windmill_meadow_layout.gd"
  "$game_root/scripts/stage/windmill_meadow_art.gd"
  "$game_root/tests/windmill_meadow_runtime_test.gd"
  "$game_root/tests/fixtures/legacy_movement_sandbox.tscn"
  "$game_root/scripts/combat/conditional_weapon_designs.gd"
  "$game_root/scripts/economy/supply_shop_browser.gd"
  "$game_root/scripts/ui/weapon_catalog_browser.gd"
  "$game_root/scripts/ui/supply_shop_inspector.gd"
  "$game_root/tests/gp911_960_runtime_test.gd"
  "$game_root/assets/links/archive.svg"
  "$game_root/assets/links/switch.svg"
  "$game_root/assets/links/evade.svg"
  "$game_root/assets/links/critical.svg"
  "$game_root/assets/links/hurt.svg"
  "$game_root/assets/links/potion.svg"
  "$game_root/assets/links/skill.svg"
  "$game_root/assets/links/frame_active.svg"
  "$game_root/assets/links/frame_dormant.svg"
  "$game_root/assets/links/frame_locked.svg"

  "$game_root/scripts/ui/combat_links_art.gd"
  "$game_root/scripts/ui/combat_links_menu_motion.gd"
  "$game_root/scripts/player/combat_link_feedback.gd"
  "$game_root/tests/gp891_910_presentation_runtime_test.gd"
  "$game_root/scripts/growth/prototype_combat_links.gd"
  "$game_root/scripts/ui/combat_links_view.gd"
  "$game_root/tests/gp841_890_runtime_test.gd"
  "$game_root/scripts/player/hero_motion_polish.gd"
  "$game_root/tests/gp831_840_animation_runtime_test.gd"
  "$game_root/scripts/ui/hero_status_art.gd"
  "$game_root/tests/gp821_830_art_runtime_test.gd"
  "$game_root/assets/status/dawn_archive.svg"
  "$game_root/assets/status/attack.svg"
  "$game_root/assets/status/defense.svg"
  "$game_root/assets/status/critical_chance.svg"
  "$game_root/assets/status/critical_damage.svg"
  "$game_root/assets/status/health.svg"
  "$game_root/assets/status/roan_counter.svg"
  "$game_root/assets/status/lumi_starlight.svg"
  "$game_root/assets/status/main_weapon_frame.svg"
  "$game_root/assets/status/backup_weapon_frame.svg"
  "$game_root/scripts/ui/hero_status_view.gd"
  "$game_root/scripts/growth/prototype_stat_specializations.gd"
  "$game_root/tests/gp770_820_runtime_test.gd"
  "$game_root/scripts/player/hero_traits.gd"
  "$game_root/tests/hero_traits_runtime_test.gd"
  "$game_root/scripts/growth/prototype_combat_stats.gd"
  "$game_root/tests/hero_stats_runtime_test.gd"
  "$game_root/scripts/growth/achievement_research.gd"
  "$game_root/scripts/ui/achievement_browser.gd"
  "$game_root/tests/gp718_767_runtime_test.gd"
  "$game_root/scripts/growth/prototype_combat_tactics.gd"
  "$game_root/tests/gp668_717_runtime_test.gd"
  "$game_root/scripts/ui/run_preparation_view.gd"
  "$game_root/scripts/ui/hero_selection_view.gd"
  "$game_root/scripts/ui/hero_selection_motion.gd"
  "$game_root/assets/status/attack_speed.svg"
  "$game_root/assets/preparation/hero-detail-shade.svg"
  "$game_root/assets/preparation/lettering/heading.svg"
  "$game_root/assets/preparation/lettering/back.svg"
  "$game_root/assets/preparation/lettering/reselect.svg"
  "$game_root/assets/preparation/lettering/next.svg"
  "$game_root/assets/preparation/lettering/roan.svg"
  "$game_root/assets/preparation/lettering/lumi.svg"
  "$game_root/scripts/ui/equipped_hero_preview.gd"
  "$game_root/scripts/ui/weapon_preparation_view.gd"
  "$game_root/scripts/ui/weapon_preparation_art.gd"
  "$game_root/scripts/ui/weapon_skill_preview.gd"
  "$game_root/assets/preparation/weapons/bow.svg"
  "$game_root/assets/preparation/weapons/fist-pair.svg"
  "$game_root/assets/preparation/weapons/fist.svg"
  "$game_root/assets/preparation/weapons/polearm.svg"
  "$game_root/assets/preparation/weapons/shield.svg"
  "$game_root/assets/preparation/weapons/staff.svg"
  "$game_root/assets/preparation/weapons/sword.svg"
  "$game_root/assets/preparation/skills/bow_arrow_rain.svg"
  "$game_root/assets/preparation/skills/bow_piercing.svg"
  "$game_root/assets/preparation/skills/fist_dash.svg"
  "$game_root/assets/preparation/skills/fist_flurry.svg"
  "$game_root/assets/preparation/skills/polearm_sweep.svg"
  "$game_root/assets/preparation/skills/polearm_thrust.svg"
  "$game_root/assets/preparation/skills/shield_counter.svg"
  "$game_root/assets/preparation/skills/shield_guard.svg"
  "$game_root/assets/preparation/skills/staff_fireball.svg"
  "$game_root/assets/preparation/skills/staff_ice_lance.svg"
  "$game_root/assets/preparation/skills/sword_dash.svg"
  "$game_root/assets/preparation/skills/sword_spin.svg"
  "$game_root/assets/preparation/weapon-lettering/back.svg"
  "$game_root/assets/preparation/weapon-lettering/backup-selected.svg"
  "$game_root/assets/preparation/weapon-lettering/backup.svg"
  "$game_root/assets/preparation/weapon-lettering/bow.svg"
  "$game_root/assets/preparation/weapon-lettering/bow_arrow_rain.svg"
  "$game_root/assets/preparation/weapon-lettering/bow_piercing.svg"
  "$game_root/assets/preparation/weapon-lettering/close.svg"
  "$game_root/assets/preparation/weapon-lettering/fist.svg"
  "$game_root/assets/preparation/weapon-lettering/fist_dash.svg"
  "$game_root/assets/preparation/weapon-lettering/fist_flurry.svg"
  "$game_root/assets/preparation/weapon-lettering/heading.svg"
  "$game_root/assets/preparation/weapon-lettering/hero.svg"
  "$game_root/assets/preparation/weapon-lettering/polearm.svg"
  "$game_root/assets/preparation/weapon-lettering/polearm_sweep.svg"
  "$game_root/assets/preparation/weapon-lettering/polearm_thrust.svg"
  "$game_root/assets/preparation/weapon-lettering/primary.svg"
  "$game_root/assets/preparation/weapon-lettering/return.svg"
  "$game_root/assets/preparation/weapon-lettering/settings.svg"
  "$game_root/assets/preparation/weapon-lettering/shield.svg"
  "$game_root/assets/preparation/weapon-lettering/shield_counter.svg"
  "$game_root/assets/preparation/weapon-lettering/shield_guard.svg"
  "$game_root/assets/preparation/weapon-lettering/staff.svg"
  "$game_root/assets/preparation/weapon-lettering/staff_fireball.svg"
  "$game_root/assets/preparation/weapon-lettering/staff_ice_lance.svg"
  "$game_root/assets/preparation/weapon-lettering/start.svg"
  "$game_root/assets/preparation/weapon-lettering/sword.svg"
  "$game_root/assets/preparation/weapon-lettering/sword_dash.svg"
  "$game_root/assets/preparation/weapon-lettering/sword_spin.svg"
  "$game_root/assets/preparation/storybook.svg"
  "$game_root/tests/run_preparation_runtime_test.gd"
  "$game_root/scripts/economy/advanced_run_tasks.gd"
  "$game_root/tests/gp618_667_runtime_test.gd"
  "$game_root/scripts/ui/start_screen_view.gd"
  "$game_root/scripts/ui/start_screen_backdrop.gd"
  "$game_root/assets/title/dawn-motion.gdshader"
  "$game_root/assets/title/lettering/dawn-title.svg"
  "$game_root/assets/title/lettering/subtitle.svg"
  "$game_root/assets/title/lettering/continue.svg"
  "$game_root/assets/title/lettering/new-journey.svg"
  "$game_root/assets/title/lettering/village.svg"
  "$game_root/assets/title/lettering/journal.svg"
  "$game_root/assets/title/lettering/settings.svg"
  "$game_root/tests/start_screen_runtime_test.gd"
  "$game_root/assets/title/dawn-road.png"
  "$game_root/assets/title/menu-shade.tres"
  "$game_root/scripts/ui/relic_art.gd"
  "$game_root/tests/gp608_617_art_runtime_test.gd"
  "$game_root/assets/relics/phoenix_feather.svg"
  "$game_root/assets/relics/clock_fragment.svg"
  "$game_root/assets/relics/spring_dew.svg"
  "$game_root/assets/relics/dawn_ember.svg"
  "$game_root/assets/relics/hourglass.svg"
  "$game_root/assets/relics/guardian_seal.svg"
  "$game_root/assets/relics/wind_knot.svg"
  "$game_root/assets/relics/vital_seed.svg"
  "$game_root/assets/relics/duelist_emblem.svg"
  "$game_root/assets/relics/arcane_emblem.svg"
  "$game_root/scripts/ui/achievement_art.gd"
  "$game_root/assets/achievements/honors_hall.svg"
  "$game_root/assets/achievements/exploration.svg"
  "$game_root/assets/achievements/vocation.svg"
  "$game_root/assets/achievements/weapon.svg"
  "$game_root/assets/achievements/growth.svg"
  "$game_root/assets/achievements/ending.svg"
  "$game_root/assets/achievements/expedition.svg"
  "$game_root/assets/achievements/memory.svg"
  "$game_root/assets/achievements/bond.svg"
  "$game_root/assets/achievements/secret.svg"
  "$game_root/scripts/growth/permanent_achievements.gd"
  "$game_root/scripts/stage/achievement_store.gd"
  "$game_root/tests/gp548_597_runtime_test.gd"
  "$game_root/scripts/stage/regional_landscape_art.gd"
  "$game_root/assets/landscapes/clockwork_foundry.svg"
  "$game_root/assets/landscapes/festival_carousel.svg"
  "$game_root/assets/landscapes/smiling_city_gate.svg"
  "$game_root/scripts/growth/prototype_weapon_mastery.gd"
  "$game_root/tests/gp515_544_runtime_test.gd"
  "$game_root/tests/regional_roster_runtime_test.gd"
  "$game_root/scripts/combat/regional_enemy_roster.gd"
  "$game_root/scripts/combat/regional_enemy_pattern.gd"
  "$game_root/tests/gp508_510_art_runtime_test.gd"
  "$game_root/scripts/ui/task_board_art.gd"
  "$game_root/tests/gp478_507_runtime_test.gd"
  "$game_root/assets/tasks/traveler_board.svg"
  "$game_root/assets/tasks/path.svg"
  "$game_root/assets/tasks/map.svg"
  "$game_root/assets/tasks/battle.svg"
  "$game_root/assets/tasks/skill.svg"
  "$game_root/assets/tasks/growth.svg"
  "$game_root/assets/tasks/gear.svg"
  "$game_root/assets/tasks/trade.svg"
  "$game_root/data/skills/sword_dawn_chain.tres"
  "$game_root/data/skills/sword_retreat_wave.tres"
  "$game_root/data/skills/sword_orbit.tres"
  "$game_root/data/skills/sword_high_arc.tres"
  "$game_root/data/skills/sword_returning_edge.tres"
  "$game_root/data/skills/bow_prism_fan.tres"
  "$game_root/data/skills/bow_starlit_rain.tres"
  "$game_root/data/skills/bow_swallow_trio.tres"
  "$game_root/data/skills/bow_drill.tres"
  "$game_root/data/skills/bow_retreat_fan.tres"
  "$game_root/data/skills/fist_dawn_barrage.tres"
  "$game_root/data/skills/fist_retreat_palm.tres"
  "$game_root/data/skills/fist_spiral.tres"
  "$game_root/data/skills/fist_sky_chain.tres"
  "$game_root/data/skills/fist_twin_pulse.tres"
  "$game_root/data/skills/staff_crystal_fan.tres"
  "$game_root/data/skills/staff_meteor_pair.tres"
  "$game_root/data/skills/staff_dawn_pulse.tres"
  "$game_root/data/skills/staff_storm_seal.tres"
  "$game_root/data/skills/staff_retreat_lance.tres"
  "$game_root/data/skills/polearm_horizon.tres"
  "$game_root/data/skills/polearm_dawn_orbit.tres"
  "$game_root/data/skills/polearm_skyward.tres"
  "$game_root/data/skills/polearm_back_cross.tres"
  "$game_root/data/skills/polearm_comet.tres"
  "$game_root/data/skills/shield_dawn_chain.tres"
  "$game_root/data/skills/shield_retreat_bash.tres"
  "$game_root/data/skills/shield_orbit.tres"
  "$game_root/data/skills/shield_twin_wave.tres"
  "$game_root/data/skills/shield_cross_march.tres"
  "$game_root/scripts/economy/run_tasks.gd"
  "$game_root/scripts/ui/run_task_view.gd"
  "$game_root/tests/gp448_477_runtime_test.gd"
  "$project_root/game/scripts/ui/supply_shop_art.gd"
  "$project_root/game/assets/supplies/travel_stall.svg"
  "$project_root/game/assets/supplies/meal.svg"
  "$project_root/game/assets/supplies/potion.svg"
  "$project_root/game/assets/supplies/charge.svg"
  "$project_root/game/assets/supplies/refresh.svg"
  "$project_root/game/assets/supplies/coin.svg"
  "$project_root/game/assets/supplies/sword.svg"
  "$project_root/game/assets/supplies/bow.svg"
  "$project_root/game/assets/supplies/skill.svg"
  "$project_root/game/assets/supplies/restock.svg"

  "$game_root/tests/gp415_444_runtime_test.gd"
  "$game_root/scripts/economy/run_supply_shop.gd"
  "$game_root/scripts/ui/supply_shop_view.gd"
  "$game_root/tests/gp385_414_runtime_test.gd"
  "$game_root/scripts/growth/prototype_weapon_training.gd"
  "$game_root/data/skills/polearm_cross.tres"
  "$game_root/data/skills/shield_wave.tres"
  "$game_root/assets/weapons/motif_striker.svg"
  "$game_root/assets/weapons/motif_weaver.svg"
  "$game_root/assets/weapons/motif_balanced.svg"
  "$game_root/tests/gp375_384_runtime_test.gd"
  "$game_root/scripts/combat/weapon_family_presentation.gd"
  "$game_root/assets/weapons/fist.svg"
  "$game_root/assets/weapons/staff.svg"
  "$game_root/assets/weapons/polearm.svg"
  "$game_root/assets/weapons/shield.svg"
  "$game_root/data/skills/fist_rising.tres"
  "$game_root/data/skills/fist_cross.tres"
  "$game_root/data/skills/fist_advancing.tres"
  "$game_root/data/skills/staff_ember_volley.tres"
  "$game_root/data/skills/staff_frost_ring.tres"
  "$game_root/data/skills/staff_thunder_echo.tres"
  "$game_root/data/skills/polearm_windwheel.tres"
  "$game_root/data/skills/polearm_retreat.tres"
  "$game_root/data/skills/shield_rush.tres"
  "$game_root/data/skills/shield_ring.tres"
  "$game_root/scripts/combat/staff_combat_controller.gd"
  "$game_root/scripts/combat/staff_magic_bolt.gd"
  "$game_root/scripts/combat/polearm_combat_controller.gd"
  "$game_root/scripts/combat/shield_combat_controller.gd"
  "$game_root/data/weapons/staff_basic.tres"
  "$game_root/data/weapons/polearm_basic.tres"
  "$game_root/data/weapons/shield_basic.tres"
  "$game_root/data/skills/staff_fireball.tres"
  "$game_root/data/skills/staff_ice_lance.tres"
  "$game_root/data/skills/staff_lightning.tres"
  "$game_root/data/skills/polearm_sweep.tres"
  "$game_root/data/skills/polearm_thrust.tres"
  "$game_root/data/skills/polearm_cycle.tres"
  "$game_root/data/skills/shield_guard.tres"
  "$game_root/data/skills/shield_counter.tres"
  "$game_root/data/skills/shield_slam.tres"
  "$game_root/tests/gp354_runtime_test.gd"
  "$game_root/tests/gp364_runtime_test.gd"
  "$game_root/tests/gp374_runtime_test.gd"

  "$game_root/scripts/combat/fist_combat_controller.gd"
  "$game_root/data/weapons/fist_basic.tres"
  "$game_root/data/skills/fist_dash.tres"
  "$game_root/data/skills/fist_flurry.tres"
  "$game_root/data/skills/fist_wave.tres"
  "$game_root/tests/gp344_runtime_test.gd"
  "$game_root/tests/gp334_runtime_test.gd"
  "$game_root/tests/gp329_runtime_test.gd"
  "$game_root/tests/gp327_runtime_test.gd"
  "$game_root/scripts/stage/expedition_stage_constraint.gd"
  "$game_root/tests/gp326_constraint_runtime_test.gd"
  "$game_root/tests/gp326_runtime_test.gd"
  "$game_root/scripts/combat/expedition_boss.gd"
  "$game_root/tests/gp325_boss_runtime_test.gd"
  "$game_root/tests/gp325_runtime_test.gd"
  "$game_root/scripts/story/final_ritual.gd"
  "$game_root/tests/gp324_runtime_test.gd"
  "$game_root/tests/gp324_enemy_runtime_test.gd"
  "$game_root/tests/gp323_runtime_test.gd"
  "$game_root/tests/gp322_runtime_test.gd"
  "$game_root/tests/gp321_runtime_test.gd"
  "$game_root/scripts/combat/enemy_visual_animation.gd"
  "$game_root/tests/enemy_art_runtime_test.gd"
  "$game_root/tests/heart_art_runtime_test.gd"
  "$game_root/scripts/combat/happiness_heart_presentation.gd"
  "$game_root/assets/happiness_heart_core.svg"
  "$game_root/tests/sera_art_runtime_test.gd"
  "$game_root/scripts/combat/sera_presentation.gd"
  "$game_root/assets/prototype_sera.svg"
  "$game_root/assets/prototype_sera_awakened.svg"
  "$game_root/assets/sera_spark.svg"
  "$game_root/tests/guardian_art_runtime_test.gd"
  "$game_root/scripts/combat/happiness_guardian_presentation.gd"
  "$game_root/assets/guardian_shield.svg"
  "$game_root/tests/clockwork_knight_art_runtime_test.gd"
  "$game_root/scripts/combat/clockwork_knight_presentation.gd"
  "$game_root/scripts/player/hero_combat_animation.gd"
  "$game_root/tests/hero_combat_animation_runtime_test.gd"
  "$game_root/assets/characters/roan_combat.png"
  "$game_root/assets/characters/lumi_combat.png"
  "$game_root/tests/gp320_runtime_test.gd"
  "$game_root/scripts/story/heart_encounter.gd"
  "$game_root/scripts/combat/boss_happiness_heart.gd"
  "$game_root/assets/happiness_heart.svg"
  "$game_root/tests/gp319_runtime_test.gd"
  "$game_root/tests/gp318_runtime_test.gd"
  "$game_root/scripts/story/arrival_ending.gd"
  "$game_root/assets/characters/roan_movement.png"
  "$game_root/assets/characters/lumi_movement.png"
  "$game_root/scripts/player/hero_movement_animation.gd"
  "$game_root/tests/hero_movement_animation_runtime_test.gd"
  "$game_root/tests/gp317_runtime_test.gd"
  "$game_root/scripts/story/heart_threshold.gd"
  "$game_root/assets/heart_threshold.svg"
  "$game_root/assets/characters/roan_lumi_idle.png"
  "$game_root/assets/characters/roan_idle.tres"
  "$game_root/assets/characters/lumi_idle.tres"
  "$game_root/tests/character_art_runtime_test.gd"
  "$game_root/tests/gp316_runtime_test.gd"
  "$game_root/tests/gp315_runtime_test.gd"
  "$game_root/scripts/combat/boss_sera.gd"
  "$game_root/scripts/story/sera_encounter.gd"
  "$game_root/assets/sera_spark.svg"
  "$game_root/assets/prototype_sera_awakened.svg"
  "$game_root/tests/gp314_runtime_test.gd"
  "$game_root/assets/prototype_sera.svg"
  "$game_root/tests/gp313_runtime_test.gd"
  "$game_root/tests/gp312_runtime_test.gd"
  "$game_root/scripts/stage/guardian_decision.gd"
  "$game_root/tests/gp311_runtime_test.gd"
  "$game_root/scripts/combat/boss_happiness_guardian.gd"
  "$game_root/assets/happiness_guardian.svg"
  "$game_root/assets/guardian_lance.svg"
  "$game_root/tests/gp310_runtime_test.gd"
  "$game_root/scripts/stage/city_core_layout.gd"
  "$game_root/tests/gp309_runtime_test.gd"
  "$game_root/scripts/stage/city_gate_layout.gd"
  "$game_root/tests/gp308_runtime_test.gd"
  "$game_root/scripts/stage/region_stage_layout.gd"
  "$game_root/tests/gp307_runtime_test.gd"
  "$game_root/scripts/stage/journey_route_plan.gd"
  "$game_root/tests/gp277_306_runtime_test.gd"
  "$game_root/scripts/story/prototype_story.gd"
  "$game_root/scripts/story/prototype_story_run.gd"
  "$game_root/scripts/story/prototype_story_view.gd"
  "$game_root/scripts/story/story_journal_store.gd"
  "$game_root/tests/gp267_276_runtime_test.gd"
  "$game_root/scripts/player/prototype_characters.gd"
  "$game_root/assets/prototype_lumi.svg"
  "$game_root/tests/gp257_266_runtime_test.gd"
  "$game_root/tests/gp247_256_runtime_test.gd"
  "$game_root/tests/gp248_249_runtime_test.gd"
  "$game_root/tests/gp250_252_runtime_test.gd"
  "$game_root/assets/festival_soldier.svg"
  "$game_root/assets/festival_turret.svg"
  "$game_root/tests/gp237_246_runtime_test.gd"
  "$game_root/tests/gp239_runtime_test.gd"
  "$game_root/tests/gp240_242_runtime_test.gd"
  "$game_root/scripts/stage/clock_trap_controller.gd"
  "$game_root/assets/star_clock_doll.svg"
  "$game_root/tests/gp227_236_runtime_test.gd"
  "$game_root/tests/gp228_229_runtime_test.gd"
  "$game_root/tests/gp230_232_runtime_test.gd"
  "$game_root/tests/gp217_226_runtime_test.gd"
  "$game_root/tests/gp187_198_runtime_test.gd"
  "$game_root/tests/gp199_206_runtime_test.gd"
  "$game_root/tests/gp207_212_runtime_test.gd"
  "$game_root/tests/gp213_216_runtime_test.gd"

  "$game_root/tests/gp177_180_runtime_test.gd"
  "$game_root/tests/gp181_184_runtime_test.gd"
  "$game_root/tests/gp185_186_runtime_test.gd"
  "$game_root/data/skills/sword_revolve.tres"
  "$game_root/data/skills/bow_fan_piercing.tres"
  "$game_root/tests/gp167_170_runtime_test.gd"
  "$game_root/tests/gp171_174_runtime_test.gd"
  "$game_root/tests/gp175_176_runtime_test.gd"
  "$game_root/data/skills/sword_rising.tres"
  "$game_root/data/skills/bow_chain.tres"
  "$project_root/.github/workflows/check-godot-project.yml"
  "$project_root/.github/workflows/build-android-apk.yml"
  "$game_root/tests/gp162_166_runtime_test.gd"
  "$game_root/tests/gp159_161_runtime_test.gd"
  "$game_root/tests/gp158_runtime_test.gd"
  "$game_root/data/skills/sword_cross.tres"
  "$game_root/tests/gp157_runtime_test.gd"
  "$game_root/data/skills/bow_ricochet.tres"
  "$game_root/scripts/combat/ricochet_arrow.gd"
  "$game_root/scenes/combat/ricochet_arrow.tscn"
  "$game_root/tests/gp156_runtime_test.gd"
  "$game_root/tests/gp155_runtime_test.gd"
  "$game_root/tests/gp154_runtime_test.gd"
  "$game_root/tests/gp153_runtime_test.gd"
  "$game_root/tests/gp151_runtime_test.gd"
  "$game_root/tests/gp150_runtime_test.gd"
  "$game_root/tests/gp149_runtime_test.gd"
  "$game_root/tests/gp148_runtime_test.gd"
  "$game_root/tests/gp147_runtime_test.gd"
  "$game_root/data/skills/sword_wave.tres"
  "$game_root/scripts/combat/sword_wave.gd"
  "$game_root/tests/gp146_runtime_test.gd"
  "$game_root/tests/gp145_runtime_test.gd"
  "$game_root/data/skills/bow_homing.tres"
  "$game_root/tests/gp144_runtime_test.gd"
  "$game_root/tests/gp143_runtime_test.gd"
  "$game_root/data/skills/sword_charge.tres"
  "$game_root/data/skills/bow_retreat.tres"
  "$game_root/tests/gp142_runtime_test.gd"
  "$game_root/scripts/ui/prototype_run_build_view.gd"
  "$game_root/tests/gp141_runtime_test.gd"
  "$game_root/tests/gp140_runtime_test.gd"
  "$game_root/tests/gp139_runtime_test.gd"
  "$game_root/tests/gp138_runtime_test.gd"
  "$game_root/tests/gp137_runtime_test.gd"
  "$game_root/tests/gp136_runtime_test.gd"
  "$game_root/tests/gp135_runtime_test.gd"
  "$game_root/tests/gp134_runtime_test.gd"
  "$game_root/data/skills/sword_thrust.tres"
  "$game_root/data/skills/bow_double_piercing.tres"
  "$game_root/tests/gp133_runtime_test.gd"
  "$game_root/tests/gp132_runtime_test.gd"
  "$game_root/tests/gp131_runtime_test.gd"
  "$game_root/tests/gp130_runtime_test.gd"
  "$game_root/tests/gp129_runtime_test.gd"
  "$game_root/tests/gp128_runtime_test.gd"
  "$game_root/tests/gp127_runtime_test.gd"
  "$game_root/data/skills/sword_triple.tres"
  "$game_root/data/skills/bow_focus.tres"
  "$game_root/tests/gp126_runtime_test.gd"
  "$game_root/scripts/growth/prototype_ability_codex.gd"
  "$game_root/scripts/stage/ability_discovery_store.gd"
  "$game_root/tests/gp125_runtime_test.gd"
  "$game_root/tests/gp124_runtime_test.gd"
  "$game_root/tests/gp123_runtime_test.gd"
  "$game_root/scripts/stage/prototype_route_atlas.gd"
  "$game_root/tests/gp122_runtime_test.gd"
  "$game_root/data/skills/sword_line.tres"
  "$game_root/data/skills/bow_spread.tres"
  "$game_root/tests/gp121_runtime_test.gd"
  "$game_root/scripts/growth/prototype_potion_recipes.gd"
  "$game_root/tests/gp120_runtime_test.gd"
  "$game_root/project.godot"
  "$game_root/export_presets.cfg"
  "$game_root/scenes/movement/ground_movement_sandbox.tscn"
  "$game_root/scripts/movement/ground_movement_sandbox.gd"
  "$game_root/scripts/movement/ground_movement_controls.gd"
  "$game_root/scripts/player/prototype_player.gd"
  "$game_root/scripts/combat/damage_event.gd"
  "$game_root/scripts/combat/damage_receiver.gd"
  "$game_root/scripts/combat/weapon_definition.gd"
  "$game_root/scripts/combat/skill_definition.gd"
  "$game_root/scripts/combat/sword_combat_controller.gd"
  "$game_root/scripts/combat/bow_combat_controller.gd"
  "$game_root/scripts/combat/bow_projectile.gd"
  "$game_root/scripts/combat/prototype_weapon_controller.gd"
  "$game_root/scripts/combat/ultimate_controller.gd"
  "$game_root/scripts/combat/combat_feedback_controller.gd"
  "$game_root/scripts/combat/prototype_enemy.gd"
  "$game_root/scripts/combat/enemy_seed_projectile.gd"
  "$game_root/scripts/combat/elite_armored_boar.gd"
  "$game_root/scripts/combat/elite_shockwave.gd"
  "$game_root/scripts/stage/prototype_stage_runner.gd"
  "$game_root/scripts/telemetry/local_test_recorder.gd"
  "$game_root/tests/cp206_runtime_test.gd"
  "$game_root/tests/cp301_runtime_test.gd"
  "$game_root/tests/cp302_runtime_test.gd"
  "$game_root/tests/cp303_runtime_test.gd"
  "$game_root/tests/cp304_runtime_test.gd"
  "$game_root/tests/cp401_runtime_test.gd"
  "$game_root/tests/cp402_runtime_test.gd"
  "$game_root/tests/cp403_runtime_test.gd"
  "$game_root/tests/cp404_runtime_test.gd"
  "$game_root/tests/cp405_runtime_test.gd"
  "$game_root/tests/cp406_runtime_test.gd"
  "$game_root/tests/gp101_runtime_test.gd"
  "$game_root/scripts/growth/prototype_growth_controller.gd"
  "$game_root/scripts/growth/prototype_job_progress.gd"
  "$game_root/tests/gp102_runtime_test.gd"
  "$game_root/scripts/growth/prototype_job_rewards.gd"
  "$game_root/tests/gp103_runtime_test.gd"
  "$game_root/tests/gp104_runtime_test.gd"
  "$game_root/scripts/stage/run_checkpoint_store.gd"
  "$game_root/tests/gp105_runtime_test.gd"
  "$game_root/tests/gp106_runtime_test.gd"
  "$game_root/tests/gp107_runtime_test.gd"
  "$game_root/tests/gp108_runtime_test.gd"
  "$game_root/tests/gp109_runtime_test.gd"
  "$game_root/tests/gp110_runtime_test.gd"
  "$game_root/tests/gp111_runtime_test.gd"
  "$game_root/tests/gp112_runtime_test.gd"
  "$game_root/tests/gp113_runtime_test.gd"
  "$game_root/tests/gp114_runtime_test.gd"
  "$game_root/tests/gp115_runtime_test.gd"
  "$game_root/tests/gp116_runtime_test.gd"
  "$game_root/tests/gp117_runtime_test.gd"
  "$game_root/scripts/combat/prototype_skill_rewards.gd"
  "$game_root/data/skills/sword_crescent.tres"
  "$game_root/data/skills/bow_volley.tres"
  "$game_root/scripts/ui/prototype_village_view.gd"
  "$game_root/scripts/growth/prototype_memory_abilities.gd"
  "$game_root/scripts/stage/boss_legacy_store.gd"
  "$game_root/scripts/combat/boss_clockwork_knight.gd"
  "$game_root/assets/clockwork_knight.svg"
  "$game_root/scripts/combat/prototype_weapon_rewards.gd"
  "$game_root/scripts/stage/prototype_route_terrain.gd"
  "$game_root/scripts/combat/auto_target_selector.gd"
  "$game_root/scripts/combat/prototype_target.gd"
  "$game_root/data/weapons/sword_basic.tres"
  "$game_root/data/skills/sword_dash.tres"
  "$game_root/data/skills/sword_spin.tres"
  "$game_root/data/weapons/bow_basic.tres"
  "$game_root/data/skills/bow_piercing.tres"
  "$game_root/data/skills/bow_arrow_rain.tres"
  "$game_root/scenes/combat/bow_projectile.tscn"
  "$game_root/scenes/combat/enemy_seed_projectile.tscn"
  "$game_root/scenes/combat/elite_shockwave.tscn"
  "$game_root/assets/prototype_player.svg"
  "$game_root/assets/prototype_target.svg"
  "$game_root/assets/prototype_target_selection.svg"
  "$game_root/assets/sword_slash.svg"
  "$game_root/assets/bow_arrow.svg"
  "$game_root/assets/bow_rain.svg"
  "$game_root/assets/enemy_seed_projectile.svg"
  "$game_root/assets/leaf_slime.svg"
  "$game_root/assets/seed_sack.svg"
  "$game_root/assets/wind_spirit.svg"
  "$game_root/assets/armored_boar.svg"
  "$game_root/assets/elite_shockwave.svg"
  "$game_root/scripts/input/player_command.gd"
  "$game_root/scripts/input/player_command_buffer.gd"
  "$game_root/scripts/input/control_layout_store.gd"
  "$game_root/assets/icon.svg"
)

for required_file in "${required_files[@]}"; do
  if [[ ! -s "$required_file" ]]; then
    echo "Missing required file: $required_file" >&2
    exit 1
  fi
done

if ! rg -q 'run/main_scene="res://scenes/movement/ground_movement_sandbox.tscn"' "$game_root/project.godot"; then
  echo "Main scene is not configured correctly." >&2
  exit 1
fi

if ! rg -q 'res://scripts/movement/ground_movement_sandbox.gd' "$game_root/scenes/movement/ground_movement_sandbox.tscn"; then
  echo "Ground movement scene does not reference its controller." >&2
  exit 1
fi

if ! rg -q 'class_name PrototypePlayer' "$game_root/scripts/player/prototype_player.gd"; then
  echo "PrototypePlayer type is missing." >&2
  exit 1
fi

if ! rg -q 'avatar_sprite\.flip_h = facing_direction < 0' "$game_root/scripts/player/prototype_player.gd"; then
  echo "Player sprite facing flip is missing." >&2
  exit 1
fi

if ! rg -q 'return int\(signf\(value\)\)' "$game_root/scripts/player/prototype_player.gd"; then
  echo "Float-safe direction sign conversion is missing." >&2
  exit 1
fi

if rg -q 'signi\(' "$game_root/scripts/player/prototype_player.gd"; then
  echo "Integer sign conversion must not be used for float movement values." >&2
  exit 1
fi

if ! rg -q 'const COYOTE_TIME_S := 0\.10' "$game_root/scripts/player/prototype_player.gd"; then
  echo "CP-103 coyote time is missing." >&2
  exit 1
fi

if ! rg -q 'const JUMP_BUFFER_S := 0\.12' "$game_root/scripts/player/prototype_player.gd"; then
  echo "CP-103 jump buffer is missing." >&2
  exit 1
fi

if ! rg -q 'jump_pressed\.connect\(player\.request_jump\)' "$game_root/scripts/movement/ground_movement_sandbox.gd"; then
  echo "Jump input is not connected to the player." >&2
  exit 1
fi

if ! rg -q 'PracticePlatform' "$game_root/scenes/movement/ground_movement_sandbox.tscn"; then
  echo "CP-103 practice platform is missing." >&2
  exit 1
fi

if ! rg -q 'const GROUND_EVADE_INVINCIBLE_S := 0\.18' "$game_root/scripts/player/prototype_player.gd"; then
  echo "CP-104 ground evade invincibility is missing." >&2
  exit 1
fi

if ! rg -q 'air_dash_available = false' "$game_root/scripts/player/prototype_player.gd"; then
  echo "CP-104 air dash single-use gate is missing." >&2
  exit 1
fi

if ! rg -q 'evade_pressed\.connect\(player\.request_evade\)' "$game_root/scripts/movement/ground_movement_sandbox.gd"; then
  echo "Evade input is not connected to the player." >&2
  exit 1
fi

if ! rg -q 'const FALL_DAMAGE_RATIO := 0\.10' "$game_root/scripts/player/prototype_player.gd"; then
  echo "CP-105 fall damage ratio is missing." >&2
  exit 1
fi

if ! rg -q 'fall_recovery_started\.connect\(controls\.release_all_inputs\)' "$game_root/scripts/movement/ground_movement_sandbox.gd"; then
  echo "Fall recovery input reset is not connected." >&2
  exit 1
fi

if ! rg -q 'LeftSafeZone' "$game_root/scenes/movement/ground_movement_sandbox.tscn" \
  || ! rg -q 'RightSafeZone' "$game_root/scenes/movement/ground_movement_sandbox.tscn"; then
  echo "CP-105 safe zones are missing." >&2
  exit 1
fi

if rg -q 'size = Vector2\(5000, 120\)' "$game_root/scenes/movement/ground_movement_sandbox.tscn"; then
  echo "Continuous floor still blocks the CP-105 fall zone." >&2
  exit 1
fi

if ! rg -q 'class_name AutoTargetSelector' "$game_root/scripts/combat/auto_target_selector.gd"; then
  echo "CP-201 auto target selector is missing." >&2
  exit 1
fi

if ! rg -q 'const RETARGET_INTERVAL_S := 0\.10' "$game_root/scripts/combat/auto_target_selector.gd" \
  || ! rg -q 'const SWITCH_DISTANCE_RATIO := 0\.80' "$game_root/scripts/combat/auto_target_selector.gd" \
  || ! rg -q 'const DEFAULT_ATTACK_RANGE_M := 1\.6' "$game_root/scripts/combat/auto_target_selector.gd"; then
  echo "CP-201 targeting constants do not match the combat spec." >&2
  exit 1
fi

if ! rg -q 'offset\.x \* float\(player\.facing_direction\) <= 0\.0' "$game_root/scripts/combat/auto_target_selector.gd"; then
  echo "CP-201 forward-facing target filter is missing." >&2
  exit 1
fi

if ! rg -q 'target_selector\.target_metrics_changed\.connect\(controls\.update_target_metrics\)' "$game_root/scripts/movement/ground_movement_sandbox.gd"; then
  echo "CP-201 target metrics are not connected to the HUD." >&2
  exit 1
fi

if ! rg -q 'CrossingTargetA' "$game_root/scenes/movement/ground_movement_sandbox.tscn" \
  || ! rg -q 'RearTarget' "$game_root/scenes/movement/ground_movement_sandbox.tscn"; then
  echo "CP-201 crossing and rear target fixtures are missing." >&2
  exit 1
fi

if ! rg -q 'BodySprite' "$game_root/scenes/movement/ground_movement_sandbox.tscn" \
  || ! rg -q 'SelectionSprite' "$game_root/scenes/movement/ground_movement_sandbox.tscn"; then
  echo "CP-201 explicit target sprites are missing." >&2
  exit 1
fi

if ! rg -q 'class_name DamageEvent' "$game_root/scripts/combat/damage_event.gd" \
  || ! rg -q 'attacker_id: StringName' "$game_root/scripts/combat/damage_event.gd" \
  || ! rg -q 'stagger_s: float' "$game_root/scripts/combat/damage_event.gd" \
  || ! rg -q 'tags: PackedStringArray' "$game_root/scripts/combat/damage_event.gd"; then
  echo "CP-202 common damage event fields are missing." >&2
  exit 1
fi

if ! rg -q 'class_name DamageReceiver' "$game_root/scripts/combat/damage_receiver.gd" \
  || ! rg -q 'post_hit_invulnerability_s: float = 0\.50' "$game_root/scripts/combat/damage_receiver.gd" \
  || ! rg -q '_processed_event_ids\.has\(event\.event_id\)' "$game_root/scripts/combat/damage_receiver.gd"; then
  echo "CP-202 damage receiver or duplicate prevention is missing." >&2
  exit 1
fi

if ! rg -q 'name="DamageReceiver"' "$game_root/scenes/movement/ground_movement_sandbox.tscn" \
  || ! rg -q 'player\.receive_damage\(event\)' "$game_root/scripts/combat/enemy_seed_projectile.gd"; then
  echo "CP-202 scene integration and incoming damage path are missing." >&2
  exit 1
fi

if ! rg -q 'class_name WeaponDefinition' "$game_root/scripts/combat/weapon_definition.gd" \
  || ! rg -q 'class_name SkillDefinition' "$game_root/scripts/combat/skill_definition.gd" \
  || ! rg -q 'class_name SwordCombatController' "$game_root/scripts/combat/sword_combat_controller.gd"; then
  echo "CP-203 sword combat data or controller types are missing." >&2
  exit 1
fi

if ! rg -q 'damage = PackedInt32Array\(12, 14, 20\)' "$game_root/data/weapons/sword_basic.tres" \
  || ! rg -q 'attack_interval_s = PackedFloat32Array\(0\.28, 0\.3, 0\.42\)' "$game_root/data/weapons/sword_basic.tres"; then
  echo "CP-203 sword combo data does not match the combat spec." >&2
  exit 1
fi

if ! rg -q 'cooldown_s = 6\.0' "$game_root/data/skills/sword_dash.tres" \
  || ! rg -q 'movement_distance_m = 3\.5' "$game_root/data/skills/sword_dash.tres" \
  || ! rg -q 'damage = PackedInt32Array\(20, 20\)' "$game_root/data/skills/sword_spin.tres" \
  || ! rg -q 'cooldown_s = 9\.0' "$game_root/data/skills/sword_spin.tres"; then
  echo "CP-203 sword skill data does not match the combat spec." >&2
  exit 1
fi

if ! rg -q 'name="SwordCombatController"' "$game_root/scenes/movement/ground_movement_sandbox.tscn" \
  || ! rg -q 'skill_1_pressed\.connect\(weapon_controller\.request_skill_1\)' "$game_root/scripts/movement/ground_movement_sandbox.gd" \
  || ! rg -q 'player\.evade_started\.connect' "$game_root/scripts/combat/sword_combat_controller.gd"; then
  echo "CP-203 sword scene, input, or evade cancel integration is missing." >&2
  exit 1
fi

if ! rg -q 'class_name BowCombatController' "$game_root/scripts/combat/bow_combat_controller.gd" \
  || ! rg -q 'class_name BowProjectile' "$game_root/scripts/combat/bow_projectile.gd" \
  || ! rg -q 'class_name PrototypeWeaponController' "$game_root/scripts/combat/prototype_weapon_controller.gd"; then
  echo "CP-204 bow combat, projectile, or weapon test controller is missing." >&2
  exit 1
fi

if ! rg -q 'attack_range_m = 8\.0' "$game_root/data/weapons/bow_basic.tres" \
  || ! rg -q 'projectile_speed_mps = 14\.0' "$game_root/data/weapons/bow_basic.tres" \
  || ! rg -q 'damage = PackedInt32Array\(14\)' "$game_root/data/weapons/bow_basic.tres"; then
  echo "CP-204 bow basic attack data does not match the combat spec." >&2
  exit 1
fi

if ! rg -q 'damage = PackedInt32Array\(36\)' "$game_root/data/skills/bow_piercing.tres" \
  || ! rg -q 'max_targets = 3' "$game_root/data/skills/bow_piercing.tres" \
  || ! rg -q 'cooldown_s = 7\.0' "$game_root/data/skills/bow_piercing.tres" \
  || ! rg -q 'damage = PackedInt32Array\(8, 8, 8, 8, 8, 8\)' "$game_root/data/skills/bow_arrow_rain.tres" \
  || ! rg -q 'cooldown_s = 11\.0' "$game_root/data/skills/bow_arrow_rain.tres"; then
  echo "CP-204 bow skill data does not match the combat spec." >&2
  exit 1
fi

if ! rg -q 'screen_only and not is_target_on_screen' "$game_root/scripts/combat/auto_target_selector.gd" \
  || ! rg -q 'CLOSE_DAMAGE_MULTIPLIER := 0\.80' "$game_root/scripts/combat/bow_combat_controller.gd" \
  || ! rg -q 'weapon_swap_pressed\.connect\(weapon_controller\.request_weapon_switch\)' "$game_root/scripts/movement/ground_movement_sandbox.gd" \
  || ! rg -q 'OffscreenTarget' "$game_root/scenes/movement/ground_movement_sandbox.tscn"; then
  echo "CP-204 screen filtering, close penalty, or mobile test integration is missing." >&2
  exit 1
fi

if ! rg -q 'const SWITCH_COOLDOWN_S := 0\.50' "$game_root/scripts/combat/prototype_weapon_controller.gd" \
  || ! rg -q 'const SWITCH_BUFFER_S := 0\.20' "$game_root/scripts/combat/prototype_weapon_controller.gd" \
  || ! rg -q 'player\.can_switch_weapon\(\)' "$game_root/scripts/combat/prototype_weapon_controller.gd"; then
  echo "CP-205 weapon switch limit or action buffer is missing." >&2
  exit 1
fi

if ! rg -q 'for family in PrototypeWeaponRewards\.FAMILY_IDS' "$game_root/scripts/combat/prototype_weapon_controller.gd" \
  || ! rg -q 'combat_for\(family\)\.current_metrics\(\)' "$game_root/scripts/combat/prototype_weapon_controller.gd" \
  || ! rg -q 'basic_attack_remaining_s' "$game_root/scripts/combat/prototype_weapon_controller.gd" \
  || ! rg -q 'skill_2_cooldown_s' "$game_root/scripts/combat/prototype_weapon_controller.gd"; then
  echo "CP-205 per-weapon attack and skill cooldown state reporting is missing." >&2
  exit 1
fi

if ! rg -q '_basic_remaining_s = maxf\(0\.0, _basic_remaining_s - delta \* player\.attack_speed_multiplier\(\)\)' "$game_root/scripts/combat/sword_combat_controller.gd" \
  || ! rg -q '_basic_remaining_s = maxf\(0\.0, _basic_remaining_s - delta \* player\.attack_speed_multiplier\(\)\)' "$game_root/scripts/combat/bow_combat_controller.gd"; then
  echo "CP-205 inactive weapon attack waits must continue without reset." >&2
  exit 1
fi

if ! rg -q 'class_name UltimateController' "$game_root/scripts/combat/ultimate_controller.gd" \
  || ! rg -q 'const MAX_GAUGE := 100' "$game_root/scripts/combat/ultimate_controller.gd" \
  || ! rg -q 'const BASIC_HIT_GAIN := 4' "$game_root/scripts/combat/ultimate_controller.gd" \
  || ! rg -q 'const SKILL_HIT_GAIN := 8' "$game_root/scripts/combat/ultimate_controller.gd" \
  || ! rg -q 'const PRECISE_EVADE_GAIN := 12' "$game_root/scripts/combat/ultimate_controller.gd"; then
  echo "CP-206 ultimate gauge rules are missing." >&2
  exit 1
fi

if ! rg -q 'const DURATION_S := 3\.0' "$game_root/scripts/combat/ultimate_controller.gd" \
  || ! rg -q 'const ENEMY_TIME_SCALE := 0\.15' "$game_root/scripts/combat/ultimate_controller.gd" \
  || ! rg -q 'get_nodes_in_group\("enemy_time_scaled"\)' "$game_root/scripts/combat/ultimate_controller.gd"; then
  echo "CP-206 selective time slowdown is missing." >&2
  exit 1
fi

if rg -q 'enemy_time_scale' "$game_root/scripts/combat/bow_projectile.gd" \
  || rg -q 'Engine\.time_scale' "$game_root/scripts/combat/ultimate_controller.gd"; then
  echo "CP-206 must not slow the player or player projectiles globally." >&2
  exit 1
fi

if ! rg -q 'ultimate_pressed\.connect\(ultimate_controller\.request_ultimate\)' "$game_root/scripts/movement/ground_movement_sandbox.gd" \
  || ! rg -q 'class_name EnemySeedProjectile' "$game_root/scripts/combat/enemy_seed_projectile.gd" \
  || ! rg -q 'ultimate_gauge_ratio' "$game_root/scripts/movement/ground_movement_controls.gd"; then
	echo "CP-206 scene, input, enemy projectile, or HUD integration is missing." >&2
	exit 1
fi

if ! rg -q 'class_name PrototypeEnemy' "$game_root/scripts/combat/prototype_enemy.gd" \
  || ! rg -q 'const SLIME_WARNING_S := 0\.35' "$game_root/scripts/combat/prototype_enemy.gd" \
  || ! rg -q 'const SEED_WARNING_S := 1\.00' "$game_root/scripts/combat/prototype_enemy.gd" \
  || ! rg -q 'const WIND_WARNING_S := 0\.60' "$game_root/scripts/combat/prototype_enemy.gd"; then
	echo "CP-301 enemy types or warning durations are missing." >&2
	exit 1
fi

if ! rg -q 'const SLIME_DAMAGE := 8' "$game_root/scripts/combat/prototype_enemy.gd" \
  || ! rg -q 'const SEED_DAMAGE := 7' "$game_root/scripts/combat/prototype_enemy.gd" \
  || ! rg -q 'const WIND_DAMAGE := 10' "$game_root/scripts/combat/prototype_enemy.gd" \
  || ! rg -q 'SEED_RECOVERY_S := 1\.00' "$game_root/scripts/combat/prototype_enemy.gd" \
  || ! rg -q 'WIND_RECOVERY_S := 1\.20' "$game_root/scripts/combat/prototype_enemy.gd"; then
	echo "CP-301 damage or recovery values do not match the combat spec." >&2
	exit 1
fi

if ! rg -q 'name="LeafSlime"' "$game_root/scenes/movement/ground_movement_sandbox.tscn" \
  || ! rg -q 'name="SeedSack"' "$game_root/scenes/movement/ground_movement_sandbox.tscn" \
  || ! rg -q 'name="WindSpirit"' "$game_root/scenes/movement/ground_movement_sandbox.tscn" \
  || ! rg -q 'name="WarningRing"' "$game_root/scenes/movement/ground_movement_sandbox.tscn" \
  || ! rg -q 'name="WarningLine"' "$game_root/scenes/movement/ground_movement_sandbox.tscn"; then
	echo "CP-301 enemy fixtures or warning visuals are missing." >&2
	exit 1
fi

if ! rg -q 'class_name EliteArmoredBoar' "$game_root/scripts/combat/elite_armored_boar.gd" \
  || ! rg -q 'const MAX_HEALTH := 180' "$game_root/scripts/combat/elite_armored_boar.gd" \
  || ! rg -q 'PHASE_TWO_HEALTH_RATIO := 0\.50' "$game_root/scripts/combat/elite_armored_boar.gd" \
  || ! rg -q 'current_pattern = Pattern\.SHOCKWAVE if last_pattern == Pattern\.CHARGE else Pattern\.CHARGE' "$game_root/scripts/combat/elite_armored_boar.gd"; then
	echo "CP-302 elite health, phase change, or anti-repeat pattern rule is missing." >&2
	exit 1
fi

if ! rg -q 'SWORD_ARMOR_MULTIPLIER := 0\.60' "$game_root/scripts/combat/elite_armored_boar.gd" \
  || ! rg -q 'BOW_ARMOR_MULTIPLIER := 1\.25' "$game_root/scripts/combat/elite_armored_boar.gd" \
  || ! rg -q 'SWORD_STUN_MULTIPLIER := 1\.75' "$game_root/scripts/combat/elite_armored_boar.gd" \
  || ! rg -q 'name="ArmoredBoar"' "$game_root/scenes/movement/ground_movement_sandbox.tscn"; then
	echo "CP-302 weapon weakness values or elite scene fixture are missing." >&2
	exit 1
fi

if ! rg -q 'class_name EliteShockwave' "$game_root/scripts/combat/elite_shockwave.gd" \
  || ! rg -q 'State\.STUNNED' "$game_root/scripts/combat/elite_armored_boar.gd" \
  || ! rg -q '_spawn_shockwaves' "$game_root/scripts/combat/elite_armored_boar.gd"; then
	echo "CP-302 wall stun or shockwave integration is missing." >&2
	exit 1
fi

if ! rg -q 'class_name PrototypeStageRunner' "$game_root/scripts/stage/prototype_stage_runner.gd" \
  || ! rg -q 'SECTION_TARGET_SECONDS: Array\[float\] = \[40\.0, 35\.0, 35\.0, 40\.0, 30\.0\]' "$game_root/scripts/stage/prototype_stage_runner.gd" \
  || ! rg -q 'STAGE_TARGET_SECONDS := 180\.0' "$game_root/scripts/stage/prototype_stage_runner.gd"; then
	echo "CP-303 five-section runner or target timing is missing." >&2
	exit 1
fi

if ! rg -q 'name="GateA"' "$game_root/scenes/movement/ground_movement_sandbox.tscn" \
  || ! rg -q 'name="GateB"' "$game_root/scenes/movement/ground_movement_sandbox.tscn" \
  || ! rg -q 'name="GateC"' "$game_root/scenes/movement/ground_movement_sandbox.tscn" \
  || ! rg -q 'name="FinalGate"' "$game_root/scenes/movement/ground_movement_sandbox.tscn" \
  || ! rg -q 'stage_runner\.stage_metrics_changed\.connect\(controls\.update_stage_metrics\)' "$game_root/scripts/movement/ground_movement_sandbox.gd"; then
	echo "CP-303 gates or stage HUD metrics are missing." >&2
	exit 1
fi

if rg -q 'stage_elapsed_s >= STAGE_TARGET_SECONDS.*failed' "$game_root/scripts/stage/prototype_stage_runner.gd"; then
	echo "CP-303 target time must not cause a forced failure." >&2
	exit 1
fi

if ! rg -q 'enum ScreenMode' "$game_root/scripts/movement/ground_movement_controls.gd" \
  || ! rg -q 'damage_cause_summary' "$game_root/scripts/player/prototype_player.gd" \
  || ! rg -q '_usage_ratio' "$game_root/scripts/combat/prototype_weapon_controller.gd" \
  || ! rg -q 'retry_requested\.connect\(_reset_test\)' "$game_root/scripts/movement/ground_movement_sandbox.gd"; then
	echo "CP-304 combat HUD, result metrics, retry, or main flow is missing." >&2
	exit 1
fi

if ! rg -q 'func open_layout_editor' "$game_root/scripts/movement/ground_movement_controls.gd" \
  || ! rg -q '0\.70, 1\.40' "$game_root/scripts/movement/ground_movement_controls.gd" \
  || ! rg -q '0\.30, 1\.00' "$game_root/scripts/movement/ground_movement_controls.gd" \
  || ! rg -q '_touch_overlap_ratio' "$game_root/scripts/movement/ground_movement_controls.gd"; then
	echo "CP-401 control layout editor, size, opacity, or overlap validation is missing." >&2
	exit 1
fi

if ! rg -q 'class_name ControlLayoutStore' "$game_root/scripts/input/control_layout_store.gd" \
  || ! rg -q 'SCHEMA_VERSION := 1' "$game_root/scripts/input/control_layout_store.gd" \
  || ! rg -q 'PRESET_LEFT' "$game_root/scripts/movement/ground_movement_controls.gd" \
  || ! rg -q 'layout_store\.save_layout' "$game_root/scripts/movement/ground_movement_controls.gd"; then
	echo "CP-402 presets, versioned JSON storage, or element recovery is missing." >&2
	exit 1
fi

if ! rg -q 'func start_layout_test' "$game_root/scripts/movement/ground_movement_controls.gd" \
  || ! rg -q 'COMBAT_RESUME_COUNTDOWN' "$game_root/scripts/movement/ground_movement_controls.gd" \
  || ! rg -q 'layout_test_started' "$game_root/scripts/movement/ground_movement_sandbox.gd"; then
	echo "CP-403 ten-second layout test or combat resume countdown is missing." >&2
	exit 1
fi

if ! rg -q 'class_name CombatFeedbackController' "$game_root/scripts/combat/combat_feedback_controller.gd" \
  || ! rg -q 'const BASIC_HIT_STOP_S := 0\.04' "$game_root/scripts/combat/combat_feedback_controller.gd" \
  || ! rg -q 'const STRONG_HIT_STOP_S := 0\.07' "$game_root/scripts/combat/combat_feedback_controller.gd" \
  || ! rg -q 'feedback_settings_changed' "$game_root/scripts/movement/ground_movement_controls.gd"; then
	echo "CP-404 hit feedback controller or independent settings are missing." >&2
	exit 1
fi

if ! rg -q 'uses_color_and_shape.*true' "$game_root/scripts/combat/prototype_enemy.gd" \
  || ! rg -q 'uses_color_and_shape.*true' "$game_root/scripts/combat/elite_armored_boar.gd" \
  || rg -q 'Engine\.time_scale' "$game_root/scripts/combat/combat_feedback_controller.gd"; then
	echo "CP-404 warning shape fallback or judgment-independent feedback is missing." >&2
	exit 1
fi

if ! rg -q 'class_name LocalTestRecorder' "$game_root/scripts/telemetry/local_test_recorder.gd" \
  || ! rg -q 'local_test_records\.jsonl' "$game_root/scripts/telemetry/local_test_recorder.gd" \
  || ! rg -q 'file\.flush\(\)' "$game_root/scripts/telemetry/local_test_recorder.gd" \
  || ! rg -q 'test_records_clear_requested' "$game_root/scripts/movement/ground_movement_controls.gd"; then
	echo "CP-405 JSON Lines recorder, immediate flush, or settings reset is missing." >&2
	exit 1
fi

if ! rg -q 'permissions/internet=false' "$game_root/export_presets.cfg" \
  || rg -q 'HTTPRequest|HTTPClient|WebSocketPeer' "$game_root/scripts/telemetry/local_test_recorder.gd"; then
	echo "CP-405 local records must not require network permission or network clients." >&2
	exit 1
fi

if ! rg -q 'ANDROID_VALIDATION_TARGET_RUNS := 10' "$game_root/scripts/movement/ground_movement_controls.gd" \
  || ! rg -q 'ANDROID_VALIDATION_TARGET_SESSION_S := 20\.0 \* 60\.0' "$game_root/scripts/movement/ground_movement_controls.gd" \
  || ! rg -q 'background_resume_pass' "$game_root/scripts/movement/ground_movement_controls.gd" \
  || ! rg -q '2400\.0, 1080\.0' "$game_root/tests/cp406_runtime_test.gd"; then
	echo "CP-406 Android validation counters or two-aspect safe-area check is missing." >&2
	exit 1
fi

if ! rg -q 'class_name PlayerCommand' "$game_root/scripts/input/player_command.gd"; then
  echo "PlayerCommand type is missing." >&2
  exit 1
fi

if ! rg -q 'class_name PlayerCommandBuffer' "$game_root/scripts/input/player_command_buffer.gd"; then
  echo "PlayerCommandBuffer type is missing." >&2
  exit 1
fi

if ! rg -q 'name="Android Debug APK"' "$game_root/export_presets.cfg"; then
  echo "Android debug export preset is missing." >&2
  exit 1
fi

# APK는 요청 시에만 수동으로 만든다. PR/main의 자동 검증은 별도 워크플로다.
apk_events="$(awk '/^on:$/ {in_events=1; next} in_events && /^[^ ]/ {in_events=0} in_events && /^  [a-z_]+:/ {print $1}' "$project_root/.github/workflows/build-android-apk.yml")"
if [[ "$apk_events" != "workflow_dispatch:" ]] \
  || ! rg -q '^  pull_request:' "$project_root/.github/workflows/check-godot-project.yml" \
  || ! rg -q '^  push:' "$project_root/.github/workflows/check-godot-project.yml" \
  || rg -q 'godot-export|setup-android|sdkmanager|export-debug|upload-artifact' "$project_root/.github/workflows/check-godot-project.yml"; then
  echo "Delivery policy requires manual APK builds and automatic Godot checks without APK export." >&2
  exit 1
fi

godot_command=""
if command -v godot >/dev/null 2>&1; then
  godot_command="godot"
elif command -v godot4 >/dev/null 2>&1; then
  godot_command="godot4"
fi

if [[ -n "$godot_command" ]]; then
  check_data_dir="$(mktemp -d)"
  export XDG_DATA_HOME="$check_data_dir/data"
  export XDG_CONFIG_HOME="$check_data_dir/config"
  mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME"
  trap 'rm -rf "$check_data_dir"' EXIT
  # Godot import는 스크립트 오류에도 종료 코드 0을 반환할 수 있다.
  # Preserve checkpoint dependencies while sharding isolated content matrices.
  declare -A check_script_shards=()
  checked_godot() {
    local check_timeout="$1"
    shift
    check_timeout="$(( ${check_timeout%s} * check_timeout_multiplier ))s"
    local prior="" argument="" script="" assigned="" shard_key="" user_args_started="false"
    local -a user_args=()
    for argument in "$@"; do
      if [[ "$prior" == "--script" ]]; then script="$argument"; fi
      if [[ "$user_args_started" == "true" ]]; then user_args+=("$argument"); fi
      if [[ "$argument" == "--" ]]; then user_args_started="true"; fi
      prior="$argument"
    done
    shard_key="$script"
    # These content matrices isolate saves by every argument after phase.
    # Keep seed/resume/next together, distribute independent content cases.
    case "$script" in
      res://tests/gp344_runtime_test.gd|res://tests/gp354_runtime_test.gd|res://tests/gp364_runtime_test.gd|res://tests/gp374_runtime_test.gd|res://tests/gp375_384_runtime_test.gd|res://tests/gp385_414_runtime_test.gd|res://tests/gp415_444_runtime_test.gd|res://tests/gp448_477_runtime_test.gd|res://tests/gp478_507_runtime_test.gd|res://tests/gp515_544_runtime_test.gd|res://tests/gp618_667_runtime_test.gd|res://tests/gp668_717_runtime_test.gd|res://tests/gp961_1010_runtime_test.gd)
        shard_key="$script|${user_args[*]:1}"
        ;;
    esac
    if [[ -n "$script" ]] && (( check_shard_count > 1 )); then
      assigned="${check_script_shards[$shard_key]:-}"
      if [[ -z "$assigned" ]]; then
        assigned="$(printf '%s' "$shard_key" | cksum | awk '{print $1}')"
        assigned=$(( assigned % check_shard_count ))
        check_script_shards[$shard_key]="$assigned"
      fi
      if (( assigned != check_shard_index )); then return 0; fi
    fi
    echo "Godot check: ${script:-project import} ${user_args[*]} (timeout $check_timeout)"
    if timeout "$check_timeout" "$godot_command" "$@" 2>&1 | tee "$check_data_dir/runtime.log"; then
      :
    else
      local check_status="$?"
      echo "Godot check failed (exit $check_status): ${script:-project import} ${user_args[*]} (timeout $check_timeout)" >&2
      return "$check_status"
    fi
    if rg -q '^ERROR:|SCRIPT ERROR:|Parse Error:' "$check_data_dir/runtime.log"; then
      echo "Godot runtime or script error detected." >&2
      return 1
    fi
  }
  checked_android_export_pack() {
    local check_timeout="$1"
    shift
    check_timeout="$(( ${check_timeout%s} * check_timeout_multiplier ))s"
    timeout "$check_timeout" "$godot_command" "$@" 2>&1 | tee "$check_data_dir/runtime.log"
    if rg -q '^SCRIPT ERROR:|^Parse Error:' "$check_data_dir/runtime.log" \
      || { rg '^ERROR:' "$check_data_dir/runtime.log" | rg -v 'resources still in use at exit' >/dev/null; }; then
      echo "Godot Android resource export reported an unexpected script or runtime error." >&2
      return 1
    fi
  }
  checked_godot 120s --headless --path "$game_root" --import
  checked_godot 120s --headless --path "$game_root" --script res://tests/gp1031_1050_presentation_runtime_test.gd -- catalog
  for shop_art_phase in seed resume next; do
    checked_godot 120s --headless --path "$game_root" --script res://tests/gp1031_1050_presentation_runtime_test.gd -- "$shop_art_phase" skill_sword_0 roan
  done
  checked_godot 120s --headless --path "$game_root" --script res://tests/gp1031_1050_presentation_runtime_test.gd -- rules heal lumi
  checked_godot 120s --headless --path "$game_root" --script res://tests/gp1011_1030_presentation_runtime_test.gd -- catalog
  for board_phase in seed resume next; do
    checked_godot 120s --headless --path "$game_root" --script res://tests/gp1011_1030_presentation_runtime_test.gd -- "$board_phase" pair_sword_bow_practice roan
  done
  checked_godot 90s --headless --path "$game_root" --script res://tests/gp961_1010_runtime_test.gd -- catalog
  for partner_hero in roan lumi; do
    partner_families=(sword bow fist staff polearm shield)
    for (( partner_first=0; partner_first<6; partner_first++ )); do
      for (( partner_second=partner_first+1; partner_second<6; partner_second++ )); do
        for partner_style in practice arsenal; do
          for partner_phase in seed resume next; do
            checked_godot 120s --headless --path "$game_root" --script res://tests/gp961_1010_runtime_test.gd -- "$partner_phase" "pair_${partner_families[$partner_first]}_${partner_families[$partner_second]}_${partner_style}" "$partner_hero"
          done
        done
      done
    done
    for supply_trial in meal_clock potion_workshop recovery_plan battle_ready all_services maintained_journey varied_basket supply_investment long_investment stock_explorer two_upgrades skill_basket; do
      for partner_phase in seed resume next; do
        checked_godot 120s --headless --path "$game_root" --script res://tests/gp961_1010_runtime_test.gd -- "$partner_phase" "supply_trial_${supply_trial}" "$partner_hero"
      done
    done
  done
  for map_phase in flow physics journey story; do
    checked_godot 120s --headless --path "$game_root" --script res://tests/windmill_meadow_runtime_test.gd -- "$map_phase"
  done
  checked_godot 120s --headless --path "$game_root" --script res://tests/gp821_830_art_runtime_test.gd
  checked_godot 120s --headless --path "$game_root" --script res://tests/gp831_840_animation_runtime_test.gd
  checked_godot 120s --headless --path "$game_root" --script res://tests/gp891_910_presentation_runtime_test.gd -- runtime
  for gear_phase in catalog combat acquisition seed resume ui; do
    checked_godot 120s --headless --path "$game_root" --script res://tests/gp911_960_runtime_test.gd -- "$gear_phase"
  done
  for link_phase in catalog combat acquisition seed resume ui; do
    checked_godot 120s --headless --path "$game_root" --script res://tests/gp841_890_runtime_test.gd -- "$link_phase"
  done
  for status_phase in seed resume combat ui acquisition; do
    checked_godot 120s --headless --path "$game_root" --script res://tests/gp770_820_runtime_test.gd -- "$status_phase"
  done
  for traits_hero in roan lumi; do
    for traits_phase in seed resume combat; do
      checked_godot 90s --headless --path "$game_root" --script res://tests/hero_traits_runtime_test.gd -- "$traits_phase" "$traits_hero"
    done
  done
  for stats_phase in seed resume combat; do
    checked_godot 90s --headless --path "$game_root" --script res://tests/hero_stats_runtime_test.gd -- "$stats_phase"
  done
  checked_godot 90s --headless --path "$game_root" \
    --script res://tests/gp668_717_runtime_test.gd -- catalog
  for tactics_hero in roan lumi; do
    for tactics_family in sword bow fist staff polearm shield; do
      for tactics_style in ground_skill air_basic barrier_basic barrier_skill calm_rhythm crisis_rhythm; do
        for tactics_phase in seed resume next; do
          checked_godot 90s --headless --path "$game_root" \
            --script res://tests/gp668_717_runtime_test.gd -- "$tactics_phase" "${tactics_family}_tactic_${tactics_style}" "$tactics_hero"
        done
      done
    done
    for tactics_support in evasive_barrier_master restorative_barrier_master victory_resilience_master orb_bloom_master time_attunement_master nimble_master; do
      for tactics_phase in seed resume next; do
        checked_godot 90s --headless --path "$game_root" \
          --script res://tests/gp668_717_runtime_test.gd -- "$tactics_phase" "$tactics_support" "$tactics_hero"
      done
    done
  done
  checked_godot 90s --headless --path "$game_root" \
    --script res://tests/run_preparation_runtime_test.gd
  checked_godot 45s --headless --path "$game_root" \
    --script res://tests/start_screen_runtime_test.gd
  checked_godot 90s --headless --path "$game_root" \
    --script res://tests/gp608_617_art_runtime_test.gd
  for research_phase in catalog seed resume live ui; do
    checked_godot 120s --headless --path "$game_root" \
      --script res://tests/gp718_767_runtime_test.gd -- "$research_phase"
  done
  for achievement_phase in catalog seed resume live failure corrupt; do
    checked_godot 120s --headless --path "$game_root" \
      --script res://tests/gp548_597_runtime_test.gd -- "$achievement_phase"
  done
  checked_godot 45s --headless --path "$game_root" \
    --script res://tests/character_art_runtime_test.gd
  checked_godot 45s --headless --path "$game_root" \
    --script res://tests/hero_movement_animation_runtime_test.gd
  checked_godot 45s --headless --path "$game_root" \
    --script res://tests/hero_combat_animation_runtime_test.gd
  checked_godot 45s --headless --path "$game_root" \
    --script res://tests/enemy_art_runtime_test.gd
  checked_godot 45s --headless --path "$game_root" \
    --script res://tests/clockwork_knight_art_runtime_test.gd
  checked_godot 45s --headless --path "$game_root" \
    --script res://tests/guardian_art_runtime_test.gd
  checked_godot 45s --headless --path "$game_root" \
    --script res://tests/sera_art_runtime_test.gd
  checked_godot 45s --headless --path "$game_root" \
    --script res://tests/heart_art_runtime_test.gd
  checked_godot 60s --headless --path "$game_root" \
    --script res://tests/regional_roster_runtime_test.gd
  # Scene conversion may report an error with exit code zero. Check the actual
  # Android resource pack and boot its converted scenes, without building an APK.
  checked_android_export_pack 120s --headless --path "$game_root" \
    --export-pack "Android Debug APK" "$check_data_dir/android-resources.pck"
  test -s "$check_data_dir/android-resources.pck"
  checked_godot 45s --headless \
    --main-pack "$check_data_dir/android-resources.pck" --quit-after 30
  echo "Android resource export and packed game boot: OK"
  checked_godot 60s --headless --path "$game_root" \
    --script res://tests/gp618_667_runtime_test.gd -- catalog
  for trial_hero in roan lumi; do
    for trial_family in sword bow fist staff polearm shield; do
      for trial_style in precision growth equipment discipline journey expert; do
        for trial_phase in seed resume next; do
          checked_godot 90s --headless --path "$game_root" \
            --script res://tests/gp618_667_runtime_test.gd -- "$trial_phase" "trial_${trial_family}_${trial_style}" "$trial_hero"
        done
      done
    done
    for trial_route in meadow wind forest ruins festival city_gate; do
      for trial_phase in seed resume next; do
        checked_godot 90s --headless --path "$game_root" \
          --script res://tests/gp618_667_runtime_test.gd -- "$trial_phase" "trial_route_${trial_route}" "$trial_hero"
      done
    done
  done
  for mastery_hero in roan lumi; do
    for mastery_family in sword bow fist staff polearm shield; do
      for mastery_style in ground air focus resolve rhythm; do
        for mastery_phase in seed resume next; do
          checked_godot 60s --headless --path "$game_root" \
            --script res://tests/gp515_544_runtime_test.gd -- "$mastery_phase" "${mastery_family}_mastery_${mastery_style}" "$mastery_hero"
        done
      done
    done
  done
  for dawn_hero in roan lumi; do
    for dawn_skill in sword_dawn_chain sword_retreat_wave sword_orbit sword_high_arc sword_returning_edge bow_prism_fan bow_starlit_rain bow_swallow_trio bow_drill bow_retreat_fan fist_dawn_barrage fist_retreat_palm fist_spiral fist_sky_chain fist_twin_pulse staff_crystal_fan staff_meteor_pair staff_dawn_pulse staff_storm_seal staff_retreat_lance polearm_horizon polearm_dawn_orbit polearm_skyward polearm_back_cross polearm_comet shield_dawn_chain shield_retreat_bash shield_orbit shield_twin_wave shield_cross_march; do
      for dawn_phase in seed resume next combat; do
        checked_godot 60s --headless --path "$game_root" \
          --script res://tests/gp478_507_runtime_test.gd -- "$dawn_phase" "$dawn_skill" "$dawn_hero" "$([[ "$dawn_hero" == roan ]] && echo 1 || echo -1)"
      done
    done
  done
  checked_godot 45s --headless --path "$game_root" \
    --script res://tests/gp478_507_runtime_test.gd -- catalog sword_dawn_chain roan 1
  for task_hero in roan lumi; do
    for task_id in first_steps steady_steps long_road toward_dawn meadow_scout wind_scout forest_scout ruins_scout festival_scout gate_scout damage_500 damage_1500 damage_3000 skills_10 skills_30 sword_training bow_training fist_training staff_training polearm_training shield_training level_5 level_10 first_job advanced_job rare_pair hero_pair shop_regular fresh_stock prepared_traveler; do
      for task_phase in seed resume next; do
        checked_godot 90s --headless --path "$game_root" \
          --script res://tests/gp448_477_runtime_test.gd -- "$task_phase" "$task_id" "$task_hero"
      done
    done
    for task_phase in catalog legacy spend; do
      checked_godot 90s --headless --path "$game_root" \
        --script res://tests/gp448_477_runtime_test.gd -- "$task_phase" first_steps "$task_hero"
    done
  done
  for supply_hero in roan lumi; do
    for supply_family in sword bow fist staff polearm shield; do
      for supply_item in "weapon_$supply_family" "skill_${supply_family}_0" "skill_${supply_family}_1"; do
        for supply_phase in seed resume next; do
          checked_godot 90s --headless --path "$game_root" \
            --script res://tests/gp415_444_runtime_test.gd -- "$supply_phase" "$supply_item" "$supply_hero" "$supply_family"
        done
      done
      for supply_phase in rules legacy progression; do
        checked_godot 90s --headless --path "$game_root" \
          --script res://tests/gp415_444_runtime_test.gd -- "$supply_phase" heal "$supply_hero" "$supply_family"
      done
    done
    for supply_item in heal potion gauge refresh; do
      for supply_phase in seed resume next; do
        checked_godot 90s --headless --path "$game_root" \
          --script res://tests/gp415_444_runtime_test.gd -- "$supply_phase" "$supply_item" "$supply_hero" sword
      done
    done
  done
  checked_godot 90s --headless --path "$game_root" \
    --script res://tests/gp385_414_runtime_test.gd -- catalog striker_fist roan 1
  for content_item in striker_fist weaver_fist balanced_fist striker_staff weaver_staff balanced_staff striker_polearm weaver_polearm balanced_polearm striker_shield weaver_shield balanced_shield fist_pendant fist_sigil staff_pendant staff_sigil polearm_pendant polearm_sigil shield_pendant shield_sigil fist_basic_training fist_skill_training staff_basic_training staff_skill_training polearm_basic_training polearm_skill_training shield_basic_training shield_skill_training polearm_cross shield_wave; do
    for content_hero in roan lumi; do
      for content_phase in seed resume finish; do
        checked_godot 90s --headless --path "$game_root" \
          --script res://tests/gp385_414_runtime_test.gd -- "$content_phase" "$content_item" "$content_hero" 1
      done
    done
  done
  for new_skill in polearm_cross shield_wave; do
    for content_hero in roan lumi; do
      for content_direction in 1 -1; do
        checked_godot 90s --headless --path "$game_root" \
          --script res://tests/gp385_414_runtime_test.gd -- combat "$new_skill" "$content_hero" "$content_direction"
      done
    done
  done
  for expansion_skill in fist_rising fist_cross fist_advancing staff_ember_volley staff_frost_ring staff_thunder_echo polearm_windwheel polearm_retreat shield_rush shield_ring; do
    for expansion_hero in roan lumi; do
      for expansion_direction in 1 -1; do
        for expansion_phase in combat seed resume; do
          checked_godot 90s --headless --path "$game_root" \
            --script res://tests/gp375_384_runtime_test.gd -- "$expansion_phase" "$expansion_skill" "$expansion_hero" "$expansion_direction"
        done
      done
    done
  done
  for new_family in staff polearm shield; do
    case "$new_family" in
      staff) new_script=gp354_runtime_test; new_jobs="flame_sage frost_mage"; new_base=flame_sage ;;
      polearm) new_script=gp364_runtime_test; new_jobs="sky_monk time_wanderer"; new_base=sky_monk ;;
      shield) new_script=gp374_runtime_test; new_jobs="fortress_knight rune_guardian"; new_base=fortress_knight ;;
    esac
    for new_character in roan lumi; do
      for new_backup in sword bow fist staff polearm shield; do
        if [[ "$new_backup" == "$new_family" ]]; then continue; fi
        checked_godot 90s --headless --path "$game_root" \
          --script "res://tests/$new_script.gd" -- combat "$new_character" "$new_base" "$new_backup"
        for new_job in $new_jobs; do
          for new_phase in seed resume legacy late; do
            checked_godot 90s --headless --path "$game_root" \
              --script "res://tests/$new_script.gd" -- "$new_phase" "$new_character" "$new_job" "$new_backup"
          done
        done
      done
    done
  done
  for martial_character in roan lumi; do
    for martial_backup in sword bow; do
      checked_godot 90s --headless --path "$game_root" \
        --script res://tests/gp344_runtime_test.gd -- combat "$martial_character" thunder_fist "$martial_backup"
      for martial_job in thunder_fist phantom_dancer; do
        for martial_phase in seed resume legacy late; do
          checked_godot 90s --headless --path "$game_root" \
            --script res://tests/gp344_runtime_test.gd -- "$martial_phase" "$martial_character" "$martial_job" "$martial_backup"
        done
      done
    done
  done
  for advanced_job in dragon_knight breaker storm_archer forest_warden; do
    for evolution_character in roan lumi; do
      for evolution_phase in seed resume legacy late; do
        checked_godot 90s --headless --path "$game_root" \
          --script res://tests/gp334_runtime_test.gd -- "$evolution_phase" "$evolution_character" "$advanced_job"
      done
    done
  done
  for advanced_job in breaker storm_archer forest_warden; do
    for evolution_character in roan lumi; do
      for evolution_phase in seed resume legacy late; do
        checked_godot 90s --headless --path "$game_root" \
          --script res://tests/gp329_runtime_test.gd -- "$evolution_phase" "$evolution_character" "$advanced_job"
      done
    done
  done
  for evolution_character in roan lumi; do
    for evolution_phase in seed resume legacy late; do
      checked_godot 90s --headless --path "$game_root" \
        --script res://tests/gp327_runtime_test.gd -- "$evolution_phase" "$evolution_character"
    done
  done
  checked_godot 60s --headless --path "$game_root" \
    --script res://tests/gp326_constraint_runtime_test.gd
  for expedition_character in roan lumi; do
    for expedition_weapon in sword bow; do
      for expedition_phase in preview seed resume legacy validate healing story-off layout clear-seed clear-resume finish; do
        checked_godot 60s --headless --path "$game_root" \
          --script res://tests/gp326_runtime_test.gd -- "$expedition_phase" "$expedition_character" "$expedition_weapon"
      done
    done
  done
  checked_godot 45s --headless --path "$game_root" \
    --script res://tests/gp325_boss_runtime_test.gd
  for expedition_character in roan lumi; do
    for expedition_weapon in sword bow; do
      for expedition_phase in preview seed resume legacy validate healing story-off layout clear-seed clear-resume finish; do
        checked_godot 60s --headless --path "$game_root" \
          --script res://tests/gp325_runtime_test.gd -- "$expedition_phase" "$expedition_character" "$expedition_weapon"
      done
    done
  done
  checked_godot 60s --headless --path "$game_root" \
    --script res://tests/gp324_enemy_runtime_test.gd
  for expedition_character in roan lumi; do
    for expedition_weapon in sword bow; do
      for expedition_phase in preview seed resume legacy validate healing story-off layout clear-seed clear-resume finish; do
        checked_godot 80s --headless --path "$game_root" \
          --script res://tests/gp324_runtime_test.gd -- "$expedition_phase" "$expedition_character" "$expedition_weapon"
      done
    done
  done
  for expedition_character in roan lumi; do
    for expedition_weapon in sword bow; do
      for expedition_phase in preview migration seed resume validate legacy healing layout story-off clear-fault clear-seed clear-resume finish; do
        checked_godot 80s --headless --path "$game_root" \
          --script res://tests/gp323_runtime_test.gd -- "$expedition_phase" "$expedition_character" "$expedition_weapon"
      done
    done
  done
  for expedition_character in roan lumi; do
    for expedition_weapon in sword bow; do
      for expedition_phase in preview seed resume validate legacy layout story-off finish; do
        checked_godot 80s --headless --path "$game_root" \
          --script res://tests/gp322_runtime_test.gd -- "$expedition_phase" "$expedition_character" "$expedition_weapon"
      done
    done
  done
  for ritual_character in roan lumi; do
    for ritual_weapon in sword bow; do
      ritual_choice=destroy
      if [[ "$ritual_character/$ritual_weapon" == roan/sword || "$ritual_character/$ritual_weapon" == lumi/bow ]]; then ritual_choice=rescue; fi
      for ritual_ending in return liberation dawn; do
        for ritual_phase in seed resume finish; do
          checked_godot 80s --headless --path "$game_root" \
            --script res://tests/gp321_runtime_test.gd -- "$ritual_phase" "$ritual_character" "$ritual_weapon" "$ritual_choice" "$ritual_ending"
        done
      done
    done
  done
  for ritual_phase in selection-fault ending-fault journal-fault secret-fault validate layout legacy first story-off fault-seed fault-resume; do
    checked_godot 80s --headless --path "$game_root" \
      --script res://tests/gp321_runtime_test.gd -- "$ritual_phase" lumi bow destroy liberation
  done
  for heart_character in roan lumi; do
    for heart_weapon in sword bow; do
      for heart_choice in rescue destroy; do
        for heart_phase in seed resume defeated finish; do
          checked_godot 60s --headless --path "$game_root" \
            --script res://tests/gp320_runtime_test.gd -- "$heart_phase" "$heart_character" "$heart_weapon" "$heart_choice"
        done
      done
    done
  done
  for heart_choice in rescue destroy; do
    for heart_phase in entry-fault truth-fault victory-fault journal-fault fault-seed fault-resume legacy first validate patterns layout death story-off reward-fault; do
      checked_godot 60s --headless --path "$game_root" \
        --script res://tests/gp320_runtime_test.gd -- "$heart_phase" lumi bow "$heart_choice"
    done
  done
  for truth_character in roan lumi; do
    for truth_weapon in sword bow; do
      for truth_choice in rescue destroy; do
        for truth_phase in seed resume finish; do
          checked_godot 60s --headless --path "$game_root" \
            --script res://tests/gp319_runtime_test.gd -- "$truth_phase" "$truth_character" "$truth_weapon" "$truth_choice"
        done
      done
    done
  done
  for truth_choice in rescue destroy; do
    for truth_phase in checkpoint-fault journal-fault fault-seed fault-resume first-run legacy validate layout story-off standard; do
      checked_godot 60s --headless --path "$game_root" \
        --script res://tests/gp319_runtime_test.gd -- "$truth_phase" lumi bow "$truth_choice"
    done
  done
  for ending_character in roan lumi; do
    for ending_weapon in sword bow; do
      for ending_choice in rescue destroy; do
        for ending_phase in seed resume finish; do
          checked_godot 60s --headless --path "$game_root" \
            --script res://tests/gp318_runtime_test.gd -- "$ending_phase" "$ending_character" "$ending_weapon" "$ending_choice"
        done
      done
    done
  done
  for ending_choice in rescue destroy; do
    for ending_phase in checkpoint-fault journal-fault fault-seed fault-resume validate legacy story-off journal layout; do
      checked_godot 60s --headless --path "$game_root" \
        --script res://tests/gp318_runtime_test.gd -- "$ending_phase" lumi bow "$ending_choice"
    done
  done
  for heart_character in roan lumi; do
    for heart_weapon in sword bow; do
      for heart_choice in rescue destroy; do
        for heart_phase in seed resume finish; do
          checked_godot 60s --headless --path "$game_root" \
            --script res://tests/gp317_runtime_test.gd -- "$heart_phase" "$heart_character" "$heart_weapon" "$heart_choice"
        done
      done
    done
  done
  for heart_choice in rescue destroy; do
    for heart_phase in checkpoint-fault reward-fault validate legacy story-off layout; do
      checked_godot 60s --headless --path "$game_root" \
        --script res://tests/gp317_runtime_test.gd -- "$heart_phase" lumi bow "$heart_choice"
    done
  done
  for legacy_character in roan lumi; do
    for legacy_weapon in sword bow; do
      for legacy_choice in rescue destroy; do
        for legacy_phase in seed resume finish; do
          checked_godot 60s --headless --path "$game_root" \
            --script res://tests/gp316_runtime_test.gd -- "$legacy_phase" "$legacy_character" "$legacy_weapon" "$legacy_choice"
        done
      done
    done
  done
  for legacy_choice in rescue destroy; do
    for legacy_phase in fault validate previous-choice; do
      checked_godot 60s --headless --path "$game_root" \
        --script res://tests/gp316_runtime_test.gd -- "$legacy_phase" lumi bow "$legacy_choice"
    done
  done
  for legacy_phase in journal modes; do
    checked_godot 60s --headless --path "$game_root" \
      --script res://tests/gp316_runtime_test.gd -- "$legacy_phase" roan sword rescue
  done
  for sera_character in roan lumi; do
    for sera_weapon in sword bow; do
      for sera_phase in seed resume defeated finish; do
        checked_godot 60s --headless --path "$game_root" \
          --script res://tests/gp315_runtime_test.gd -- "$sera_phase" "$sera_character" "$sera_weapon"
      done
    done
  done
  for sera_weapon in sword bow; do
    for sera_pattern in dash wave ring; do
      checked_godot 60s --headless --path "$game_root" \
        --script res://tests/gp315_runtime_test.gd -- "patterns-$sera_pattern" roan "$sera_weapon"
    done
  done
  for sera_phase in fault-choice fault-story fault-record; do
    checked_godot 60s --headless --path "$game_root" \
      --script res://tests/gp315_runtime_test.gd -- "$sera_phase" lumi bow
  done
  for sera_phase in legacy-gate legacy-final legacy-standard; do
    checked_godot 60s --headless --path "$game_root" \
      --script res://tests/gp315_runtime_test.gd -- "$sera_phase" roan sword
  done
  for sera_phase in flows story-off validation layout; do
    checked_godot 60s --headless --path "$game_root" \
      --script res://tests/gp315_runtime_test.gd -- "$sera_phase" lumi sword
  done
  for reunion_character in roan lumi; do
    for reunion_weapon in sword bow; do
      for reunion_phase in seed pending acknowledged finish; do
        checked_godot 60s --headless --path "$game_root" \
          --script res://tests/gp314_runtime_test.gd -- "$reunion_phase" "$reunion_character" "$reunion_weapon"
      done
    done
  done
  for reunion_character in roan lumi; do
    for reunion_phase in fragment-fault checkpoint-fault; do
      checked_godot 60s --headless --path "$game_root" \
        --script res://tests/gp314_runtime_test.gd -- "$reunion_phase" "$reunion_character" bow
    done
  done
  for reunion_phase in legacy-pending legacy-seen rules layout; do
    checked_godot 60s --headless --path "$game_root" \
      --script res://tests/gp314_runtime_test.gd -- "$reunion_phase" lumi sword
  done
  for companion_character in roan lumi; do
    for companion_weapon in sword bow; do
      for companion_choice in rescue destroy; do
        for companion_phase in seed resume finish; do
          checked_godot 60s --headless --path "$game_root" \
            --script res://tests/gp313_runtime_test.gd -- "$companion_phase" "$companion_character" "$companion_weapon" "$companion_choice"
        done
      done
    done
  done
  for companion_choice in rescue destroy; do
    for companion_phase in fault validate; do
      checked_godot 60s --headless --path "$game_root" \
        --script res://tests/gp313_runtime_test.gd -- "$companion_phase" lumi bow "$companion_choice"
    done
  done
  for companion_phase in journal modes; do
    checked_godot 60s --headless --path "$game_root" \
      --script res://tests/gp313_runtime_test.gd -- "$companion_phase" lumi bow rescue
  done
  for decision_character in roan lumi; do
    for decision_weapon in sword bow; do
      for guardian_decision in rescue destroy; do
        for decision_phase in seed resume selected finish; do
          checked_godot 60s --headless --path "$game_root" \
            --script res://tests/gp312_runtime_test.gd -- "$decision_phase" "$decision_character" "$decision_weapon" "$guardian_decision"
        done
      done
    done
  done
  for guardian_decision in rescue destroy; do
    for decision_phase in fault legacy validate effects flows; do
      checked_godot 60s --headless --path "$game_root" \
        --script res://tests/gp312_runtime_test.gd -- "$decision_phase" lumi bow "$guardian_decision"
    done
  done
  for guardian_character in roan lumi; do
    for guardian_weapon in sword bow; do
      for guardian_phase in seed resume finish combat flows regress; do
        checked_godot 60s --headless --path "$game_root" \
          --script res://tests/gp311_runtime_test.gd -- "$guardian_phase" "$guardian_character" "$guardian_weapon"
      done
    done
  done
  for core_character in roan lumi; do
    for core_weapon in sword bow; do
      for core_phase in seed resume finish cross combat flows; do
        checked_godot 60s --headless --path "$game_root" \
          --script res://tests/gp310_runtime_test.gd -- "$core_phase" "$core_character" "$core_weapon"
      done
    done
  done
  for gate_character in roan lumi; do
    for gate_weapon in sword bow; do
      for gate_phase in seed resume cross fault flows; do
        checked_godot 60s --headless --path "$game_root" \
          --script res://tests/gp309_runtime_test.gd -- "$gate_phase" "$gate_character" "$gate_weapon"
      done
    done
  done
  for second_route in wind forest ruins festival; do
    for second_phase in seed resume motion cross flows hazard; do
      checked_godot 60s --headless --path "$game_root" \
        --script res://tests/gp308_runtime_test.gd -- "$second_phase" "$second_route"
    done
  done
  for protagonist in roan lumi; do
    for starting_weapon in sword bow; do
      checked_godot 45s --headless --path "$game_root" --script res://tests/gp307_runtime_test.gd -- seed "$protagonist" "$starting_weapon"
      for completed_stage in {1..9}; do
        checked_godot 45s --headless --path "$game_root" --script res://tests/gp307_runtime_test.gd -- resume "$protagonist" "$starting_weapon" "$completed_stage"
      done
      for journey_phase in finish records; do
        checked_godot 45s --headless --path "$game_root" --script res://tests/gp307_runtime_test.gd -- "$journey_phase" "$protagonist" "$starting_weapon"
      done
    done
  done
  for journey_phase in preview orders validate fault legacy flows; do
    checked_godot 45s --headless --path "$game_root" --script res://tests/gp307_runtime_test.gd -- "$journey_phase" roan sword
  done
  for protagonist in roan lumi; do
    for starting_weapon in sword bow; do
      for story_phase in seed resume1 resume2 finish records; do
        checked_godot 45s --headless --path "$game_root" --script res://tests/gp277_306_runtime_test.gd -- "$story_phase" "$protagonist" "$starting_weapon"
      done
    done
    checked_godot 45s --headless --path "$game_root" --script res://tests/gp277_306_runtime_test.gd -- preview "$protagonist" sword
  done
  for story_phase in fragment-fault checkpoint-fault rewind-fault chronicle-seed chronicle-resume death validate corruption legacy-seed legacy reader orders jobs; do
    checked_godot 45s --headless --path "$game_root" --script res://tests/gp277_306_runtime_test.gd -- "$story_phase" roan sword
  done
  for protagonist in roan lumi; do
    for starting_weapon in sword bow; do
      for character_phase in seed resume finish; do
        checked_godot 45s --headless --path "$game_root" --script res://tests/gp267_276_runtime_test.gd -- "$character_phase" "$protagonist" "$starting_weapon"
      done
    done
    for character_phase in preview fault; do
      checked_godot 45s --headless --path "$game_root" --script res://tests/gp267_276_runtime_test.gd -- "$character_phase" "$protagonist" sword
    done
  done
  for starting_weapon in sword bow; do
    checked_godot 45s --headless --path "$game_root" --script res://tests/gp267_276_runtime_test.gd -- balance lumi "$starting_weapon"
  done
  for character_phase in legacy-seed legacy validate records; do
    checked_godot 45s --headless --path "$game_root" --script res://tests/gp267_276_runtime_test.gd -- "$character_phase" lumi sword
  done
  for starting_weapon in sword bow; do
    for region_phase in seed resume2 resume3 resume4 boss finish legacy-seed legacy preview; do
      checked_godot 45s --headless --path "$game_root" --script res://tests/gp257_266_runtime_test.gd -- "$region_phase" "$starting_weapon"
    done
  done
  for region_phase in orders validate fault flows; do
    checked_godot 45s --headless --path "$game_root" --script res://tests/gp257_266_runtime_test.gd -- "$region_phase" sword
  done
  for starting_weapon in sword bow; do
    for festival_phase in seed resume finish legacy-seed legacy paging; do
      checked_godot 45s --headless --path "$game_root" --script res://tests/gp247_256_runtime_test.gd -- "$festival_phase" "$starting_weapon"
    done
  done
  for festival_phase in fault-seed fault-resume; do
    checked_godot 45s --headless --path "$game_root" --script res://tests/gp247_256_runtime_test.gd -- "$festival_phase" sword
  done
  for terrain_phase in motion cross pause; do
    checked_godot 45s --headless --path "$game_root" --script res://tests/gp248_249_runtime_test.gd -- "$terrain_phase"
  done
  for enemy in soldier turret; do
    for direction in 1 -1; do
      checked_godot 45s --headless --path "$game_root" --script res://tests/gp250_252_runtime_test.gd -- "$enemy" "$direction"
    done
  done
  checked_godot 45s --headless --path "$game_root" --script res://tests/gp250_252_runtime_test.gd -- flows
  for starting_weapon in sword bow; do
    for ruins_phase in seed resume finish legacy-seed legacy paging; do
      checked_godot 45s --headless --path "$game_root" --script res://tests/gp237_246_runtime_test.gd -- "$ruins_phase" "$starting_weapon"
    done
  done
  for ruins_phase in fault-seed fault-resume; do
    checked_godot 45s --headless --path "$game_root" --script res://tests/gp237_246_runtime_test.gd -- "$ruins_phase" sword
  done
  for terrain_phase in motion cross pause; do
    checked_godot 45s --headless --path "$game_root" --script res://tests/gp239_runtime_test.gd -- "$terrain_phase"
  done
  for trap_phase in damage evade flows; do
    checked_godot 45s --headless --path "$game_root" --script res://tests/gp240_242_runtime_test.gd -- "$trap_phase"
  done
  for direction in 1 -1; do
    checked_godot 45s --headless --path "$game_root" --script res://tests/gp240_242_runtime_test.gd -- doll "$direction"
  done
  for starting_weapon in sword bow; do
    for forest_phase in seed resume finish legacy-seed legacy; do
      checked_godot 45s --headless --path "$game_root" --script res://tests/gp227_236_runtime_test.gd -- "$forest_phase" "$starting_weapon"
    done
  done
  for forest_phase in fault-seed fault-resume; do
    checked_godot 45s --headless --path "$game_root" --script res://tests/gp227_236_runtime_test.gd -- "$forest_phase" sword
  done
  for enemy in slime seed wind; do
    for direction in 1 -1; do
      checked_godot 45s --headless --path "$game_root" --script res://tests/gp230_232_runtime_test.gd -- "$enemy" "$direction"
    done
  done
  checked_godot 45s --headless --path "$game_root" --script res://tests/gp230_232_runtime_test.gd -- flows
  for terrain_phase in motion cross pause; do
    checked_godot 45s --headless --path "$game_root" --script res://tests/gp228_229_runtime_test.gd -- "$terrain_phase"
  done
  checked_godot 45s --headless --path "$game_root" --script res://tests/gp217_226_runtime_test.gd -- catalog
  for design in duelist_sword hunter_bow runic_sword spell_bow fencer_sword precision_bow forged_sword sturdy_bow balanced_sword balanced_bow; do
    for equipment_phase in seed resume finish; do
      checked_godot 45s --headless --path "$game_root" --script res://tests/gp217_226_runtime_test.gd -- "$equipment_phase" "$design"
    done
  done
  for growth_phase in seed resume finish legacy-seed legacy combat; do
    checked_godot 45s --headless --path "$game_root" --script res://tests/gp207_212_runtime_test.gd -- "$growth_phase"
  done
  for relic_id in iron spark sword bow bell prism dial lens; do
    for relic_phase in seed resume finish combat; do
      checked_godot 45s --headless --path "$game_root" --script res://tests/gp199_206_runtime_test.gd -- "$relic_id" "$relic_phase"
    done
  done
  for pair in 0 1 2 3 4 5; do
    for skill_phase in seed resume finish legacy combat-right combat-left flows; do
      checked_godot 45s --headless --path "$game_root" --script res://tests/gp187_198_runtime_test.gd -- "$skill_phase" "$pair"
    done
  done
  for profile in 0 1 2 3; do
    for ultimate_phase in seed resume finish; do
      checked_godot 45s --headless --path "$game_root" --script res://tests/gp213_216_runtime_test.gd -- "$ultimate_phase" "$profile"
    done
  done
  for synergy_phase in seed resume finish legacy-seed legacy combat; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp177_180_runtime_test.gd -- "$synergy_phase"
  done
  for relic_id in charm feather necklace whistle; do
    for relic_phase in seed resume finish combat; do
      checked_godot 45s --headless --path "$game_root" \
        --script res://tests/gp181_184_runtime_test.gd -- "$relic_id" "$relic_phase"
    done
  done
  for skill_phase in seed resume finish legacy combat-right combat-left flows; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp185_186_runtime_test.gd -- "$skill_phase"
  done
  for growth_phase in seed resume finish legacy-seed legacy combat; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp167_170_runtime_test.gd -- "$growth_phase"
  done
  for relic_id in rune compass coin cup; do
    for relic_phase in seed resume finish combat; do
      checked_godot 45s --headless --path "$game_root" \
        --script res://tests/gp171_174_runtime_test.gd -- "$relic_id" "$relic_phase"
    done
  done
  for skill_phase in seed resume finish legacy combat-right combat-left flows; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp175_176_runtime_test.gd -- "$skill_phase"
  done
  for relic_id in seal wind seed duel; do
    for relic_phase in seed resume finish combat; do
      checked_godot 45s --headless --path "$game_root" \
        --script res://tests/gp162_166_runtime_test.gd -- "$relic_id" "$relic_phase"
    done
  done
  for survival_phase in seed resume finish legacy-seed legacy evasion potions victory combined; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp159_161_runtime_test.gd -- "$survival_phase"
  done
  for cross_phase in seed resume finish legacy combat-right combat-left flows; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp158_runtime_test.gd -- "$cross_phase"
  done
  for ricochet_phase in seed resume finish legacy combat-right combat-left flows; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp157_runtime_test.gd -- "$ricochet_phase"
  done
  for collector_boost_phase in seed resume finish legacy-seed legacy combat; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp156_runtime_test.gd -- "$collector_boost_phase"
  done
  for hourglass_phase in seed resume finish legacy-seed legacy combat; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp155_runtime_test.gd -- "$hourglass_phase"
  done
  for orb_vitality_phase in seed resume finish legacy-seed legacy combat; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp154_runtime_test.gd -- "$orb_vitality_phase"
  done
  for magnet_phase in seed resume finish legacy-seed legacy combat; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp153_runtime_test.gd -- "$magnet_phase"
  done
  for history_phase in seed resume finish; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp151_runtime_test.gd -- "$history_phase"
  done
  for ember_phase in seed resume finish legacy-seed legacy combat; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp150_runtime_test.gd -- "$ember_phase"
  done
  for portioned_phase in seed resume finish legacy-seed legacy combat; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp149_runtime_test.gd -- "$portioned_phase"
  done
  for potion_barrier_phase in seed resume finish legacy-seed legacy combat; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp148_runtime_test.gd -- "$potion_barrier_phase"
  done
  for wave_phase in seed resume finish legacy combat-right combat-left flows; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp147_runtime_test.gd -- "$wave_phase"
  done
  for evasive_phase in seed resume finish legacy-seed legacy combat; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp146_runtime_test.gd -- "$evasive_phase"
  done
  for homing_phase in seed resume finish legacy combat-right combat-left flows; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp145_runtime_test.gd -- "$homing_phase"
  done
  for echo_phase in seed resume finish legacy-seed legacy combat; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp144_runtime_test.gd -- "$echo_phase"
  done
  for mobility_phase in seed resume finish legacy combat-sword combat-bow flows; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp143_runtime_test.gd -- "$mobility_phase"
  done
  for victory_recovery_phase in seed resume finish legacy-seed legacy combat; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp142_runtime_test.gd -- "$victory_recovery_phase"
  done
  for run_build_phase in seed resume finish flows; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp141_runtime_test.gd -- "$run_build_phase"
  done
  for mastery_phase in seed-sword resume-sword finish-sword seed-bow resume-bow finish-bow legacy-seed legacy-resume; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp140_runtime_test.gd -- "$mastery_phase"
  done
  for expedition_phase in seed resume boss finish legacy flows; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp139_runtime_test.gd -- "$expedition_phase"
  done
  for collector_phase in seed resume finish legacy combat; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp138_runtime_test.gd -- "$collector_phase"
  done
  for weapon_codex_phase in seed resume finish legacy combinations; do
    # The expanded catalog is traversed at both aspect ratios, repeatedly across
    # save/load states. A successful hosted run already takes over 40 seconds.
    checked_godot 120s --headless --path "$game_root" \
      --script res://tests/gp137_runtime_test.gd -- "$weapon_codex_phase"
  done
  for fortified_phase in seed resume finish legacy combat; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp136_runtime_test.gd -- "$fortified_phase"
  done
  for dew_phase in seed resume finish legacy combat; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp135_runtime_test.gd -- "$dew_phase"
  done
  for precision_phase in seed resume finish legacy combat; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp134_runtime_test.gd -- "$precision_phase"
  done
  for nimble_phase in seed resume finish legacy combat; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp133_runtime_test.gd -- "$nimble_phase"
  done
  for skill_codex_phase in seed resume finish legacy; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp132_runtime_test.gd -- "$skill_codex_phase"
  done
  for pouch_phase in seed resume finish legacy combat; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp131_runtime_test.gd -- "$pouch_phase"
  done
  for relic_codex_phase in seed resume finish legacy; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp130_runtime_test.gd -- "$relic_codex_phase"
  done
  checked_godot 45s --headless --path "$game_root" \
    --script res://tests/cp206_runtime_test.gd
  checked_godot 45s --headless --path "$game_root" \
    --script res://tests/cp301_runtime_test.gd
  checked_godot 45s --headless --path "$game_root" \
    --script res://tests/cp302_runtime_test.gd
  checked_godot 45s --headless --path "$game_root" \
    --script res://tests/cp303_runtime_test.gd
  checked_godot 45s --headless --path "$game_root" \
    --script res://tests/cp304_runtime_test.gd
  checked_godot 45s --headless --path "$game_root" \
    --script res://tests/cp401_runtime_test.gd
  checked_godot 45s --headless --path "$game_root" \
    --script res://tests/cp402_runtime_test.gd
  checked_godot 45s --headless --path "$game_root" \
    --script res://tests/cp403_runtime_test.gd
  checked_godot 45s --headless --path "$game_root" \
    --script res://tests/cp404_runtime_test.gd
  checked_godot 45s --headless --path "$game_root" \
    --script res://tests/cp405_runtime_test.gd
  checked_godot 45s --headless --path "$game_root" \
    --script res://tests/cp406_runtime_test.gd
  checked_godot 45s --headless --path "$game_root" \
    --script res://tests/gp101_runtime_test.gd
  checked_godot 45s --headless --path "$game_root" \
    --script res://tests/gp102_runtime_test.gd
  checked_godot 45s --headless --path "$game_root" \
    --script res://tests/gp103_runtime_test.gd
  checked_godot 45s --headless --path "$game_root" \
    --script res://tests/gp104_runtime_test.gd
  for checkpoint_phase in seed resume finish empty seed-bow resume finish empty; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp105_runtime_test.gd -- "$checkpoint_phase"
  done
  for checkpoint_phase in seed resume corrupt recover empty; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp105_runtime_test.gd -- "$checkpoint_phase"
  done
  for checkpoint_phase in seed death empty seed new empty; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp105_runtime_test.gd -- "$checkpoint_phase"
  done
  checked_godot 45s --headless --path "$game_root" \
    --script res://tests/gp106_runtime_test.gd
  checked_godot 90s --headless --path "$game_root" \
    --script res://tests/gp107_runtime_test.gd
  for reward_phase in seed claim finish legacy-seed legacy-resume; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp108_runtime_test.gd -- "$reward_phase"
  done
  for boss_phase in seed resolve empty resolved-seed resolved-resume empty-resolved; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp109_runtime_test.gd -- "$boss_phase"
  done
  for legacy_phase in reward-seed rescue-start rescue-resume destroy-start destroy-resume; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp110_runtime_test.gd -- "$legacy_phase"
  done
  for memory_phase in legacy-seed guard-start guard-resume echo-start echo-resume; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp111_runtime_test.gd -- "$memory_phase"
  done
  for risk_phase in seed resume finish; do
    checked_godot 90s --headless --path "$game_root" \
      --script res://tests/gp112_runtime_test.gd -- "$risk_phase"
  done
  for blueprint_phase in seed resume finish legacy-resume; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp113_runtime_test.gd -- "$blueprint_phase"
  done
  for village_phase in seed resume finish; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp114_runtime_test.gd -- "$village_phase"
  done
  for skill_phase in seed resume finish legacy-resume combat; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp115_runtime_test.gd -- "$skill_phase"
  done
  for codex_phase in seed resume finish legacy-fail legacy-resume; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp116_runtime_test.gd -- "$codex_phase"
  done
  for potion_phase in seed resume finish legacy-resume; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp117_runtime_test.gd -- "$potion_phase"
  done
  for orb_phase in seed resume; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp118_runtime_test.gd -- "$orb_phase"
  done
  for relic_phase in seed resume spent legacy; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp119_runtime_test.gd -- "$relic_phase"
  done
  for apothecary_phase in seed resume legacy; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp120_runtime_test.gd -- "$apothecary_phase"
  done
  for directional_phase in seed resume finish legacy combat; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp121_runtime_test.gd -- "$directional_phase"
  done
  for atlas_phase in seed resume finish legacy; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp122_runtime_test.gd -- "$atlas_phase"
  done
  for jump_phase in seed resume finish legacy; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp123_runtime_test.gd -- "$jump_phase"
  done
  for absorption_phase in seed resume finish legacy combat; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp124_runtime_test.gd -- "$absorption_phase"
  done
  for branch_phase in seed resume crisis restore legacy combat; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp125_runtime_test.gd -- "$branch_phase"
  done
  for codex_phase in seed resume finish legacy-fail legacy-resume; do
    # The expanded ability codex visits every page at two viewport sizes.
    checked_godot 90s --headless --path "$game_root" \
      --script res://tests/gp126_runtime_test.gd -- "$codex_phase"
  done
  for tactical_phase in seed resume finish legacy combat; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp127_runtime_test.gd -- "$tactical_phase"
  done
  for barrier_phase in seed resume finish legacy combat; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp128_runtime_test.gd -- "$barrier_phase"
  done
  for clock_phase in seed resume finish legacy combat; do
    checked_godot 45s --headless --path "$game_root" \
      --script res://tests/gp129_runtime_test.gd -- "$clock_phase"
  done
  echo "Godot headless project check: OK"
else
  echo "Static project check: OK"
  echo "Godot executable not found; GDScript parse and runtime checks were skipped."
fi
