extends RefCounted

const GameAudioPlayerFactory := preload("res://scripts/audio/game_audio_player_factory.gd")
const BgmMuteState := preload("res://scripts/audio/bgm_mute_state.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")

const PADDLE_HIT_SOUND_PATH := "res://assets/sounds/paddle_hit.wav"
const SERVE_SOUND_PATH := "res://assets/sounds/serve.wav"
const PINGPONG_SERVE_SOUND_PATH := "res://assets/sounds/pong_paddle.wav"
const WALL_HIT_SOUND_PATH := "res://assets/sounds/wall_hit.wav"
const DASH_SOUND_PATH := "res://assets/sounds/dash.wav"
const HALF_DASH_SOUND_PATH := "res://assets/sounds/halfdash.wav"
const DASH_DELAY_SOUND_PATH := "res://assets/sounds/dashdelay.wav"
const DASH_CHARGE_SOUND_PATH := "res://assets/sounds/dashcharge.wav"
const BUST_UP_DASH_SOUND_PATH := "res://assets/sounds/bustup.wav"
const BOOST_CHARGING_SOUND_PATH := "res://assets/sounds/boostcharging.wav"
const SOUL_BURST_DASH_SOUND_PATH := "res://assets/sounds/soulbust.wav"
const DASH_SPIRIT_DELETE_SOUND_PATH := "res://assets/sounds/dashspiritdelete.wav"
const DRIVE_SOUND_PATH := "res://assets/sounds/drive.wav"
const MIKA_DRIVE_VOICE_PATH := "res://assets/sounds/mika_drive.mp3"
const MIKA_DRIVE_VOICE_GAIN_DB := -2.5
const PLASMA_CHARGE_SOUND_PATH := "res://assets/sounds/plazmacharge.wav"
const PLASMA_SHOOT_SOUND_PATH := "res://assets/sounds/plazmashoot.wav"
const PLASMA_SHOCK_SOUND_PATH := "res://assets/sounds/plazmashock.wav"
const PLASMA_CHARGE_GAIN_DB := 0.0
const PLASMA_SHOOT_GAIN_DB := -6.0206
const PLASMA_SHOCK_GAIN_DB := -4.4370
const RECOVERY_SOUND_PATH := "res://assets/sounds/recovery.wav"
const CLEANSE_SOUND_PATH := "res://assets/sounds/cleanse.wav"
const WARP_GATE_SOUND_PATH := "res://assets/sounds/warpgate.wav"
const MAGNUM_GRIP_SOUND_PATH := "res://assets/sounds/magnumgrip.wav"
const SMASHER_WHEEL_SOUND_PATH := "res://assets/sounds/smasherwheel.wav"
const SHIELD_KITING_WIND_UP_SOUND_PATH := "res://assets/sounds/shieldcating1.wav"
const SHIELD_KITING_LAUNCH_SOUND_PATH := "res://assets/sounds/shieldcating2.wav"
const SHIELD_KITING_HIT_SOUND_PATH := "res://assets/sounds/shieldcating3.wav"
const WHIP_SOUND_PATH := "res://assets/sounds/whip_effect.wav"
const FAN_SOUND_PATH := "res://assets/sounds/fan.wav"
const WHIPCRACK_SOUND_PATH := "res://assets/sounds/whipcrack.wav"
const GAKSITAL_FAN_SOUND_POOL_SIZE := 3
const VIPER_JETPACK_SOUND_PATH := "res://assets/sounds/jetpack.wav"
const VIPER_BACKSTEP_SOUND_PATH := "res://assets/sounds/backstep.wav"
const VIPER_SHADOW_KICK_SOUND_PATH := "res://assets/sounds/shadowkick.wav"
const VIPER_DIVE_PREP_SOUND_PATH := "res://assets/sounds/beforedivestrike.wav"
const VIPER_DIVE_STRIKE_SOUND_PATH := "res://assets/sounds/divestrike.wav"
const VIPER_DIVE_PREP_GAIN_DB := -4.4370
const VIPER_DIVE_STRIKE_GAIN_DB := -4.4370
const VIPER_IGNITION_AURA_SOUND_PATH := "res://assets/sounds/beforedivestrike.wav"
const VIPER_IGNITION_AURA_FALLBACK_SOUND_PATH := "res://assets/sounds/backstep.wav"
const VIPER_IGNITION_AURA_GAIN_DB := -3.0980
const VIPER_PHANTOM_SHOW_SOUND_PATH := "res://assets/sounds/bypershow.wav"
const VIPER_PHANTOM_KICK_HIT_SOUND_PATH := "res://assets/sounds/pentomkick.wav"
const VIPER_BLADE_SOUND_PATH := "res://assets/sounds/blade.wav"
const VIPER_BLADE_SPIN_SOUND_PATH := "res://assets/sounds/bladeafter.wav"
const VIPER_VENOM_MOVING_SOUND_PATH := "res://assets/sounds/venommoving.wav"
const VIPER_VENOM_ATTACK_SOUND_PATH := "res://assets/sounds/venomattack.wav"
const VIPER_HWARANG_KICK_SOUND_PATH := "res://assets/sounds/hwarangkick.wav"
const VIPER_KICK_GUARD_KNOCKBACK_SOUND_PATH := "res://assets/sounds/nuckbackball.wav"
const VIPER_DUAL_GLITCH_WINDUP_SOUND_PATH := "res://assets/sounds/dualglitch1.wav"
const VIPER_DUAL_GLITCH_WINDUP_GAIN_DB := -13.5
# 분신이 몸에서 갈라져 분리되는 순간(startup -> spawn) 재생. windup(dualglitch1)은 이때 정지.
const VIPER_DUAL_GLITCH_SPLIT_SOUND_PATH := "res://assets/sounds/dualglitch2.wav"
const VIPER_DUAL_GLITCH_SPLIT_GAIN_DB := 0.0
const CHAOS_SPEAR_WINDUP_SOUND_PATH := "res://assets/sounds/chaosphase1.wav"
const CHAOS_SPEAR_FLYING_SOUND_PATH := "res://assets/sounds/chaosphase2.wav"
const CHAOS_SPEAR_IMPACT_SOUND_PATH := "res://assets/sounds/chaosphase3.wav"
const CHAOS_SPEAR_BLACKHOLE_SOUND_PATH := "res://assets/sounds/gravityaccel.wav"
const COMMANDO_SUPPLY_RADIO_SOUND_PATH := "res://assets/sounds/radio.wav"
const COMMANDO_SUPPLY_AIRCRAFT_SOUND_PATH := "res://assets/sounds/airplane.wav"
const COMMANDO_SUPPLY_AIRCRAFT_GAIN_DB := -3.0980
const COMMANDO_WEAPON_CHANGE_SOUND_PATH := "res://assets/sounds/weapon.wav"
const COMMANDO_WEAPON_CHANGE_GAIN_DB := -5.0
const COMMANDO_SLINGSHOT_FIRE_SOUND_PATH := "res://assets/sounds/shurikenthrow.wav"
const COMMANDO_PISTOL_READY_SOUND_PATH := "res://assets/sounds/gunroad.wav"
const COMMANDO_PISTOL_FIRE_SOUND_PATH := "res://assets/sounds/gunshot.wav"
const COMMANDO_PISTOL_RELOAD_START_SOUND_PATH := "res://assets/sounds/pistolreloadstart.wav"
const COMMANDO_PISTOL_RELOAD_SOUND_PATH := "res://assets/sounds/pistolreload.wav"
const COMMANDO_RELOAD_SOUND_PATH := "res://assets/sounds/reload.wav"
const COMMANDO_AK47_FIRE_SOUND_PATH := "res://assets/sounds/ak47.wav"
const COMMANDO_BAZOOKA_FIRE_SOUND_PATH := "res://assets/sounds/bazukagoing.wav"
const COMMANDO_NET_CAPTURE_SOUND_PATH := "res://assets/sounds/net.wav"
const COMMANDO_NET_CONSTRICT_SOUND_PATH := "res://assets/sounds/netcome.wav"
const COMMANDO_BOWLING_TRAP_INSTALL_SOUND_PATH := "res://assets/sounds/ballingtrapsetup.wav"
const COMMANDO_BOWLING_TRAP_SNAP_SOUND_PATH := "res://assets/sounds/ballingtrapgrap.wav"
const COMMANDO_SUICIDE_DRONE_SOUND_PATH := "res://assets/sounds/drone.wav"
const THOR_SHIELD_OPEN_SOUND_PATH := "res://assets/sounds/umbopen.wav"
const THOR_SHIELD_CLOSE_SOUND_PATH := "res://assets/sounds/umbclose.wav"
const THOR_SHIELD_SWING_SOUND_PATH := "res://assets/sounds/swing.wav"
const THOR_SHIELD_BLOCK_SOUND_PATH := "res://assets/sounds/blocking.wav"
const COMMANDO_SLINGSHOT_FIRE_GAIN_DB := -4.4370
const COMMANDO_PISTOL_READY_GAIN_DB := -3.0980
const COMMANDO_PISTOL_FIRE_GAIN_DB := -6.0206
const COMMANDO_PISTOL_RELOAD_GAIN_DB := -6.0206
const COMMANDO_AK47_FIRE_GAIN_DB := -6.0206
const COMMANDO_AK47_FIRE_POOL_SIZE := 4
const COMMANDO_BAZOOKA_FIRE_GAIN_DB := -4.4370
const COMMANDO_NET_CAPTURE_GAIN_DB := -6.0206
const COMMANDO_NET_CONSTRICT_GAIN_DB := -1.9382
const COMMANDO_BOWLING_TRAP_GAIN_DB := -3.0980
const COMMANDO_SUICIDE_DRONE_GAIN_DB := 0.0
const ITEM_GET_SOUND_PATH := "res://assets/sounds/itemget.wav"
const DRINK_SOUND_PATH := "res://assets/sounds/drink.wav"
const ACTIVE_ITEM_SOUND_PATH := "res://assets/sounds/activeitem.wav"
const TRADE_SOUND_PATH := "res://assets/sounds/trade.wav"
const TRADE_SOUND_GAIN_DB := -4.4370
const BRICK_WALL_DESTROY_SOUND_PATH := "res://assets/sounds/stonebreak2.wav"
const BRICK_WALL_DESTROY_GAIN_DB := -5.0
const TREASURE_HUNT_MINING_SOUND_PATH := "res://assets/sounds/mining.wav"
const ALCHEMY_SOUND_PATH := "res://assets/sounds/alchemy.wav"
const PANDORA_SOUND_PATH := "res://assets/sounds/pandora.wav"
const LUCKY_COIN_SPAWN_SOUND_PATH := "res://assets/sounds/lucky_coin_spawn.wav"
const FOUL_WHISTLE_SOUND_PATH := "res://assets/sounds/foul_whistle.wav"
const MEGINGJORD_SOUND_PATH := "res://assets/sounds/megin.wav"
const LEGENDARY_OPEN_SOUND_PATH := "res://assets/sounds/legendopen.wav"
const ANGEL_BLESSING_ROLL_SOUND_PATH := "res://assets/sounds/angeldice.wav"
const ANGEL_BLESSING_ABSORB_SOUND_PATH := "res://assets/sounds/angeldicewhisp.wav"
const ANGEL_BLESSING_ABSORB_POOL_SIZE := 3
const ANGEL_BLESSING_ROLL_GAIN_DB := 0.0
const ANGEL_BLESSING_ABSORB_GAIN_DB := 0.0
const RESULT_BOX_OPEN_SOUND_PATH := "res://assets/sounds/boxopen.wav"
const DEFEAT_JEWEL_SOUND_PATH := "res://assets/sounds/defeatjewel1.wav"
const DEFEAT_GEM_SHATTER_SOUND_PATH := "res://assets/sounds/defeat_gem_shatter.wav"
const LINGPET_ACQUIRE_CUTIN_SOUND_PATH := "res://assets/sounds/lingpet/lingpet_acquire_ominous_shadow_shimmer_02.wav"
const LINGPET_ACQUIRE_CLICK_DEEP_BASS_SOUND_PATH := "res://assets/sounds/lingpet/lingpet_acquire_click_deep_bass_doom.wav"
const LINGPET_ACQUIRE_CLICK_CRACKLE_SWEEP_SOUND_PATH := "res://assets/sounds/lingpet/lingpet_acquire_click_magic_crackle_sweep.wav"
const LINGPET_LUNABI_CLICK_VOICE_SOUND_PATH := "res://assets/sounds/lingpet/lunabi_click_reaction_voice_v1.mp3"
const LINGPET_VOLTY_CLICK_VOICE_SOUND_PATH := "res://assets/sounds/lingpet/volty_click_reaction_voice_v1.mp3"
const LINGPET_MILKRING_CLICK_VOICE_SOUND_PATH := "res://assets/sounds/lingpet/milkring_click_reaction_voice_v1.mp3"
const LINGPET_RED_DRAGON_CLICK_VOICE_SOUND_PATH := "res://assets/sounds/lingpet/red_dragon_click_reaction_voice_v1.mp3"
const LINGPET_MARIBO_CLICK_VOICE_SOUND_PATH := "res://assets/sounds/lingpet/maribo_click_reaction_voice_v1.mp3"
const LINGPET_RABI_CLICK_VOICE_SOUND_PATH := "res://assets/sounds/lingpet/rabi_click_reaction_voice_v1.mp3"
const LINGPET_LUMION_CLICK_VOICE_SOUND_PATH := "res://assets/sounds/lingpet/lumion_click_reaction_voice_v1.mp3"
const LINGPET_MONKEYRING_CLICK_VOICE_SOUND_PATH := "res://assets/sounds/lingpet/monkeyring_click_reaction_voice_v1.mp3"
const LINGPET_ONIMARU_CLICK_VOICE_SOUND_PATH := "res://assets/sounds/lingpet/onimaru_click_reaction_voice_v1.mp3"
const LINGPET_OROSHA_CLICK_VOICE_SOUND_PATH := "res://assets/sounds/lingpet/orosha_click_reaction_voice_v1.wav"
const LINGPET_KOYORA_CLICK_VOICE_SOUND_PATH := "res://assets/sounds/lingpet/koyora_click_reaction_voice_v1.mp3"
const LINGPET_PUPPET_GRAB_CAST_SOUND_PATH := "res://assets/sounds/lingpet/puppet_grab_tentacle.wav"
const LINGPET_PUPPET_GRAB_PULL_SOUND_PATH := "res://assets/sounds/lingpet/puppet_grab.wav"
const LINGPET_PUPPET_GRAB_KISS_SOUND_PATH := "res://assets/sounds/lingpet/puppet_grab_kissing.wav"
const LINGPET_PUPPET_GRAB_MISS_SOUND_PATH := "res://assets/sounds/lingpet/puppet_grab_tentacle.wav"
const LINGPET_SAND_PRISON_OPEN_SOUND_PATH := "res://assets/sounds/lingpet/rahoset_sand_prison_open.wav"
const LINGPET_WILD_ROAR_SOUND_PATH := "res://assets/sounds/lingpet/monkeyshouting.wav"
# Orosha 별똬리(star_coil) BIND squish: plays while the star coil-snake constricts the
# boss (one-shot at bind start, stopped on release so the wet squish does not trail
# into the roll-away). Source is the ESM "Juicy Wet Squish" foley, re-mastered louder
# (soft-clip makeup gain so its quiet body lifts from ~-30 to ~-21 dBFS RMS) and
# trimmed to ~3.6s so the audible squish lands on the bind window (1.5~3.5s).
const LINGPET_STAR_COIL_BIND_SOUND_PATH := "res://assets/sounds/lingpet/orosha_star_coil_bind.wav"
# Orosha 별똬리(star_coil) MOVE loop: plays while the star coil-snake rolls to the wall,
# climbs, lunges, crosses, and descends (every moving phase). Looping — started once per
# travel and stopped on bind / idle / retire / cancel by the skill.
const LINGPET_STAR_COIL_MOVE_SOUND_PATH := "res://assets/sounds/starmoving.wav"
const LINGPET_RING_DASH_SOUND_PATH := "res://assets/sounds/lingpet/ring_dash_whoosh_strike.wav"
const LINGPET_AFFINITY_LEVEL_UP_SOUND_PATH := "res://assets/sounds/lingpet/affinity_level_up_chime.wav"
const LINGPET_GATLING_TRANSFORM_SOUND_PATH := "res://assets/sounds/tanktransform.wav"
const LINGPET_GATLING_LOOP_SOUND_PATH := "res://assets/sounds/gatling.wav"
const LINGPET_GATLING_FIRE_SOUND_PATH := "res://assets/sounds/smallboyshoot.wav"
const LINGPET_GATLING_HIT_SOUND_PATH := "res://assets/sounds/bullethit.wav"
const LEGENDARY_AFTER_SOUND_PATH := "res://assets/sounds/legendafter.wav"
const LEGENDARY_ENDING_SOUND_PATH := "res://assets/sounds/legendending.wav"
const LINGPET_ACQUIRE_CUTIN_GAIN_DB := 0.0
const LINGPET_ACQUIRE_CLICK_DEEP_BASS_GAIN_DB := -2.0
const LINGPET_ACQUIRE_CLICK_CRACKLE_SWEEP_GAIN_DB := -5.0
const LINGPET_LUNABI_CLICK_VOICE_GAIN_DB := -4.0
const LINGPET_VOLTY_CLICK_VOICE_GAIN_DB := 0.0
const LINGPET_MILKRING_CLICK_VOICE_GAIN_DB := 0.0
const LINGPET_RED_DRAGON_CLICK_VOICE_GAIN_DB := 0.0
const LINGPET_MARIBO_CLICK_VOICE_GAIN_DB := 0.0
const LINGPET_RABI_CLICK_VOICE_GAIN_DB := 0.0
const LINGPET_LUMION_CLICK_VOICE_GAIN_DB := 0.0
const LINGPET_MONKEYRING_CLICK_VOICE_GAIN_DB := 0.0
const LINGPET_ONIMARU_CLICK_VOICE_GAIN_DB := 0.0
const LINGPET_OROSHA_CLICK_VOICE_GAIN_DB := 0.0
const LINGPET_KOYORA_CLICK_VOICE_GAIN_DB := 0.0
const LINGPET_PUPPET_GRAB_CAST_GAIN_DB := -5.0
const LINGPET_PUPPET_GRAB_PULL_GAIN_DB := -5.0
const LINGPET_PUPPET_GRAB_KISS_GAIN_DB := -5.0
const LINGPET_PUPPET_GRAB_MISS_GAIN_DB := -5.0
const LINGPET_SAND_PRISON_OPEN_GAIN_DB := -6.0
const LINGPET_WILD_ROAR_GAIN_DB := -4.0
const LINGPET_STAR_COIL_BIND_GAIN_DB := -2.0
const LINGPET_STAR_COIL_MOVE_GAIN_DB := -6.0
const LINGPET_RING_DASH_GAIN_DB := -5.0
const LINGPET_AFFINITY_LEVEL_UP_GAIN_DB := -4.0
# 링펫알(공명 알)이 공에 맞을 때 재생하는 뼈 부러지는 임팩트 SFX 2종. 매 히트마다
# 둘 중 하나를 랜덤으로 재생(피치 지터)해 연속 히트가 똑같이 들리지 않게 한다.
# mini_spark 패턴과 동일하게 단일 플레이어 + 후보 스트림 배열로 로드한다.
const LINGPET_EGG_HIT_SOUND_PATHS := [
	"res://assets/sounds/lingpet/lingpet_egg_hit_bone_break_1.wav",
	"res://assets/sounds/lingpet/lingpet_egg_hit_bone_break_2.wav",
]
const LINGPET_EGG_HIT_GAIN_DB := -5.0
const LINGPET_GATLING_TRANSFORM_GAIN_DB := -3.0980
const LINGPET_GATLING_LOOP_GAIN_DB := -3.0980
const LINGPET_GATLING_FIRE_GAIN_DB := -16.4782
const LINGPET_GATLING_HIT_GAIN_DB := -13.9794
# Serabi 난쟁이마술 (Dwarf Magic): original PingFighter parity — smallboyshoot on
# cast, smallboyhit on boss hit (downtown/hero_skills.py DwarfMagic).
const LINGPET_DWARF_MAGIC_CAST_SOUND_PATH := "res://assets/sounds/smallboyshoot.wav"
const LINGPET_DWARF_MAGIC_HIT_SOUND_PATH := "res://assets/sounds/smallboyhit.wav"
const LINGPET_DWARF_MAGIC_CAST_GAIN_DB := -4.0
const LINGPET_DWARF_MAGIC_HIT_GAIN_DB := -4.0
# Serabi 중력가속 (Gravity Accel): original PingFighter parity — gravityaccel on
# cast (downtown/hero_skills.py GravityControl, duration field skill, cast cue only).
const LINGPET_GRAVITY_ACCEL_CAST_SOUND_PATH := "res://assets/sounds/gravityaccel.wav"
const LINGPET_GRAVITY_ACCEL_CAST_GAIN_DB := -4.0
const RAGNAROK_SHOT_SOUND_PATH := "res://assets/sounds/ragnarokshot.wav"
const RAGNAROK_BOOM_SOUND_PATH := "res://assets/sounds/ragnarokboom.wav"
const RAGNAROK_SHOCK_SOUND_PATH := "res://assets/sounds/ragnarokshock.wav"
const ELECTRIC_SHOCK_SOUND_PATH := "res://assets/sounds/electricshock.wav"
const ELECTRIC_SHOCK_GAIN_DB := -6.9357
const THUNDER_ORB_SHOT_SOUND_PATH := "res://assets/sounds/thunderbolt.wav"
const THUNDER_ORB_BOOM_SOUND_PATH := "res://assets/sounds/thunderboltboom.wav"
const THUNDER_ORB_SHOT_GAIN_DB := -7.9588
const THUNDER_ORB_BOOM_GAIN_DB := -6.0206
# Parity with original PingFighter SolarBolt (천둥 낙뢰): plays devinethunder.wav,
# the same divine-thunder cue DivineShield's lightning interception uses. Gain
# -6.0206 dB matches the original's pygame volume 0.5.
const SOLAR_BOLT_STRIKE_SOUND_PATH := "res://assets/sounds/devinethunder.wav"
# Lumion Thunder Orb (천둥 뇌구) Lv.3+ mini-spark crackle. Each spark instance plays
# a RANDOM one of these three short zaps (pitch-jittered) so the scattered
# post-stun sparks read audibly distinct. Streams are loaded eagerly at setup via
# _load_audio_stream_candidates and retained in mini_spark_streams (no hot-path
# lazy load), mirroring the mika_*_voice multi-variant pattern.
const MINI_SPARK_SOUND_PATHS := [
	"res://assets/sounds/spark1.wav",
	"res://assets/sounds/spark2.wav",
	"res://assets/sounds/spark3.wav",
]
const MINI_SPARK_GAIN_DB := -11.0
const SOLAR_BOLT_STRIKE_GAIN_DB := -6.0206
const POSEIDON_WAVE_SOUND_PATH := "res://assets/sounds/poseidon.wav"
const POSEIDON_CHARGE_SOUND_PATH := "res://assets/sounds/poseidoncharge.wav"
const TIMEWATCH_SOUND_PATH := "res://assets/sounds/timewatch.wav"
const THROW_BEFORE_SOUND_PATH := "res://assets/sounds/throwbefore.wav"
const THROW_SOUND_PATH := "res://assets/sounds/throw.wav"
const HORN_STRAWBERRY_CHANGE_SOUND_PATH := "res://assets/sounds/strawberrychange.wav"
const HORN_STRAWBERRY_EAT_SOUND_PATH := "res://assets/sounds/strawberryeat.wav"
const HORN_STRAWBERRY_STEM_FIRE_SOUND_PATH := "res://assets/sounds/arrow.wav"
const HORN_STRAWBERRY_STEM_HIT_SOUND_PATH := "res://assets/sounds/bullethit.wav"
const HORN_STRAWBERRY_HORN_CHARGE_SOUND_PATH := "res://assets/sounds/horncharge.wav"
const HORN_STRAWBERRY_FIELD_BUILD_SOUND_PATH := "res://assets/sounds/bonemake3.wav"
const HORN_STRAWBERRY_FIELD_BREAK_SOUND_PATH := "res://assets/sounds/bonebreak.wav"
const HORN_STRAWBERRY_FIELD_BUILD_BREAK_SOUND_PATH := "res://assets/sounds/shurikenhit.wav"
const HORN_STRAWBERRY_BOMB_TRIGGER_SOUND_PATH := "res://assets/sounds/bullethit.wav"
const HORN_STRAWBERRY_CHANGE_GAIN_DB := -3.0980
const HORN_STRAWBERRY_EAT_GAIN_DB := 0.0
const HORN_STRAWBERRY_STEM_FIRE_GAIN_DB := -6.0206
# Python parity: stem hit plays bullethit at 0.3 (pingfighter play_cached_sound), not the
# module's unused 0.4 loader. 20*log10(0.3) = -10.4576.
const HORN_STRAWBERRY_STEM_HIT_GAIN_DB := -10.4576
const HORN_STRAWBERRY_HORN_CHARGE_GAIN_DB := -3.7417
const HORN_STRAWBERRY_FIELD_GAIN_DB := -3.0980
const HORN_STRAWBERRY_FIELD_BUILD_BREAK_GAIN_DB := -10.4576
const HORN_STRAWBERRY_BOMB_TRIGGER_GAIN_DB := -7.9588
const GRENADE_SOUND_PATH := "res://assets/sounds/grenade.wav"
const FLASHBOMB_SOUND_PATH := "res://assets/sounds/flashbomb.wav"
const SMOKEBOMB_SOUND_PATH := "res://assets/sounds/smokebomb.wav"
const DYNAMITE_FUSE_SOUND_PATH := "res://assets/sounds/bombfuse.wav"
const FIREBOMB_SOUND_PATH := "res://assets/sounds/firebomb.wav"
const BOOMERANG_SOUND_PATH := "res://assets/sounds/boomerang.wav"
const BOOMERANG_HIT_SOUND_PATH := "res://assets/sounds/boomeranghit.wav"
const BOOMERANG_BREAK_SOUND_PATH := "res://assets/sounds/bonebreak.wav"
const SHRAPNEL_ARMOR_FIRE_SOUND_PATH := "res://assets/sounds/arrow.wav"
const SHRAPNEL_ARMOR_HIT_SOUND_PATH := "res://assets/sounds/bullethit.wav"
const BANANA_THROW_SOUND_PATH := "res://assets/sounds/throwingbanana.wav"
const BANANA_SLIP_SOUND_PATH := "res://assets/sounds/bananastep.wav"
const SOAP_THROW_SOUND_PATH := "res://assets/sounds/oil.wav"
const SOAP_LAND_SOUND_PATH := "res://assets/sounds/shootoil.wav"
const SOAP_SLIP_SOUND_PATH := "res://assets/sounds/bananastep.wav"
const SPIDER_MINE_WALK_SOUND_PATH := "res://assets/sounds/spiderminewalk.wav"
const SPIDER_MINE_SETUP_SOUND_PATH := "res://assets/sounds/spiderminesetup.wav"
const BOMB_SURPRISE_ATTACH_SOUND_PATH := "res://assets/sounds/boomstart.wav"
const BOMB_SURPRISE_TICK1_SOUND_PATH := "res://assets/sounds/ticking1.wav"
const BOMB_SURPRISE_TICK2_SOUND_PATH := "res://assets/sounds/ticking2.wav"
const BOMB_SURPRISE_URGENT_TICK_SOUND_PATH := "res://assets/sounds/ticking3.wav"
const BOMB_SURPRISE_ATTACH_GAIN_DB := -9.1186
const BOMB_SURPRISE_TRANSFER_GAIN_DB := -10.4576
const BOMB_SURPRISE_URGENT_TICK_GAIN_DB := -6.9357
const BOMB_SURPRISE_EXPLOSION_GAIN_DB := -1.9382
const POWER_SMASH_SOUND_PATH := "res://assets/sounds/power_smash.wav"
const MIKA_POWER_SMASHING_VOICE_PATHS := [
	"res://assets/sounds/voice/mika_power_smashing_cutin_v1.mp3",
	"res://assets/sounds/voice/mika_power_smashing_cutin_v2.mp3",
	"res://assets/sounds/voice/mika_power_smashing_cutin_v3.mp3",
	"res://assets/sounds/voice/mika_power_smashing_cutin_v4.mp3",
]
const MIKA_GHOST_SMASHING_VOICE_PATHS := [
	"res://assets/sounds/voice/mika_ghost_smashing_cutin_v1.mp3",
	"res://assets/sounds/voice/mika_ghost_smashing_cutin_v2.wav",
	"res://assets/sounds/voice/mika_ghost_smashing_cutin_v3.mp3",
	"res://assets/sounds/voice/mika_ghost_smashing_cutin_v4.wav",
]
const MIKA_POWER_SMASHING_VOICE_GAIN_DB := -6.0
const MIKA_GHOST_SMASHING_VOICE_GAIN_DB := -4.5
const POWER_SMASH_LAUNCH_SOUND_PATH := "res://assets/sounds/power_smash_launch.wav"
const ROUND_SET_SOUND_PATH := "res://assets/sounds/roundset.wav"
const BALL_SPAWN_INTRO_SOUND_PATH := "res://assets/sounds/stagestart_godot_short.wav"
const STAGE_LANDING_ZOOM_INTRO_SOUND_PATH := "res://assets/sounds/stage_landing_zoom_doom.wav"
const BALLOON_POP_SOUND_PATH := "res://assets/sounds/balloonboom.wav"
const STAGE1_BALLOON_DOOR_SOUND_PATH := "res://assets/sounds/stage1door.wav"
const STAGE1_BALLOON_MACHINE_SOUND_PATH := "res://assets/sounds/stage1muchine.wav"
const STAR_COLLECT_SOUND_PATH := "res://assets/sounds/star.wav"
const STAGE2_HYDRO_SOUND_PATH := "res://assets/sounds/hydro.wav"
const STAGE2_STONEBREAK_SOUND_PATH := "res://assets/sounds/stonebreak2.wav"
const STAGE2_ROCKHIT_SOUND_PATH := "res://assets/sounds/rockhit.wav"
const STAGE2_ROCK_SPAWN_SOUND_PATH := "res://assets/sounds/rock_spawn.wav"
const STAGE2_QUAKE_SOUND_PATH := "res://assets/sounds/quake_sound.wav"
const STAGE2_BOSS_CRY_SOUND_PATH := "res://assets/sounds/cry.wav"
const STAGE2_SPEED_DEFENSE_START_SOUND_PATH := "res://assets/sounds/speed_defense_start.wav"
const STAGE2_SPEED_DEFENSE_HIT_SOUND_PATH := "res://assets/sounds/defense_hit.wav"
const STAGE2_SPEED_DEFENSE_BLOCK_SOUND_PATH := "res://assets/sounds/blocking.wav"
const STAGE3_TAIL_SOUND_PATH := "res://assets/sounds/stage3tail.wav"
const STAGE3_PSYCHOBALL_SOUND_PATH := "res://assets/sounds/psychoball.wav"
const STAGE3_DOLLCURSE_SOUND_PATH := "res://assets/sounds/dollcurse.wav"
const STAGE3_TEARS_SOUND_PATH := "res://assets/sounds/tears.wav"
const STAGE3_CHEST_LAND_SOUND_PATH := "res://assets/sounds/bonemake.wav"
const STAGE3_CURSE_EXPLODE_SOUND_PATH := "res://assets/sounds/weakexplosion.wav"
const STAGE3_KUROMI_AWAKE_SOUND_PATH := "res://assets/sounds/kuromiawake.wav"
const STAGE3_KUROMI_STONEBREAK_SOUND_PATH := "res://assets/sounds/stonebreak_large.wav"
const STAGE3_KUROMI_TONGUE_SOUND_PATH := "res://assets/sounds/kuromitongue.wav"
const STAGE3_KUROMI_SWALLOW_SOUND_PATH := "res://assets/sounds/kuromiswallow.wav"
const STAGE3_KUROMI_SPIT_SOUND_PATH := "res://assets/sounds/kuromispit.wav"
const LINGPET_GHOST_SUMMON_SOUND_PATH := "res://assets/sounds/bencyghost.wav"
const LINGPET_GHOST_SUMMON_OUT_SOUND_PATH := "res://assets/sounds/bencyghostout.wav"
# Nekuring Skeleton Archer (네크로 해골궁수) original PingFighter SFX, ported 1:1 from
# downtown/hero_skills.py SkeletonArcher. dB values mirror the original pygame
# set_volume() (0.6 -> -4.4, 0.3 -> -10.5, 0.7 -> -3.1; played at native pitch).
const LINGPET_SKELETON_ARCHER_SUMMON_SOUND_PATH := "res://assets/sounds/bonemake2.wav"
const LINGPET_SKELETON_ARCHER_DEATH_SOUND_PATH := "res://assets/sounds/skulldead.wav"
const LINGPET_SKELETON_ARCHER_ARROW_FIRE_SOUND_PATH := "res://assets/sounds/arrow.wav"
const LINGPET_SKELETON_ARCHER_ARROW_HIT_SOUND_PATH := "res://assets/sounds/bullethit.wav"
const LINGPET_BONE_BARRIER_BUILD_SOUND_PATH := "res://assets/sounds/bonemake3.wav"
const LINGPET_BONE_BARRIER_BREAK_SOUND_PATH := "res://assets/sounds/bonebreak.wav"
const LINGPET_BONE_BARRIER_BUILD_BREAK_SOUND_PATH := "res://assets/sounds/shurikenhit.wav"
const STAGE4_MOON_SHOOT_SOUND_PATH := "res://assets/sounds/stage4moonshoot.wav"
const STAGE4_FRAGMENT_SHOOT_SOUND_PATH := "res://assets/sounds/stage4moonshoot2.wav"
const STAGE4_TEMPLE_HIT_SOUND_PATH := "res://assets/sounds/stage4hitting.wav"
const STAGE4_BIRDKILL_SOUND_PATH := "res://assets/sounds/birdkill.wav"
const STAGE4_MAGNETIC_SOUND_PATH := "res://assets/sounds/magnetic.wav"
const STAGE4_MEDITATION_SOUND_PATH := "res://assets/sounds/ponkmeditation.wav"
const STAGE4_MEDITATION_AFTER_SOUND_PATH := "res://assets/sounds/meditationafter.wav"
const STAGE5_HONGRYUN_FIREBALL_SOUND_PATH := "res://assets/sounds/stage5_hongryun_fireball.wav"
const STAGE5_HONGRYUN_CHARGE_SOUND_PATH := "res://assets/sounds/stage5_hongryun_charge.wav"
const STAGE5_HONGRYUN_SHOOT_SOUND_PATH := "res://assets/sounds/stage5_hongryun_shoot.wav"
const STAGE6_TETRISER_BREAK_SOUND_PATH := "res://assets/sounds/stage6_tetriser_break.wav"
const STAGE6_TETRISER_WALL_SOUND_PATH := "res://assets/sounds/stage6_tetriser_wall.wav"
const STAGE6_TETRISER_SUPER_ROAR_SOUND_PATH := "res://assets/sounds/stage6_tetriser_super_roar.wav"
const STAGE6_TETRISER_BIG_SOUND_PATH := "res://assets/sounds/stage6_tetriser_big.wav"
const STAGE6_TETRISER_SHIELD_SOUND_PATH := "res://assets/sounds/stage6_tetriser_shield.wav"
const STAGE6_TETRISER_LASER_SOUND_PATH := "res://assets/sounds/stage6_tetriser_laser.wav"
const STAGE7_AKAMU_SHURIKEN_SHOOT_SOUND_PATH := "res://assets/sounds/stage7_akamu_shuriken_shoot.wav"
const STAGE7_AKAMU_SHURIKEN_HIT_SOUND_PATH := "res://assets/sounds/stage7_akamu_shuriken_hit.wav"
const STAGE7_AKAMU_CLOUD_SOUND_PATH := "res://assets/sounds/stage7_akamu_cloud.wav"
const STAGE7_AKAMU_AURA_BLOCK_SOUND_PATH := "res://assets/sounds/stage7_akamu_aura_block.wav"
const STAGE7_AKAMU_CLONE_SPAWN_SOUND_PATH := "res://assets/sounds/stage7_akamu_clone_spawn.wav"
const STAGE7_AKAMU_CLONE_OUT_SOUND_PATH := "res://assets/sounds/stage7_akamu_clone_out.wav"
const STAGE5_HONGRYUN_HURT_SOUND_PATHS := [
	"res://assets/sounds/stage5_hongryun_hurt_1.wav",
	"res://assets/sounds/stage5_hongryun_hurt_2.wav",
	"res://assets/sounds/stage5_hongryun_hurt_3.wav",
]
const LEAF_SHIELD_SOUND_PATH := "res://assets/sounds/leaf.wav"
# 트램펄린(trampoline) 액티브 아이템이 공을 위로 튕겨내는(launch) 순간 재생하는 "보잉" 큐.
const TRAMPOLINE_BOUNCE_SOUND_PATH := "res://assets/sounds/trampoline_bounce.wav"
const TRAMPOLINE_BOUNCE_GAIN_DB := -4.0
const STAGE1_BGM_PATH := "res://assets/bgm/stage1bgm.mp3"
const STAGE1_ALT_BGM_PATH := "res://assets/bgm/stage1bgm2.ogg"
const STAGE1_ALT2_BGM_PATH := "res://assets/bgm/stage1bgm3.ogg"
const STAGE2_BGM_PATH := "res://assets/bgm/stage2bgm.ogg"
const STAGE2_ALT_BGM_PATH := "res://assets/bgm/stage2bgm2.mp3"
const STAGE3_BGM_PATH := "res://assets/bgm/stage3bgm.ogg"
const STAGE4_BGM_PATH := "res://assets/bgm/stage4bgm.ogg"
const STAGE4_PHASE2_BGM_PATH := "res://assets/bgm/stage4bgm-phase2.mp3"
const STAGE5_BGM_PATH := "res://assets/bgm/stage5_hongryun_bgm.ogg"
const STAGE6_BGM_PATH := "res://assets/bgm/stage6_tetriser_bgm.ogg"
const STAGE7_BGM_PATH := "res://assets/bgm/stage7_akamu_bgm.ogg"
const PADDLE_HIT_SOUND_COOLDOWN := 0.06
const WALL_HIT_SOUND_COOLDOWN := 0.035
const SCOREBOARD_SOUND_VOLUME_DB := -8.0
const UI_MOVE_SOUND_PATH := "res://assets/sounds/ui_move.wav"
const UI_CONFIRM_SOUND_PATH := "res://assets/sounds/ui_confirm.wav"
const UI_BACK_SOUND_PATH := "res://assets/sounds/ui_back.wav"
# 퍽 선택화면에서 퍽을 확정(선택)했을 때 재생하는 마법 보상 확인음. 일반 퍽 픽에 쓰인다
# (액티브 언락 퍽은 오브로 날아가는 비행 연출 사운드를 유지).
const UI_PERK_SELECT_SOUND_PATH := "res://assets/sounds/ui_perk_select.wav"
const UI_MOVE_GAIN_DB := -9.0
const UI_CONFIRM_GAIN_DB := -7.0
const UI_BACK_GAIN_DB := -8.0
const UI_PERK_SELECT_GAIN_DB := 0.0
const DEFAULT_BGM_VOLUME := 0.4
const DEFAULT_SFX_VOLUME := 0.7
const STAGE1_BGM_GAIN := 0.75
const STAGE2_BGM_GAIN := 1.0
const STAGE3_BGM_GAIN := 0.9
const STAGE4_BGM_GAIN := 0.9
const STAGE5_BGM_GAIN := 0.9
const STAGE6_BGM_GAIN := 0.9
const STAGE7_BGM_GAIN := 0.9
const STAGE1_BGM_NAMES := ["stage1", "stage1_alt", "stage1_alt2"]
const STAGE2_BGM_NAMES := ["stage2", "stage2_alt"]
const BGM_BUS_NAME := "BGM"
const SFX_BUS_NAME := "SFX"
const SFX_PAN_PADDLE_BUS_NAME := "SFXPanPaddle"
const SFX_PAN_WALL_BUS_NAME := "SFXPanWall"
const AUDIO_SETUP_STEP_COUNT := 7
const BGM_SETUP_STEP_COUNT := 12
const PLAYFIELD_LEFT_X := 0.0
const PLAYFIELD_RIGHT_X := 760.0
const PLAYFIELD_CENTER_X := 380.0
const HIT_PAN_STRENGTH := 0.6

var owner_node: Node
var player_factory: Object = GameAudioPlayerFactory.new()
var paddle_sound_cooldown := 0.0
var wall_sound_cooldown := 0.0
var current_bgm_name := ""
var primed_bgm_volumes: Dictionary = {}
var bgm_volume := DEFAULT_BGM_VOLUME
var sfx_volume := DEFAULT_SFX_VOLUME
var audio_bus_volumes_adopted := false
var bgm_muted := false
var muted_bgm_name := ""
var ui_move_sfx: AudioStreamPlayer
var ui_confirm_sfx: AudioStreamPlayer
var ui_back_sfx: AudioStreamPlayer
var ui_perk_select_sfx: AudioStreamPlayer
var paddle_hit_sfx: AudioStreamPlayer
var serve_sfx: AudioStreamPlayer
var pingpong_serve_sfx: AudioStreamPlayer
var wall_hit_sfx: AudioStreamPlayer
var dash_sfx: AudioStreamPlayer
var half_dash_sfx: AudioStreamPlayer
var dash_delay_sfx: AudioStreamPlayer
var dash_charge_sfx: AudioStreamPlayer
var bust_up_dash_sfx: AudioStreamPlayer
var boost_charging_sfx: AudioStreamPlayer
var soul_burst_dash_sfx: AudioStreamPlayer
var dash_spirit_delete_sfx: AudioStreamPlayer
var drive_sfx: AudioStreamPlayer
var mika_drive_voice_sfx: AudioStreamPlayer
var plasma_charge_sfx: AudioStreamPlayer
var plasma_shoot_sfx: AudioStreamPlayer
var plasma_shock_sfx: AudioStreamPlayer
var recovery_sfx: AudioStreamPlayer
var cleanse_sfx: AudioStreamPlayer
var warp_gate_sfx: AudioStreamPlayer
var magnum_grip_sfx: AudioStreamPlayer
var smasher_wheel_sfx: AudioStreamPlayer
var shield_kiting_wind_up_sfx: AudioStreamPlayer
var shield_kiting_launch_sfx: AudioStreamPlayer
var shield_kiting_hit_sfx: AudioStreamPlayer
var whip_sfx: AudioStreamPlayer
var gaksital_fan_sfx: AudioStreamPlayer
var gaksital_fan_sfx_layers: Array = []
var gaksital_fan_sfx_cursor := 0
var whipcrack_sfx: AudioStreamPlayer
var thor_shield_open_sfx: AudioStreamPlayer
var thor_shield_close_sfx: AudioStreamPlayer
var thor_shield_swing_sfx: AudioStreamPlayer
var thor_shield_block_sfx: AudioStreamPlayer
var viper_jetpack_sfx: AudioStreamPlayer
var viper_backstep_sfx: AudioStreamPlayer
var viper_shadow_kick_sfx: AudioStreamPlayer
var viper_marshal_kick_sfx: AudioStreamPlayer
var viper_dive_prep_sfx: AudioStreamPlayer
var viper_dive_strike_sfx: AudioStreamPlayer
var viper_ignition_aura_sfx: AudioStreamPlayer
var viper_ignition_aura_fallback_sfx: AudioStreamPlayer
var viper_phantom_show_sfx: AudioStreamPlayer
var viper_phantom_kick_hit_sfx: AudioStreamPlayer
var viper_blade_sfx: AudioStreamPlayer
var viper_blade_spin_sfx: AudioStreamPlayer
var viper_venom_moving_sfx: AudioStreamPlayer
var viper_venom_attack_sfx: AudioStreamPlayer
var viper_hwarang_kick_sfx: AudioStreamPlayer
var viper_kick_guard_knockback_sfx: AudioStreamPlayer
var viper_dual_glitch_windup_sfx: AudioStreamPlayer
var viper_dual_glitch_split_sfx: AudioStreamPlayer
var chaos_spear_windup_sfx: AudioStreamPlayer
var chaos_spear_flying_sfx: AudioStreamPlayer
var chaos_spear_impact_sfx: AudioStreamPlayer
var chaos_spear_blackhole_sfx: AudioStreamPlayer
var commando_supply_radio_sfx: AudioStreamPlayer
var commando_supply_radio_loop_sfx: AudioStreamPlayer
var commando_supply_aircraft_sfx: AudioStreamPlayer
var commando_weapon_change_sfx: AudioStreamPlayer
var commando_fire_support_radio_sfx: AudioStreamPlayer
var commando_fire_support_aircraft_sfx: AudioStreamPlayer
var commando_slingshot_fire_sfx: AudioStreamPlayer
var commando_pistol_ready_sfx: AudioStreamPlayer
var commando_pistol_fire_sfx: AudioStreamPlayer
var commando_pistol_reload_start_sfx: AudioStreamPlayer
var commando_pistol_reload_sfx: AudioStreamPlayer
var commando_reload_sfx: AudioStreamPlayer
var commando_ak47_fire_sfx: AudioStreamPlayer
var commando_ak47_fire_sfx_layers: Array = []
var commando_ak47_fire_sfx_cursor := 0
var commando_bazooka_fire_sfx: AudioStreamPlayer
var commando_net_capture_sfx: AudioStreamPlayer
var commando_net_constrict_sfx: AudioStreamPlayer
var commando_bowling_trap_install_sfx: AudioStreamPlayer
var commando_bowling_trap_snap_sfx: AudioStreamPlayer
var commando_suicide_drone_sfx: AudioStreamPlayer
var item_get_sfx: AudioStreamPlayer
var drink_sfx: AudioStreamPlayer
var active_item_sfx: AudioStreamPlayer
var trade_sfx: AudioStreamPlayer
var brick_wall_destroy_sfx: AudioStreamPlayer
var treasure_hunt_mining_sfx: AudioStreamPlayer
var alchemy_sfx: AudioStreamPlayer
var pandora_sfx: AudioStreamPlayer
var lucky_coin_spawn_sfx: AudioStreamPlayer
var foul_whistle_sfx: AudioStreamPlayer
var megingjord_sfx: AudioStreamPlayer
var legendary_open_sfx: AudioStreamPlayer
var angel_blessing_roll_sfx: AudioStreamPlayer
var angel_blessing_absorb_sfx: AudioStreamPlayer
var angel_blessing_absorb_sfx_layers: Array = []
var angel_blessing_absorb_sfx_cursor := 0
var result_box_open_sfx: AudioStreamPlayer
var defeat_jewel_sfx: AudioStreamPlayer
var defeat_gem_shatter_sfx: AudioStreamPlayer
var lingpet_acquire_cutin_sfx: AudioStreamPlayer
var lingpet_acquire_click_deep_bass_sfx: AudioStreamPlayer
var lingpet_acquire_click_crackle_sweep_sfx: AudioStreamPlayer
var lingpet_lunabi_click_voice_sfx: AudioStreamPlayer
var lingpet_volty_click_voice_sfx: AudioStreamPlayer
var lingpet_milkring_click_voice_sfx: AudioStreamPlayer
var lingpet_red_dragon_click_voice_sfx: AudioStreamPlayer
var lingpet_maribo_click_voice_sfx: AudioStreamPlayer
var lingpet_rabi_click_voice_sfx: AudioStreamPlayer
var lingpet_lumion_click_voice_sfx: AudioStreamPlayer
var lingpet_monkeyring_click_voice_sfx: AudioStreamPlayer
var lingpet_onimaru_click_voice_sfx: AudioStreamPlayer
var lingpet_orosha_click_voice_sfx: AudioStreamPlayer
var lingpet_koyora_click_voice_sfx: AudioStreamPlayer
var lingpet_puppet_grab_cast_sfx: AudioStreamPlayer
var lingpet_puppet_grab_pull_sfx: AudioStreamPlayer
var lingpet_puppet_grab_kiss_sfx: AudioStreamPlayer
var lingpet_puppet_grab_miss_sfx: AudioStreamPlayer
var lingpet_sand_prison_open_sfx: AudioStreamPlayer
var lingpet_wild_roar_sfx: AudioStreamPlayer
var lingpet_star_coil_bind_sfx: AudioStreamPlayer
var lingpet_star_coil_move_sfx: AudioStreamPlayer
var lingpet_ring_dash_sfx: AudioStreamPlayer
var lingpet_affinity_level_up_sfx: AudioStreamPlayer
var lingpet_egg_hit_sfx: AudioStreamPlayer
var lingpet_egg_hit_streams: Array[AudioStream] = []
var lingpet_gatling_transform_sfx: AudioStreamPlayer
var lingpet_gatling_loop_sfx: AudioStreamPlayer
var lingpet_gatling_fire_sfx: AudioStreamPlayer
var lingpet_gatling_hit_sfx: AudioStreamPlayer
var lingpet_dwarf_magic_cast_sfx: AudioStreamPlayer
var lingpet_dwarf_magic_hit_sfx: AudioStreamPlayer
var lingpet_gravity_accel_cast_sfx: AudioStreamPlayer
var legendary_after_sfx: AudioStreamPlayer
var legendary_ending_sfx: AudioStreamPlayer
var ragnarok_shot_sfx: AudioStreamPlayer
var ragnarok_boom_sfx: AudioStreamPlayer
var ragnarok_shock_sfx: AudioStreamPlayer
var electric_shock_sfx: AudioStreamPlayer
var thunder_orb_shot_sfx: AudioStreamPlayer
var thunder_orb_boom_sfx: AudioStreamPlayer
var solar_bolt_strike_sfx: AudioStreamPlayer
var mini_spark_sfx: AudioStreamPlayer
var mini_spark_streams: Array[AudioStream] = []
var poseidon_wave_sfx: AudioStreamPlayer
var poseidon_charge_sfx: AudioStreamPlayer
var timewatch_sfx: AudioStreamPlayer
var throw_before_sfx: AudioStreamPlayer
var throw_sfx: AudioStreamPlayer
var horn_strawberry_change_sfx: AudioStreamPlayer
var horn_strawberry_eat_sfx: AudioStreamPlayer
var horn_strawberry_stem_fire_sfx: AudioStreamPlayer
var horn_strawberry_stem_hit_sfx: AudioStreamPlayer
var horn_strawberry_horn_charge_sfx: AudioStreamPlayer
var horn_strawberry_field_build_sfx: AudioStreamPlayer
var horn_strawberry_field_break_sfx: AudioStreamPlayer
var horn_strawberry_field_build_break_sfx: AudioStreamPlayer
var horn_strawberry_bomb_trigger_sfx: AudioStreamPlayer
var grenade_sfx: AudioStreamPlayer
var flashbomb_sfx: AudioStreamPlayer
var smokebomb_sfx: AudioStreamPlayer
var firebomb_sfx: AudioStreamPlayer
var boomerang_sfx: AudioStreamPlayer
var boomerang_hit_sfx: AudioStreamPlayer
var boomerang_break_sfx: AudioStreamPlayer
var shrapnel_armor_fire_sfx: AudioStreamPlayer
var shrapnel_armor_hit_sfx: AudioStreamPlayer
var banana_throw_sfx: AudioStreamPlayer
var banana_slip_sfx: AudioStreamPlayer
var soap_throw_sfx: AudioStreamPlayer
var soap_land_sfx: AudioStreamPlayer
var soap_slip_sfx: AudioStreamPlayer
var spider_mine_walk_sfx: AudioStreamPlayer
var spider_mine_setup_sfx: AudioStreamPlayer
var bomb_surprise_attach_sfx: AudioStreamPlayer
var bomb_surprise_transfer_sfx: AudioStreamPlayer
var bomb_surprise_tick1_sfx: AudioStreamPlayer
var bomb_surprise_tick2_sfx: AudioStreamPlayer
var bomb_surprise_urgent_tick_sfx: AudioStreamPlayer
var bomb_surprise_explosion_sfx: AudioStreamPlayer
var bomb_surprise_self_explosion_sfx: AudioStreamPlayer
var power_smash_sfx: AudioStreamPlayer
var mika_power_smashing_voice_sfx: AudioStreamPlayer
var mika_power_smashing_voice_streams: Array[AudioStream] = []
var mika_ghost_smashing_voice_sfx: AudioStreamPlayer
var mika_ghost_smashing_voice_streams: Array[AudioStream] = []
var power_smash_launch_sfx: AudioStreamPlayer
var round_set_sfx: AudioStreamPlayer
var ball_spawn_intro_sfx: AudioStreamPlayer
var stage_landing_zoom_intro_sfx: AudioStreamPlayer
var balloon_pop_sfx: AudioStreamPlayer
var stage1_balloon_door_sfx: AudioStreamPlayer
var stage1_balloon_machine_sfx: AudioStreamPlayer
var star_collect_sfx: AudioStreamPlayer
var stage2_hydro_sfx: AudioStreamPlayer
var stage2_stonebreak_sfx: AudioStreamPlayer
var stage2_rockhit_sfx: AudioStreamPlayer
var stage2_rock_spawn_sfx: AudioStreamPlayer
var stage2_quake_sfx: AudioStreamPlayer
var stage2_boss_cry_sfx: AudioStreamPlayer
var stage2_speed_defense_start_sfx: AudioStreamPlayer
var stage2_speed_defense_hit_sfx: AudioStreamPlayer
var stage2_speed_defense_block_sfx: AudioStreamPlayer
var stage3_tail_sfx: AudioStreamPlayer
var stage3_psychoball_sfx: AudioStreamPlayer
var stage3_dollcurse_sfx: AudioStreamPlayer
var stage3_tears_sfx: AudioStreamPlayer
var stage3_chest_land_sfx: AudioStreamPlayer
var stage3_curse_explode_sfx: AudioStreamPlayer
var stage3_kuromi_awake_sfx: AudioStreamPlayer
var stage3_kuromi_stonebreak_sfx: AudioStreamPlayer
var stage3_kuromi_tongue_sfx: AudioStreamPlayer
var stage3_kuromi_swallow_sfx: AudioStreamPlayer
var stage3_kuromi_spit_sfx: AudioStreamPlayer
var lingpet_ghost_summon_sfx: AudioStreamPlayer
var lingpet_ghost_summon_out_sfx: AudioStreamPlayer
var lingpet_skeleton_archer_summon_sfx: AudioStreamPlayer
var lingpet_skeleton_archer_death_sfx: AudioStreamPlayer
var lingpet_skeleton_archer_arrow_fire_sfx: AudioStreamPlayer
var lingpet_skeleton_archer_arrow_hit_sfx: AudioStreamPlayer
var lingpet_bone_barrier_build_sfx: AudioStreamPlayer
var lingpet_bone_barrier_break_sfx: AudioStreamPlayer
var lingpet_bone_barrier_build_break_sfx: AudioStreamPlayer
var stage4_moon_shoot_sfx: AudioStreamPlayer
var stage4_fragment_shoot_sfx: AudioStreamPlayer
var stage4_temple_hit_sfx: AudioStreamPlayer
var stage4_birdkill_sfx: AudioStreamPlayer
var stage4_magnetic_sfx: AudioStreamPlayer
var stage4_meditation_sfx: AudioStreamPlayer
var stage4_meditation_after_sfx: AudioStreamPlayer
var stage5_hongryun_fireball_sfx: AudioStreamPlayer
var stage5_hongryun_charge_sfx: AudioStreamPlayer
var stage5_hongryun_shoot_sfx: AudioStreamPlayer
var stage6_tetriser_break_sfx: AudioStreamPlayer
var stage6_tetriser_wall_sfx: AudioStreamPlayer
var stage6_tetriser_super_sfx: AudioStreamPlayer
var stage6_tetriser_big_sfx: AudioStreamPlayer
var stage6_tetriser_shield_sfx: AudioStreamPlayer
var stage6_tetriser_laser_sfx: AudioStreamPlayer
var stage7_akamu_shuriken_shoot_sfx: AudioStreamPlayer
var stage7_akamu_shuriken_hit_sfx: AudioStreamPlayer
var stage7_akamu_cloud_sfx: AudioStreamPlayer
var stage7_akamu_aura_block_sfx: AudioStreamPlayer
var stage7_akamu_clone_spawn_sfx: AudioStreamPlayer
var stage7_akamu_clone_out_sfx: AudioStreamPlayer
var stage5_hongryun_hurt_sfx: Array = []
var leaf_shield_sfx: AudioStreamPlayer
var trampoline_bounce_sfx: AudioStreamPlayer
var stage1_bgm: AudioStreamPlayer
var stage1_alt_bgm: AudioStreamPlayer
var stage1_alt2_bgm: AudioStreamPlayer
var stage2_bgm: AudioStreamPlayer
var stage2_alt_bgm: AudioStreamPlayer
var stage3_bgm: AudioStreamPlayer
var stage4_bgm: AudioStreamPlayer
var stage4_phase2_bgm: AudioStreamPlayer
var stage5_bgm: AudioStreamPlayer
var stage6_bgm: AudioStreamPlayer
var stage7_bgm: AudioStreamPlayer
var stage1_bgm_rng := RandomNumberGenerator.new()
var stage1_bgm_rng_ready := false
var stage2_bgm_rng := RandomNumberGenerator.new()
var stage2_bgm_rng_ready := false
var _audio_setup_step := 0
var _audio_setup_stream_prewarm_group := -1
var _audio_setup_stream_prewarm_index := 0
var _bgm_setup_step := 0
var paddle_hit_panner: AudioEffectPanner
var wall_hit_panner: AudioEffectPanner


func setup(parent: Node) -> void:
	while not setup_step(parent):
		pass


func get_setup_progress() -> float:
	if _is_setup_complete():
		return 1.0
	var step_progress := _get_audio_setup_step_progress(_audio_setup_step)
	return clampf((float(_audio_setup_step) + step_progress) / float(AUDIO_SETUP_STEP_COUNT), 0.0, 1.0)


func setup_step(parent: Node) -> bool:
	if owner_node == parent and _is_setup_complete():
		return true
	if owner_node != parent:
		owner_node = parent
		_audio_setup_step = 0
		_audio_setup_stream_prewarm_group = -1
		_audio_setup_stream_prewarm_index = 0
		_bgm_setup_step = 0

	if not _prewarm_audio_setup_streams_step():
		return false

	match _audio_setup_step:
		0:
			_setup_core_ball_sfx()
		1:
			_setup_smasher_skill_sfx()
		2:
			_setup_commando_skill_sfx()
		3:
			_setup_item_command_sfx()
		4:
			_setup_projectile_item_sfx()
		5:
			_setup_stage_feedback_sfx()
		6:
			if not _setup_bgm_players_step():
				_apply_audio_buses_and_volumes()
				return false
		_:
			return _is_setup_complete()

	_apply_audio_buses_and_volumes()
	_audio_setup_step += 1
	_audio_setup_stream_prewarm_group = -1
	_audio_setup_stream_prewarm_index = 0
	return _is_setup_complete()


func _setup_core_ball_sfx() -> void:
	_ensure_hit_pan_buses()
	ui_move_sfx = player_factory.create(owner_node, "UiMoveSfx", UI_MOVE_SOUND_PATH, UI_MOVE_GAIN_DB)
	ui_confirm_sfx = player_factory.create(owner_node, "UiConfirmSfx", UI_CONFIRM_SOUND_PATH, UI_CONFIRM_GAIN_DB)
	ui_back_sfx = player_factory.create(owner_node, "UiBackSfx", UI_BACK_SOUND_PATH, UI_BACK_GAIN_DB)
	ui_perk_select_sfx = player_factory.create(owner_node, "UiPerkSelectSfx", UI_PERK_SELECT_SOUND_PATH, UI_PERK_SELECT_GAIN_DB)
	paddle_hit_sfx = player_factory.create(owner_node, "PaddleHitSfx", PADDLE_HIT_SOUND_PATH, -5.0)
	serve_sfx = player_factory.create(owner_node, "ServeSfx", SERVE_SOUND_PATH, -5.0)
	pingpong_serve_sfx = player_factory.create(owner_node, "PingpongServeSfx", PINGPONG_SERVE_SOUND_PATH, -5.0)
	wall_hit_sfx = player_factory.create(owner_node, "WallHitSfx", WALL_HIT_SOUND_PATH, -7.0)
	dash_sfx = player_factory.create(owner_node, "DashSfx", DASH_SOUND_PATH, -6.0)
	half_dash_sfx = player_factory.create(owner_node, "HalfDashSfx", HALF_DASH_SOUND_PATH, -6.0)
	dash_delay_sfx = player_factory.create(owner_node, "DashDelaySfx", DASH_DELAY_SOUND_PATH, 0.0)
	_enable_loop(dash_delay_sfx)
	dash_charge_sfx = player_factory.create(owner_node, "DashChargeSfx", DASH_CHARGE_SOUND_PATH, -5.0)
	bust_up_dash_sfx = player_factory.create(owner_node, "BustUpDashSfx", BUST_UP_DASH_SOUND_PATH, -5.0)
	boost_charging_sfx = player_factory.create(owner_node, "BoostChargingSfx", BOOST_CHARGING_SOUND_PATH, -5.0)
	soul_burst_dash_sfx = player_factory.create(owner_node, "SoulBurstDashSfx", SOUL_BURST_DASH_SOUND_PATH, -5.0)
	dash_spirit_delete_sfx = player_factory.create(owner_node, "DashSpiritDeleteSfx", DASH_SPIRIT_DELETE_SOUND_PATH, -5.0)


func _setup_smasher_skill_sfx() -> void:
	drive_sfx = player_factory.create(owner_node, "DriveSfx", DRIVE_SOUND_PATH, -5.0)
	mika_drive_voice_sfx = player_factory.create(owner_node, "MikaDriveVoiceSfx", MIKA_DRIVE_VOICE_PATH, MIKA_DRIVE_VOICE_GAIN_DB)
	plasma_charge_sfx = player_factory.create(owner_node, "PlasmaChargeSfx", PLASMA_CHARGE_SOUND_PATH, PLASMA_CHARGE_GAIN_DB)
	plasma_shoot_sfx = player_factory.create(owner_node, "PlasmaShootSfx", PLASMA_SHOOT_SOUND_PATH, PLASMA_SHOOT_GAIN_DB)
	plasma_shock_sfx = player_factory.create(owner_node, "PlasmaShockSfx", PLASMA_SHOCK_SOUND_PATH, PLASMA_SHOCK_GAIN_DB)
	_enable_loop(plasma_charge_sfx)
	_enable_loop(plasma_shock_sfx)
	recovery_sfx = player_factory.create(owner_node, "RecoverySfx", RECOVERY_SOUND_PATH, -5.0)
	cleanse_sfx = player_factory.create(owner_node, "CleanseSfx", CLEANSE_SOUND_PATH, -5.0)
	warp_gate_sfx = player_factory.create(owner_node, "WarpGateSfx", WARP_GATE_SOUND_PATH, -5.0)
	_enable_loop(warp_gate_sfx)
	magnum_grip_sfx = player_factory.create(owner_node, "MagnumGripSfx", MAGNUM_GRIP_SOUND_PATH, -5.0)
	_enable_loop(magnum_grip_sfx)
	smasher_wheel_sfx = player_factory.create(owner_node, "SmasherWheelSfx", SMASHER_WHEEL_SOUND_PATH, -5.0)
	_enable_loop(smasher_wheel_sfx)
	shield_kiting_wind_up_sfx = player_factory.create(owner_node, "ShieldKitingWindUpSfx", SHIELD_KITING_WIND_UP_SOUND_PATH, -5.0)
	shield_kiting_launch_sfx = player_factory.create(owner_node, "ShieldKitingLaunchSfx", SHIELD_KITING_LAUNCH_SOUND_PATH, -5.0)
	shield_kiting_hit_sfx = player_factory.create(owner_node, "ShieldKitingHitSfx", SHIELD_KITING_HIT_SOUND_PATH, -4.0)
	whip_sfx = player_factory.create(owner_node, "WhipSfx", WHIP_SOUND_PATH, -5.0)
	gaksital_fan_sfx = player_factory.create(owner_node, "GaksitalFanSfx", FAN_SOUND_PATH, _volume_to_db(0.35))
	gaksital_fan_sfx_layers = _create_optional_sfx_layers("GaksitalFanSfxLayer", FAN_SOUND_PATH, _volume_to_db(0.35), GAKSITAL_FAN_SOUND_POOL_SIZE - 1)
	gaksital_fan_sfx_cursor = 0
	whipcrack_sfx = player_factory.create(owner_node, "WhipcrackSfx", WHIPCRACK_SOUND_PATH, _volume_to_db(0.6))
	thor_shield_open_sfx = player_factory.create(owner_node, "ThorShieldOpenSfx", THOR_SHIELD_OPEN_SOUND_PATH, -4.4)
	thor_shield_close_sfx = player_factory.create(owner_node, "ThorShieldCloseSfx", THOR_SHIELD_CLOSE_SOUND_PATH, -4.4)
	thor_shield_swing_sfx = player_factory.create(owner_node, "ThorShieldSwingSfx", THOR_SHIELD_SWING_SOUND_PATH, -5.0)
	thor_shield_block_sfx = player_factory.create(owner_node, "ThorShieldBlockSfx", THOR_SHIELD_BLOCK_SOUND_PATH, -4.0)
	viper_jetpack_sfx = player_factory.create(owner_node, "ViperJetpackSfx", VIPER_JETPACK_SOUND_PATH, -8.5)
	_enable_loop(viper_jetpack_sfx)
	viper_backstep_sfx = player_factory.create(owner_node, "ViperBackstepSfx", VIPER_BACKSTEP_SOUND_PATH, -6.0)
	viper_shadow_kick_sfx = player_factory.create(owner_node, "ViperShadowKickSfx", VIPER_SHADOW_KICK_SOUND_PATH, -4.4)
	viper_marshal_kick_sfx = player_factory.create(owner_node, "ViperMarshalKickSfx", VIPER_SHADOW_KICK_SOUND_PATH, -4.4)
	viper_dive_prep_sfx = player_factory.create(owner_node, "ViperDivePrepSfx", VIPER_DIVE_PREP_SOUND_PATH, VIPER_DIVE_PREP_GAIN_DB)
	viper_dive_strike_sfx = player_factory.create(owner_node, "ViperDiveStrikeSfx", VIPER_DIVE_STRIKE_SOUND_PATH, VIPER_DIVE_STRIKE_GAIN_DB)
	viper_ignition_aura_sfx = player_factory.create(owner_node, "ViperIgnitionAuraSfx", VIPER_IGNITION_AURA_SOUND_PATH, VIPER_IGNITION_AURA_GAIN_DB)
	viper_ignition_aura_fallback_sfx = player_factory.create(owner_node, "ViperIgnitionAuraFallbackSfx", VIPER_IGNITION_AURA_FALLBACK_SOUND_PATH, VIPER_IGNITION_AURA_GAIN_DB)
	viper_phantom_show_sfx = player_factory.create(owner_node, "ViperPhantomShowSfx", VIPER_PHANTOM_SHOW_SOUND_PATH, -1.5)
	viper_phantom_kick_hit_sfx = player_factory.create(owner_node, "ViperPhantomKickHitSfx", VIPER_PHANTOM_KICK_HIT_SOUND_PATH, -2.5)
	viper_blade_sfx = player_factory.create(owner_node, "ViperBladeSfx", VIPER_BLADE_SOUND_PATH, -6.0)
	viper_blade_spin_sfx = player_factory.create(owner_node, "ViperBladeSpinSfx", VIPER_BLADE_SPIN_SOUND_PATH, -3.0)
	viper_venom_moving_sfx = player_factory.create(owner_node, "ViperVenomMovingSfx", VIPER_VENOM_MOVING_SOUND_PATH, -4.4)
	viper_venom_attack_sfx = player_factory.create(owner_node, "ViperVenomAttackSfx", VIPER_VENOM_ATTACK_SOUND_PATH, -4.4)
	viper_hwarang_kick_sfx = player_factory.create(owner_node, "ViperHwarangKickSfx", VIPER_HWARANG_KICK_SOUND_PATH, -3.2)
	viper_kick_guard_knockback_sfx = player_factory.create(owner_node, "ViperKickGuardKnockbackSfx", VIPER_KICK_GUARD_KNOCKBACK_SOUND_PATH, -4.0)
	viper_dual_glitch_windup_sfx = player_factory.create(owner_node, "ViperDualGlitchWindupSfx", VIPER_DUAL_GLITCH_WINDUP_SOUND_PATH, VIPER_DUAL_GLITCH_WINDUP_GAIN_DB)
	viper_dual_glitch_split_sfx = player_factory.create(owner_node, "ViperDualGlitchSplitSfx", VIPER_DUAL_GLITCH_SPLIT_SOUND_PATH, VIPER_DUAL_GLITCH_SPLIT_GAIN_DB)
	chaos_spear_windup_sfx = player_factory.create(owner_node, "ChaosSpearWindupSfx", CHAOS_SPEAR_WINDUP_SOUND_PATH, -4.4)
	chaos_spear_flying_sfx = player_factory.create(owner_node, "ChaosSpearFlyingSfx", CHAOS_SPEAR_FLYING_SOUND_PATH, -4.4)
	chaos_spear_impact_sfx = player_factory.create(owner_node, "ChaosSpearImpactSfx", CHAOS_SPEAR_IMPACT_SOUND_PATH, -4.4)
	chaos_spear_blackhole_sfx = player_factory.create(owner_node, "ChaosSpearBlackholeSfx", CHAOS_SPEAR_BLACKHOLE_SOUND_PATH, -5.5)
	_enable_loop(chaos_spear_blackhole_sfx)


func _setup_commando_skill_sfx() -> void:
	commando_supply_radio_sfx = _create_optional_sfx("CommandoSupplyRadioSfx", COMMANDO_SUPPLY_RADIO_SOUND_PATH, -6.0)
	# Python parity (supply_drop.py start_radio_loop): radio.wav (~3.5s) plays
	# exactly once per hold session and runs to its natural end -- the "loop"
	# name is historical. Do not _enable_loop this player; with the state-side
	# tail no longer force-stopping it, a looping stream would never end.
	commando_supply_radio_loop_sfx = _create_optional_sfx("CommandoSupplyRadioLoopSfx", COMMANDO_SUPPLY_RADIO_SOUND_PATH, -7.0)
	commando_supply_aircraft_sfx = _create_optional_sfx("CommandoSupplyAircraftSfx", COMMANDO_SUPPLY_AIRCRAFT_SOUND_PATH, COMMANDO_SUPPLY_AIRCRAFT_GAIN_DB)
	_enable_loop(commando_supply_aircraft_sfx)
	commando_weapon_change_sfx = _create_optional_sfx("CommandoWeaponChangeSfx", COMMANDO_WEAPON_CHANGE_SOUND_PATH, COMMANDO_WEAPON_CHANGE_GAIN_DB)
	commando_fire_support_radio_sfx = _create_optional_sfx("CommandoFireSupportRadioSfx", COMMANDO_SUPPLY_RADIO_SOUND_PATH, -5.5)
	commando_fire_support_aircraft_sfx = _create_optional_sfx("CommandoFireSupportAircraftSfx", COMMANDO_SUPPLY_AIRCRAFT_SOUND_PATH, -7.5)
	_enable_loop(commando_fire_support_aircraft_sfx)
	commando_slingshot_fire_sfx = _create_optional_sfx("CommandoSlingshotFireSfx", COMMANDO_SLINGSHOT_FIRE_SOUND_PATH, COMMANDO_SLINGSHOT_FIRE_GAIN_DB)
	commando_pistol_ready_sfx = _create_optional_sfx("CommandoPistolReadySfx", COMMANDO_PISTOL_READY_SOUND_PATH, COMMANDO_PISTOL_READY_GAIN_DB)
	commando_pistol_fire_sfx = _create_optional_sfx("CommandoPistolFireSfx", COMMANDO_PISTOL_FIRE_SOUND_PATH, COMMANDO_PISTOL_FIRE_GAIN_DB)
	commando_pistol_reload_start_sfx = _create_optional_sfx("CommandoPistolReloadStartSfx", COMMANDO_PISTOL_RELOAD_START_SOUND_PATH, COMMANDO_PISTOL_RELOAD_GAIN_DB)
	commando_pistol_reload_sfx = _create_optional_sfx("CommandoPistolReloadSfx", COMMANDO_PISTOL_RELOAD_SOUND_PATH, COMMANDO_PISTOL_RELOAD_GAIN_DB)
	commando_reload_sfx = _create_optional_sfx("CommandoReloadSfx", COMMANDO_RELOAD_SOUND_PATH, COMMANDO_PISTOL_RELOAD_GAIN_DB)
	commando_ak47_fire_sfx = _create_optional_sfx("CommandoAk47FireSfx", COMMANDO_AK47_FIRE_SOUND_PATH, COMMANDO_AK47_FIRE_GAIN_DB)
	commando_ak47_fire_sfx_layers = _create_optional_sfx_layers("CommandoAk47FireSfxLayer", COMMANDO_AK47_FIRE_SOUND_PATH, COMMANDO_AK47_FIRE_GAIN_DB, COMMANDO_AK47_FIRE_POOL_SIZE - 1)
	commando_ak47_fire_sfx_cursor = 0
	commando_bazooka_fire_sfx = _create_optional_sfx("CommandoBazookaFireSfx", COMMANDO_BAZOOKA_FIRE_SOUND_PATH, COMMANDO_BAZOOKA_FIRE_GAIN_DB)
	commando_net_capture_sfx = _create_optional_sfx("CommandoNetCaptureSfx", COMMANDO_NET_CAPTURE_SOUND_PATH, COMMANDO_NET_CAPTURE_GAIN_DB)
	commando_net_constrict_sfx = _create_optional_sfx("CommandoNetConstrictSfx", COMMANDO_NET_CONSTRICT_SOUND_PATH, COMMANDO_NET_CONSTRICT_GAIN_DB)
	commando_bowling_trap_install_sfx = _create_optional_sfx("CommandoBowlingTrapInstallSfx", COMMANDO_BOWLING_TRAP_INSTALL_SOUND_PATH, COMMANDO_BOWLING_TRAP_GAIN_DB)
	commando_bowling_trap_snap_sfx = _create_optional_sfx("CommandoBowlingTrapSnapSfx", COMMANDO_BOWLING_TRAP_SNAP_SOUND_PATH, COMMANDO_BOWLING_TRAP_GAIN_DB)
	commando_suicide_drone_sfx = _create_optional_sfx("CommandoSuicideDroneSfx", COMMANDO_SUICIDE_DRONE_SOUND_PATH, COMMANDO_SUICIDE_DRONE_GAIN_DB)
	_enable_loop(commando_suicide_drone_sfx)


func _setup_item_command_sfx() -> void:
	item_get_sfx = player_factory.create(owner_node, "ItemGetSfx", ITEM_GET_SOUND_PATH, -5.0)
	drink_sfx = player_factory.create(owner_node, "DrinkSfx", DRINK_SOUND_PATH, -5.0)
	active_item_sfx = player_factory.create(owner_node, "ActiveItemSfx", ACTIVE_ITEM_SOUND_PATH, -5.0)
	trade_sfx = player_factory.create(owner_node, "TradeSfx", TRADE_SOUND_PATH, TRADE_SOUND_GAIN_DB)
	brick_wall_destroy_sfx = player_factory.create(owner_node, "BrickWallDestroySfx", BRICK_WALL_DESTROY_SOUND_PATH, BRICK_WALL_DESTROY_GAIN_DB)
	treasure_hunt_mining_sfx = player_factory.create(owner_node, "TreasureHuntMiningSfx", TREASURE_HUNT_MINING_SOUND_PATH, -6.0)
	alchemy_sfx = player_factory.create(owner_node, "AlchemySfx", ALCHEMY_SOUND_PATH, -4.5)
	pandora_sfx = player_factory.create(owner_node, "PandoraSfx", PANDORA_SOUND_PATH, -5.0)
	lucky_coin_spawn_sfx = player_factory.create(owner_node, "LuckyCoinSpawnSfx", LUCKY_COIN_SPAWN_SOUND_PATH, -5.0)
	foul_whistle_sfx = player_factory.create(owner_node, "FoulWhistleSfx", FOUL_WHISTLE_SOUND_PATH, -4.0)
	megingjord_sfx = player_factory.create(owner_node, "MegingjordSfx", MEGINGJORD_SOUND_PATH, -5.0)
	legendary_open_sfx = player_factory.create(owner_node, "LegendaryOpenSfx", LEGENDARY_OPEN_SOUND_PATH, -5.0)
	angel_blessing_roll_sfx = player_factory.create(owner_node, "AngelBlessingRollSfx", ANGEL_BLESSING_ROLL_SOUND_PATH, ANGEL_BLESSING_ROLL_GAIN_DB)
	angel_blessing_absorb_sfx = player_factory.create(owner_node, "AngelBlessingAbsorbSfx", ANGEL_BLESSING_ABSORB_SOUND_PATH, ANGEL_BLESSING_ABSORB_GAIN_DB)
	angel_blessing_absorb_sfx_layers = _create_optional_sfx_layers(
		"AngelBlessingAbsorbSfxLayer",
		ANGEL_BLESSING_ABSORB_SOUND_PATH,
		ANGEL_BLESSING_ABSORB_GAIN_DB,
		ANGEL_BLESSING_ABSORB_POOL_SIZE - 1
	)
	angel_blessing_absorb_sfx_cursor = 0
	result_box_open_sfx = player_factory.create(owner_node, "ResultBoxOpenSfx", RESULT_BOX_OPEN_SOUND_PATH, -4.0)
	defeat_jewel_sfx = player_factory.create(owner_node, "DefeatJewelSfx", DEFEAT_JEWEL_SOUND_PATH, -4.0)
	defeat_gem_shatter_sfx = player_factory.create(owner_node, "DefeatGemShatterSfx", DEFEAT_GEM_SHATTER_SOUND_PATH, -3.0)
	lingpet_acquire_cutin_sfx = player_factory.create(owner_node, "LingpetAcquireCutinSfx", LINGPET_ACQUIRE_CUTIN_SOUND_PATH, LINGPET_ACQUIRE_CUTIN_GAIN_DB)
	lingpet_acquire_click_deep_bass_sfx = player_factory.create(owner_node, "LingpetAcquireClickDeepBassSfx", LINGPET_ACQUIRE_CLICK_DEEP_BASS_SOUND_PATH, LINGPET_ACQUIRE_CLICK_DEEP_BASS_GAIN_DB)
	lingpet_acquire_click_crackle_sweep_sfx = player_factory.create(owner_node, "LingpetAcquireClickCrackleSweepSfx", LINGPET_ACQUIRE_CLICK_CRACKLE_SWEEP_SOUND_PATH, LINGPET_ACQUIRE_CLICK_CRACKLE_SWEEP_GAIN_DB)
	lingpet_lunabi_click_voice_sfx = player_factory.create(owner_node, "LingpetLunabiClickVoiceSfx", LINGPET_LUNABI_CLICK_VOICE_SOUND_PATH, LINGPET_LUNABI_CLICK_VOICE_GAIN_DB)
	lingpet_volty_click_voice_sfx = player_factory.create(owner_node, "LingpetVoltyClickVoiceSfx", LINGPET_VOLTY_CLICK_VOICE_SOUND_PATH, LINGPET_VOLTY_CLICK_VOICE_GAIN_DB)
	lingpet_milkring_click_voice_sfx = player_factory.create(owner_node, "LingpetMilkringClickVoiceSfx", LINGPET_MILKRING_CLICK_VOICE_SOUND_PATH, LINGPET_MILKRING_CLICK_VOICE_GAIN_DB)
	lingpet_red_dragon_click_voice_sfx = player_factory.create(owner_node, "LingpetRedDragonClickVoiceSfx", LINGPET_RED_DRAGON_CLICK_VOICE_SOUND_PATH, LINGPET_RED_DRAGON_CLICK_VOICE_GAIN_DB)
	lingpet_maribo_click_voice_sfx = player_factory.create(owner_node, "LingpetMariboClickVoiceSfx", LINGPET_MARIBO_CLICK_VOICE_SOUND_PATH, LINGPET_MARIBO_CLICK_VOICE_GAIN_DB)
	lingpet_rabi_click_voice_sfx = player_factory.create(owner_node, "LingpetRabiClickVoiceSfx", LINGPET_RABI_CLICK_VOICE_SOUND_PATH, LINGPET_RABI_CLICK_VOICE_GAIN_DB)
	lingpet_lumion_click_voice_sfx = player_factory.create(owner_node, "LingpetLumionClickVoiceSfx", LINGPET_LUMION_CLICK_VOICE_SOUND_PATH, LINGPET_LUMION_CLICK_VOICE_GAIN_DB)
	lingpet_monkeyring_click_voice_sfx = player_factory.create(owner_node, "LingpetMonkeyringClickVoiceSfx", LINGPET_MONKEYRING_CLICK_VOICE_SOUND_PATH, LINGPET_MONKEYRING_CLICK_VOICE_GAIN_DB)
	lingpet_onimaru_click_voice_sfx = player_factory.create(owner_node, "LingpetOnimaruClickVoiceSfx", LINGPET_ONIMARU_CLICK_VOICE_SOUND_PATH, LINGPET_ONIMARU_CLICK_VOICE_GAIN_DB)
	lingpet_orosha_click_voice_sfx = player_factory.create(owner_node, "LingpetOroshaClickVoiceSfx", LINGPET_OROSHA_CLICK_VOICE_SOUND_PATH, LINGPET_OROSHA_CLICK_VOICE_GAIN_DB)
	lingpet_koyora_click_voice_sfx = player_factory.create(owner_node, "LingpetKoyoraClickVoiceSfx", LINGPET_KOYORA_CLICK_VOICE_SOUND_PATH, LINGPET_KOYORA_CLICK_VOICE_GAIN_DB)
	lingpet_puppet_grab_cast_sfx = player_factory.create(owner_node, "LingpetPuppetGrabCastSfx", LINGPET_PUPPET_GRAB_CAST_SOUND_PATH, LINGPET_PUPPET_GRAB_CAST_GAIN_DB)
	lingpet_puppet_grab_pull_sfx = player_factory.create(owner_node, "LingpetPuppetGrabPullSfx", LINGPET_PUPPET_GRAB_PULL_SOUND_PATH, LINGPET_PUPPET_GRAB_PULL_GAIN_DB)
	lingpet_puppet_grab_kiss_sfx = player_factory.create(owner_node, "LingpetPuppetGrabKissSfx", LINGPET_PUPPET_GRAB_KISS_SOUND_PATH, LINGPET_PUPPET_GRAB_KISS_GAIN_DB)
	lingpet_puppet_grab_miss_sfx = player_factory.create(owner_node, "LingpetPuppetGrabMissSfx", LINGPET_PUPPET_GRAB_MISS_SOUND_PATH, LINGPET_PUPPET_GRAB_MISS_GAIN_DB)
	lingpet_sand_prison_open_sfx = player_factory.create(owner_node, "LingpetSandPrisonOpenSfx", LINGPET_SAND_PRISON_OPEN_SOUND_PATH, LINGPET_SAND_PRISON_OPEN_GAIN_DB)
	lingpet_wild_roar_sfx = player_factory.create(owner_node, "LingpetWildRoarSfx", LINGPET_WILD_ROAR_SOUND_PATH, LINGPET_WILD_ROAR_GAIN_DB)
	lingpet_star_coil_bind_sfx = player_factory.create(owner_node, "LingpetStarCoilBindSfx", LINGPET_STAR_COIL_BIND_SOUND_PATH, LINGPET_STAR_COIL_BIND_GAIN_DB)
	lingpet_star_coil_move_sfx = player_factory.create(owner_node, "LingpetStarCoilMoveSfx", LINGPET_STAR_COIL_MOVE_SOUND_PATH, LINGPET_STAR_COIL_MOVE_GAIN_DB)
	_enable_loop(lingpet_star_coil_move_sfx)
	lingpet_ring_dash_sfx = player_factory.create(owner_node, "LingpetRingDashSfx", LINGPET_RING_DASH_SOUND_PATH, LINGPET_RING_DASH_GAIN_DB)
	lingpet_affinity_level_up_sfx = player_factory.create(owner_node, "LingpetAffinityLevelUpSfx", LINGPET_AFFINITY_LEVEL_UP_SOUND_PATH, LINGPET_AFFINITY_LEVEL_UP_GAIN_DB)
	lingpet_egg_hit_sfx = player_factory.create(owner_node, "LingpetEggHitSfx", str(LINGPET_EGG_HIT_SOUND_PATHS[0]), LINGPET_EGG_HIT_GAIN_DB)
	lingpet_egg_hit_streams = _load_audio_stream_candidates(LINGPET_EGG_HIT_SOUND_PATHS)
	legendary_after_sfx = player_factory.create(owner_node, "LegendaryAfterSfx", LEGENDARY_AFTER_SOUND_PATH, -6.0)
	legendary_ending_sfx = player_factory.create(owner_node, "LegendaryEndingSfx", LEGENDARY_ENDING_SOUND_PATH, -5.0)
	ragnarok_shot_sfx = player_factory.create(owner_node, "RagnarokShotSfx", RAGNAROK_SHOT_SOUND_PATH, -4.0)
	ragnarok_boom_sfx = player_factory.create(owner_node, "RagnarokBoomSfx", RAGNAROK_BOOM_SOUND_PATH, -3.5)
	ragnarok_shock_sfx = player_factory.create(owner_node, "RagnarokShockSfx", RAGNAROK_SHOCK_SOUND_PATH, -5.5)
	electric_shock_sfx = player_factory.create(owner_node, "ElectricShockSfx", ELECTRIC_SHOCK_SOUND_PATH, ELECTRIC_SHOCK_GAIN_DB)
	thunder_orb_shot_sfx = player_factory.create(owner_node, "ThunderOrbShotSfx", THUNDER_ORB_SHOT_SOUND_PATH, THUNDER_ORB_SHOT_GAIN_DB)
	thunder_orb_boom_sfx = player_factory.create(owner_node, "ThunderOrbBoomSfx", THUNDER_ORB_BOOM_SOUND_PATH, THUNDER_ORB_BOOM_GAIN_DB)
	solar_bolt_strike_sfx = player_factory.create(owner_node, "SolarBoltStrikeSfx", SOLAR_BOLT_STRIKE_SOUND_PATH, SOLAR_BOLT_STRIKE_GAIN_DB)
	mini_spark_sfx = player_factory.create(owner_node, "MiniSparkSfx", str(MINI_SPARK_SOUND_PATHS[0]), MINI_SPARK_GAIN_DB)
	mini_spark_streams = _load_audio_stream_candidates(MINI_SPARK_SOUND_PATHS)
	poseidon_wave_sfx = player_factory.create(owner_node, "PoseidonWaveSfx", POSEIDON_WAVE_SOUND_PATH, -5.0)
	poseidon_charge_sfx = player_factory.create(owner_node, "PoseidonChargeSfx", POSEIDON_CHARGE_SOUND_PATH, -5.0)
	_enable_loop(ragnarok_shock_sfx)
	_enable_loop(electric_shock_sfx)
	timewatch_sfx = player_factory.create(owner_node, "TimewatchSfx", TIMEWATCH_SOUND_PATH, -5.0)
	throw_before_sfx = player_factory.create(owner_node, "ThrowBeforeSfx", THROW_BEFORE_SOUND_PATH, -5.0)
	throw_sfx = player_factory.create(owner_node, "ThrowSfx", THROW_SOUND_PATH, -5.0)
	horn_strawberry_change_sfx = player_factory.create(owner_node, "HornStrawberryChangeSfx", HORN_STRAWBERRY_CHANGE_SOUND_PATH, HORN_STRAWBERRY_CHANGE_GAIN_DB)
	horn_strawberry_eat_sfx = player_factory.create(owner_node, "HornStrawberryEatSfx", HORN_STRAWBERRY_EAT_SOUND_PATH, HORN_STRAWBERRY_EAT_GAIN_DB)
	horn_strawberry_stem_fire_sfx = player_factory.create(owner_node, "HornStrawberryStemFireSfx", HORN_STRAWBERRY_STEM_FIRE_SOUND_PATH, HORN_STRAWBERRY_STEM_FIRE_GAIN_DB)
	horn_strawberry_stem_hit_sfx = player_factory.create(owner_node, "HornStrawberryStemHitSfx", HORN_STRAWBERRY_STEM_HIT_SOUND_PATH, HORN_STRAWBERRY_STEM_HIT_GAIN_DB)
	horn_strawberry_horn_charge_sfx = player_factory.create(owner_node, "HornStrawberryHornChargeSfx", HORN_STRAWBERRY_HORN_CHARGE_SOUND_PATH, HORN_STRAWBERRY_HORN_CHARGE_GAIN_DB)
	horn_strawberry_field_build_sfx = player_factory.create(owner_node, "HornStrawberryFieldBuildSfx", HORN_STRAWBERRY_FIELD_BUILD_SOUND_PATH, HORN_STRAWBERRY_FIELD_GAIN_DB)
	horn_strawberry_field_break_sfx = player_factory.create(owner_node, "HornStrawberryFieldBreakSfx", HORN_STRAWBERRY_FIELD_BREAK_SOUND_PATH, HORN_STRAWBERRY_FIELD_GAIN_DB)
	horn_strawberry_field_build_break_sfx = player_factory.create(owner_node, "HornStrawberryFieldBuildBreakSfx", HORN_STRAWBERRY_FIELD_BUILD_BREAK_SOUND_PATH, HORN_STRAWBERRY_FIELD_BUILD_BREAK_GAIN_DB)
	horn_strawberry_bomb_trigger_sfx = player_factory.create(owner_node, "HornStrawberryBombTriggerSfx", HORN_STRAWBERRY_BOMB_TRIGGER_SOUND_PATH, HORN_STRAWBERRY_BOMB_TRIGGER_GAIN_DB)


func _setup_projectile_item_sfx() -> void:
	grenade_sfx = player_factory.create(owner_node, "GrenadeSfx", GRENADE_SOUND_PATH, -4.0)
	flashbomb_sfx = player_factory.create(owner_node, "FlashbombSfx", FLASHBOMB_SOUND_PATH, -4.0)
	smokebomb_sfx = player_factory.create(owner_node, "SmokebombSfx", SMOKEBOMB_SOUND_PATH, -5.0)
	firebomb_sfx = player_factory.create(owner_node, "FirebombSfx", FIREBOMB_SOUND_PATH, -4.0)
	boomerang_sfx = player_factory.create(owner_node, "BoomerangSfx", BOOMERANG_SOUND_PATH, -8.0)
	boomerang_hit_sfx = player_factory.create(owner_node, "BoomerangHitSfx", BOOMERANG_HIT_SOUND_PATH, -5.0)
	boomerang_break_sfx = player_factory.create(owner_node, "BoomerangBreakSfx", BOOMERANG_BREAK_SOUND_PATH, -5.0)
	shrapnel_armor_fire_sfx = player_factory.create(owner_node, "ShrapnelArmorFireSfx", SHRAPNEL_ARMOR_FIRE_SOUND_PATH, -5.0)
	shrapnel_armor_hit_sfx = player_factory.create(owner_node, "ShrapnelArmorHitSfx", SHRAPNEL_ARMOR_HIT_SOUND_PATH, -5.0)
	_enable_loop(boomerang_sfx)
	banana_throw_sfx = player_factory.create(owner_node, "BananaThrowSfx", BANANA_THROW_SOUND_PATH, -6.0)
	banana_slip_sfx = player_factory.create(owner_node, "BananaSlipSfx", BANANA_SLIP_SOUND_PATH, -4.0)
	soap_throw_sfx = player_factory.create(owner_node, "SoapThrowSfx", SOAP_THROW_SOUND_PATH, -7.0)
	soap_land_sfx = player_factory.create(owner_node, "SoapLandSfx", SOAP_LAND_SOUND_PATH, -8.0)
	soap_slip_sfx = player_factory.create(owner_node, "SoapSlipSfx", SOAP_SLIP_SOUND_PATH, -4.0)
	spider_mine_walk_sfx = player_factory.create(owner_node, "SpiderMineWalkSfx", SPIDER_MINE_WALK_SOUND_PATH, -6.5)
	spider_mine_setup_sfx = player_factory.create(owner_node, "SpiderMineSetupSfx", SPIDER_MINE_SETUP_SOUND_PATH, -5.0)
	bomb_surprise_attach_sfx = player_factory.create(owner_node, "BombSurpriseAttachSfx", BOMB_SURPRISE_ATTACH_SOUND_PATH, BOMB_SURPRISE_ATTACH_GAIN_DB)
	bomb_surprise_transfer_sfx = player_factory.create(owner_node, "BombSurpriseTransferSfx", SPIDER_MINE_SETUP_SOUND_PATH, BOMB_SURPRISE_TRANSFER_GAIN_DB)
	bomb_surprise_tick1_sfx = player_factory.create(owner_node, "BombSurpriseTick1Sfx", BOMB_SURPRISE_TICK1_SOUND_PATH, -16.4782)
	bomb_surprise_tick2_sfx = player_factory.create(owner_node, "BombSurpriseTick2Sfx", BOMB_SURPRISE_TICK2_SOUND_PATH, -16.4782)
	bomb_surprise_urgent_tick_sfx = player_factory.create(owner_node, "BombSurpriseUrgentTickSfx", BOMB_SURPRISE_URGENT_TICK_SOUND_PATH, BOMB_SURPRISE_URGENT_TICK_GAIN_DB)
	bomb_surprise_explosion_sfx = player_factory.create(owner_node, "BombSurpriseExplosionSfx", GRENADE_SOUND_PATH, BOMB_SURPRISE_EXPLOSION_GAIN_DB)
	bomb_surprise_self_explosion_sfx = player_factory.create(owner_node, "BombSurpriseSelfExplosionSfx", STAGE3_CURSE_EXPLODE_SOUND_PATH, BOMB_SURPRISE_EXPLOSION_GAIN_DB)
	lingpet_gatling_transform_sfx = player_factory.create(owner_node, "LingpetGatlingTransformSfx", LINGPET_GATLING_TRANSFORM_SOUND_PATH, LINGPET_GATLING_TRANSFORM_GAIN_DB)
	lingpet_gatling_loop_sfx = player_factory.create(owner_node, "LingpetGatlingLoopSfx", LINGPET_GATLING_LOOP_SOUND_PATH, LINGPET_GATLING_LOOP_GAIN_DB)
	lingpet_gatling_fire_sfx = player_factory.create(owner_node, "LingpetGatlingFireSfx", LINGPET_GATLING_FIRE_SOUND_PATH, LINGPET_GATLING_FIRE_GAIN_DB)
	lingpet_gatling_hit_sfx = player_factory.create(owner_node, "LingpetGatlingHitSfx", LINGPET_GATLING_HIT_SOUND_PATH, LINGPET_GATLING_HIT_GAIN_DB)
	lingpet_dwarf_magic_cast_sfx = player_factory.create(owner_node, "LingpetDwarfMagicCastSfx", LINGPET_DWARF_MAGIC_CAST_SOUND_PATH, LINGPET_DWARF_MAGIC_CAST_GAIN_DB)
	lingpet_dwarf_magic_hit_sfx = player_factory.create(owner_node, "LingpetDwarfMagicHitSfx", LINGPET_DWARF_MAGIC_HIT_SOUND_PATH, LINGPET_DWARF_MAGIC_HIT_GAIN_DB)
	lingpet_gravity_accel_cast_sfx = player_factory.create(owner_node, "LingpetGravityAccelCastSfx", LINGPET_GRAVITY_ACCEL_CAST_SOUND_PATH, LINGPET_GRAVITY_ACCEL_CAST_GAIN_DB)
	_enable_loop(spider_mine_walk_sfx)
	_enable_loop(lingpet_gatling_loop_sfx)


func _setup_stage_feedback_sfx() -> void:
	power_smash_sfx = player_factory.create(owner_node, "PowerSmashSfx", POWER_SMASH_SOUND_PATH, -4.0)
	mika_power_smashing_voice_sfx = player_factory.create(owner_node, "MikaPowerSmashingVoiceSfx", str(MIKA_POWER_SMASHING_VOICE_PATHS[0]), MIKA_POWER_SMASHING_VOICE_GAIN_DB)
	mika_power_smashing_voice_streams = _load_audio_stream_candidates(MIKA_POWER_SMASHING_VOICE_PATHS)
	mika_ghost_smashing_voice_sfx = player_factory.create(owner_node, "MikaGhostSmashingVoiceSfx", str(MIKA_GHOST_SMASHING_VOICE_PATHS[0]), MIKA_GHOST_SMASHING_VOICE_GAIN_DB)
	mika_ghost_smashing_voice_streams = _load_audio_stream_candidates(MIKA_GHOST_SMASHING_VOICE_PATHS)
	power_smash_launch_sfx = player_factory.create(owner_node, "PowerSmashLaunchSfx", POWER_SMASH_LAUNCH_SOUND_PATH, -4.0)
	round_set_sfx = player_factory.create(owner_node, "RoundSetSfx", ROUND_SET_SOUND_PATH, SCOREBOARD_SOUND_VOLUME_DB)
	ball_spawn_intro_sfx = player_factory.create(owner_node, "BallSpawnIntroSfx", BALL_SPAWN_INTRO_SOUND_PATH, -4.0)
	stage_landing_zoom_intro_sfx = player_factory.create(owner_node, "StageLandingZoomIntroSfx", STAGE_LANDING_ZOOM_INTRO_SOUND_PATH, -3.0)
	balloon_pop_sfx = player_factory.create(owner_node, "BalloonPopSfx", BALLOON_POP_SOUND_PATH, -5.0)
	stage1_balloon_door_sfx = player_factory.create(owner_node, "Stage1BalloonDoorSfx", STAGE1_BALLOON_DOOR_SOUND_PATH, -6.0)
	stage1_balloon_machine_sfx = player_factory.create(owner_node, "Stage1BalloonMachineSfx", STAGE1_BALLOON_MACHINE_SOUND_PATH, -7.0)
	star_collect_sfx = player_factory.create(owner_node, "StarCollectSfx", STAR_COLLECT_SOUND_PATH, -4.0)
	stage2_hydro_sfx = player_factory.create(owner_node, "Stage2HydroSfx", STAGE2_HYDRO_SOUND_PATH, -5.0)
	stage2_stonebreak_sfx = player_factory.create(owner_node, "Stage2StonebreakSfx", STAGE2_STONEBREAK_SOUND_PATH, -5.0)
	stage2_rockhit_sfx = player_factory.create(owner_node, "Stage2RockhitSfx", STAGE2_ROCKHIT_SOUND_PATH, -5.0)
	stage2_rock_spawn_sfx = player_factory.create(owner_node, "Stage2RockSpawnSfx", STAGE2_ROCK_SPAWN_SOUND_PATH, -5.0)
	stage2_quake_sfx = player_factory.create(owner_node, "Stage2QuakeSfx", STAGE2_QUAKE_SOUND_PATH, -7.0)
	stage2_boss_cry_sfx = player_factory.create(owner_node, "Stage2BossCrySfx", STAGE2_BOSS_CRY_SOUND_PATH, -6.0)
	stage2_speed_defense_start_sfx = player_factory.create(owner_node, "Stage2SpeedDefenseStartSfx", STAGE2_SPEED_DEFENSE_START_SOUND_PATH, -4.5)
	stage2_speed_defense_hit_sfx = player_factory.create(owner_node, "Stage2SpeedDefenseHitSfx", STAGE2_SPEED_DEFENSE_HIT_SOUND_PATH, -5.0)
	stage2_speed_defense_block_sfx = player_factory.create(owner_node, "Stage2SpeedDefenseBlockSfx", STAGE2_SPEED_DEFENSE_BLOCK_SOUND_PATH, -5.0)
	stage3_tail_sfx = player_factory.create(owner_node, "Stage3TailSfx", STAGE3_TAIL_SOUND_PATH, -4.5)
	stage3_psychoball_sfx = player_factory.create(owner_node, "Stage3PsychoballSfx", STAGE3_PSYCHOBALL_SOUND_PATH, -6.0)
	stage3_dollcurse_sfx = player_factory.create(owner_node, "Stage3DollcurseSfx", STAGE3_DOLLCURSE_SOUND_PATH, -5.0)
	stage3_tears_sfx = player_factory.create(owner_node, "Stage3TearsSfx", STAGE3_TEARS_SOUND_PATH, -7.0)
	stage3_chest_land_sfx = player_factory.create(owner_node, "Stage3ChestLandSfx", STAGE3_CHEST_LAND_SOUND_PATH, -5.0)
	stage3_curse_explode_sfx = player_factory.create(owner_node, "Stage3CurseExplodeSfx", STAGE3_CURSE_EXPLODE_SOUND_PATH, -5.0)
	stage3_kuromi_awake_sfx = player_factory.create(owner_node, "Stage3KuromiAwakeSfx", STAGE3_KUROMI_AWAKE_SOUND_PATH, -3.0)
	stage3_kuromi_stonebreak_sfx = _create_optional_sfx("Stage3KuromiStonebreakSfx", STAGE3_KUROMI_STONEBREAK_SOUND_PATH, -4.0)
	stage3_kuromi_tongue_sfx = player_factory.create(owner_node, "Stage3KuromiTongueSfx", STAGE3_KUROMI_TONGUE_SOUND_PATH, -4.5)
	stage3_kuromi_swallow_sfx = player_factory.create(owner_node, "Stage3KuromiSwallowSfx", STAGE3_KUROMI_SWALLOW_SOUND_PATH, -5.0)
	stage3_kuromi_spit_sfx = player_factory.create(owner_node, "Stage3KuromiSpitSfx", STAGE3_KUROMI_SPIT_SOUND_PATH, -4.0)
	lingpet_ghost_summon_sfx = player_factory.create(owner_node, "LingpetGhostSummonSfx", LINGPET_GHOST_SUMMON_SOUND_PATH, -5.0)
	lingpet_ghost_summon_out_sfx = player_factory.create(owner_node, "LingpetGhostSummonOutSfx", LINGPET_GHOST_SUMMON_OUT_SOUND_PATH, -5.0)
	lingpet_skeleton_archer_summon_sfx = player_factory.create(owner_node, "LingpetSkeletonArcherSummonSfx", LINGPET_SKELETON_ARCHER_SUMMON_SOUND_PATH, -4.4)
	lingpet_skeleton_archer_death_sfx = player_factory.create(owner_node, "LingpetSkeletonArcherDeathSfx", LINGPET_SKELETON_ARCHER_DEATH_SOUND_PATH, -10.5)
	lingpet_skeleton_archer_arrow_fire_sfx = player_factory.create(owner_node, "LingpetSkeletonArcherArrowFireSfx", LINGPET_SKELETON_ARCHER_ARROW_FIRE_SOUND_PATH, -3.1)
	lingpet_skeleton_archer_arrow_hit_sfx = player_factory.create(owner_node, "LingpetSkeletonArcherArrowHitSfx", LINGPET_SKELETON_ARCHER_ARROW_HIT_SOUND_PATH, -3.1)
	lingpet_bone_barrier_build_sfx = player_factory.create(owner_node, "LingpetBoneBarrierBuildSfx", LINGPET_BONE_BARRIER_BUILD_SOUND_PATH, -3.1)
	lingpet_bone_barrier_break_sfx = player_factory.create(owner_node, "LingpetBoneBarrierBreakSfx", LINGPET_BONE_BARRIER_BREAK_SOUND_PATH, -3.1)
	lingpet_bone_barrier_build_break_sfx = player_factory.create(owner_node, "LingpetBoneBarrierBuildBreakSfx", LINGPET_BONE_BARRIER_BUILD_BREAK_SOUND_PATH, -10.5)
	stage4_moon_shoot_sfx = player_factory.create(owner_node, "Stage4MoonShootSfx", STAGE4_MOON_SHOOT_SOUND_PATH, -4.0)
	stage4_fragment_shoot_sfx = player_factory.create(owner_node, "Stage4FragmentShootSfx", STAGE4_FRAGMENT_SHOOT_SOUND_PATH, -5.0)
	stage4_temple_hit_sfx = player_factory.create(owner_node, "Stage4TempleHitSfx", STAGE4_TEMPLE_HIT_SOUND_PATH, -5.0)
	stage4_birdkill_sfx = player_factory.create(owner_node, "Stage4BirdkillSfx", STAGE4_BIRDKILL_SOUND_PATH, -5.0)
	stage4_magnetic_sfx = player_factory.create(owner_node, "Stage4MagneticSfx", STAGE4_MAGNETIC_SOUND_PATH, -7.0)
	stage4_meditation_sfx = player_factory.create(owner_node, "Stage4MeditationSfx", STAGE4_MEDITATION_SOUND_PATH, -5.0)
	stage4_meditation_after_sfx = player_factory.create(owner_node, "Stage4MeditationAfterSfx", STAGE4_MEDITATION_AFTER_SOUND_PATH, -5.0)
	stage5_hongryun_fireball_sfx = player_factory.create(owner_node, "Stage5HongryunFireballSfx", STAGE5_HONGRYUN_FIREBALL_SOUND_PATH, -5.0)
	stage5_hongryun_charge_sfx = player_factory.create(owner_node, "Stage5HongryunChargeSfx", STAGE5_HONGRYUN_CHARGE_SOUND_PATH, -5.0)
	stage5_hongryun_shoot_sfx = player_factory.create(owner_node, "Stage5HongryunShootSfx", STAGE5_HONGRYUN_SHOOT_SOUND_PATH, -5.0)
	stage6_tetriser_break_sfx = player_factory.create(owner_node, "Stage6TetriserBreakSfx", STAGE6_TETRISER_BREAK_SOUND_PATH, -6.0)
	stage6_tetriser_wall_sfx = player_factory.create(owner_node, "Stage6TetriserWallSfx", STAGE6_TETRISER_WALL_SOUND_PATH, -6.0)
	stage6_tetriser_super_sfx = player_factory.create(owner_node, "Stage6TetriserSuperSfx", STAGE6_TETRISER_SUPER_ROAR_SOUND_PATH, -4.0)
	stage6_tetriser_big_sfx = player_factory.create(owner_node, "Stage6TetriserBigSfx", STAGE6_TETRISER_BIG_SOUND_PATH, -4.0)
	stage6_tetriser_shield_sfx = player_factory.create(owner_node, "Stage6TetriserShieldSfx", STAGE6_TETRISER_SHIELD_SOUND_PATH, -5.0)
	stage6_tetriser_laser_sfx = player_factory.create(owner_node, "Stage6TetriserLaserSfx", STAGE6_TETRISER_LASER_SOUND_PATH, -4.0)
	stage7_akamu_shuriken_shoot_sfx = player_factory.create(owner_node, "Stage7AkamuShurikenShootSfx", STAGE7_AKAMU_SHURIKEN_SHOOT_SOUND_PATH, 0.0)
	stage7_akamu_shuriken_hit_sfx = player_factory.create(owner_node, "Stage7AkamuShurikenHitSfx", STAGE7_AKAMU_SHURIKEN_HIT_SOUND_PATH, 0.0)
	stage7_akamu_cloud_sfx = player_factory.create(owner_node, "Stage7AkamuCloudSfx", STAGE7_AKAMU_CLOUD_SOUND_PATH, 0.0)
	stage7_akamu_aura_block_sfx = player_factory.create(owner_node, "Stage7AkamuAuraBlockSfx", STAGE7_AKAMU_AURA_BLOCK_SOUND_PATH, 0.0)
	stage7_akamu_clone_spawn_sfx = player_factory.create(owner_node, "Stage7AkamuCloneSpawnSfx", STAGE7_AKAMU_CLONE_SPAWN_SOUND_PATH, 0.0)
	stage7_akamu_clone_out_sfx = player_factory.create(owner_node, "Stage7AkamuCloneOutSfx", STAGE7_AKAMU_CLONE_OUT_SOUND_PATH, 0.0)
	stage5_hongryun_hurt_sfx.clear()
	for index in range(STAGE5_HONGRYUN_HURT_SOUND_PATHS.size()):
		stage5_hongryun_hurt_sfx.append(player_factory.create(
			owner_node,
			"Stage5HongryunHurtSfx%d" % (index + 1),
			str(STAGE5_HONGRYUN_HURT_SOUND_PATHS[index]),
			-5.0
		))
	leaf_shield_sfx = player_factory.create(owner_node, "LeafShieldSfx", LEAF_SHIELD_SOUND_PATH, -4.5)
	trampoline_bounce_sfx = player_factory.create(owner_node, "TrampolineBounceSfx", TRAMPOLINE_BOUNCE_SOUND_PATH, TRAMPOLINE_BOUNCE_GAIN_DB)
	_enable_loop(stage2_quake_sfx)
	_enable_loop(stage3_psychoball_sfx)
	_enable_loop(stage4_magnetic_sfx)


func _setup_bgm_players() -> void:
	for bgm_name in ["stage1", "stage1_alt", "stage1_alt2", "stage2", "stage2_alt", "stage3", "stage4", "stage4_phase2", "stage5", "stage6", "stage7"]:
		_ensure_bgm_player(str(bgm_name))
	_bgm_setup_step = BGM_SETUP_STEP_COUNT
	_restore_bgm_muted()
	_apply_audio_buses_and_volumes()


func _setup_bgm_players_step() -> bool:
	match _bgm_setup_step:
		0:
			if _should_setup_bgm_player("stage1"):
				_ensure_bgm_player("stage1")
		1:
			if _should_setup_bgm_player("stage1_alt"):
				_ensure_bgm_player("stage1_alt")
		2:
			if _should_setup_bgm_player("stage1_alt2"):
				_ensure_bgm_player("stage1_alt2")
		3:
			if _should_setup_bgm_player("stage2"):
				_ensure_bgm_player("stage2")
		4:
			if _should_setup_bgm_player("stage2_alt"):
				_ensure_bgm_player("stage2_alt")
		5:
			if _should_setup_bgm_player("stage3"):
				_ensure_bgm_player("stage3")
		6:
			if _should_setup_bgm_player("stage4"):
				_ensure_bgm_player("stage4")
		7:
			if _should_setup_bgm_player("stage4_phase2"):
				_ensure_bgm_player("stage4_phase2")
		8:
			if _should_setup_bgm_player("stage5"):
				_ensure_bgm_player("stage5")
		9:
			if _should_setup_bgm_player("stage6"):
				_ensure_bgm_player("stage6")
		10:
			if _should_setup_bgm_player("stage7"):
				_ensure_bgm_player("stage7")
		11:
			_restore_bgm_muted()
		_:
			return true
	_bgm_setup_step += 1
	return _bgm_setup_step >= BGM_SETUP_STEP_COUNT


func _prewarm_audio_setup_streams_step() -> bool:
	var paths: Array[String] = _get_audio_setup_stream_paths(_audio_setup_step)
	if paths.is_empty():
		return true
	if _audio_setup_stream_prewarm_group != _audio_setup_step:
		_audio_setup_stream_prewarm_group = _audio_setup_step
		_audio_setup_stream_prewarm_index = 0
	while _audio_setup_stream_prewarm_index < paths.size():
		var path := str(paths[_audio_setup_stream_prewarm_index])
		_audio_setup_stream_prewarm_index += 1
		if not _should_prewarm_audio_stream(path):
			continue
		if ProjectResourceLoader.get_cached_audio_stream(path) != null:
			continue
		ProjectResourceLoader.load_audio_stream(path)
		return _audio_setup_stream_prewarm_index >= paths.size()
	return true


func _get_audio_setup_step_progress(step: int) -> float:
	if step >= AUDIO_SETUP_STEP_COUNT:
		return 1.0
	if step < 0:
		return 0.0
	var paths: Array[String] = _get_audio_setup_stream_paths(step)
	if not paths.is_empty():
		var stream_progress := 0.0
		if _audio_setup_stream_prewarm_group == step:
			stream_progress = clampf(float(_audio_setup_stream_prewarm_index) / float(paths.size()), 0.0, 1.0)
		if stream_progress < 1.0:
			return stream_progress * 0.92
	if step == 6:
		return 0.92 + 0.08 * clampf(float(_bgm_setup_step) / float(BGM_SETUP_STEP_COUNT), 0.0, 1.0)
	return 0.96


func _get_audio_setup_stream_paths(step: int) -> Array[String]:
	match step:
		0:
			return [
				UI_MOVE_SOUND_PATH,
				UI_CONFIRM_SOUND_PATH,
				UI_BACK_SOUND_PATH,
				UI_PERK_SELECT_SOUND_PATH,
				PADDLE_HIT_SOUND_PATH,
				SERVE_SOUND_PATH,
				PINGPONG_SERVE_SOUND_PATH,
				WALL_HIT_SOUND_PATH,
				DASH_SOUND_PATH,
				HALF_DASH_SOUND_PATH,
				DASH_DELAY_SOUND_PATH,
				DASH_CHARGE_SOUND_PATH,
				BUST_UP_DASH_SOUND_PATH,
				BOOST_CHARGING_SOUND_PATH,
				SOUL_BURST_DASH_SOUND_PATH,
				DASH_SPIRIT_DELETE_SOUND_PATH,
			]
		1:
			return [
				DRIVE_SOUND_PATH,
				MIKA_DRIVE_VOICE_PATH,
				PLASMA_CHARGE_SOUND_PATH,
				PLASMA_SHOOT_SOUND_PATH,
				PLASMA_SHOCK_SOUND_PATH,
				RECOVERY_SOUND_PATH,
				CLEANSE_SOUND_PATH,
				WARP_GATE_SOUND_PATH,
				MAGNUM_GRIP_SOUND_PATH,
				SMASHER_WHEEL_SOUND_PATH,
				SHIELD_KITING_WIND_UP_SOUND_PATH,
				SHIELD_KITING_LAUNCH_SOUND_PATH,
				SHIELD_KITING_HIT_SOUND_PATH,
				WHIP_SOUND_PATH,
				FAN_SOUND_PATH,
				WHIPCRACK_SOUND_PATH,
				VIPER_JETPACK_SOUND_PATH,
				VIPER_BACKSTEP_SOUND_PATH,
				VIPER_SHADOW_KICK_SOUND_PATH,
				VIPER_DIVE_PREP_SOUND_PATH,
				VIPER_DIVE_STRIKE_SOUND_PATH,
				VIPER_IGNITION_AURA_SOUND_PATH,
				VIPER_IGNITION_AURA_FALLBACK_SOUND_PATH,
				VIPER_PHANTOM_SHOW_SOUND_PATH,
				VIPER_PHANTOM_KICK_HIT_SOUND_PATH,
				VIPER_BLADE_SOUND_PATH,
				VIPER_BLADE_SPIN_SOUND_PATH,
				VIPER_VENOM_MOVING_SOUND_PATH,
				VIPER_VENOM_ATTACK_SOUND_PATH,
				VIPER_HWARANG_KICK_SOUND_PATH,
				VIPER_KICK_GUARD_KNOCKBACK_SOUND_PATH,
				VIPER_DUAL_GLITCH_WINDUP_SOUND_PATH,
				VIPER_DUAL_GLITCH_SPLIT_SOUND_PATH,
				CHAOS_SPEAR_WINDUP_SOUND_PATH,
				CHAOS_SPEAR_FLYING_SOUND_PATH,
				CHAOS_SPEAR_IMPACT_SOUND_PATH,
				CHAOS_SPEAR_BLACKHOLE_SOUND_PATH,
			]
		2:
			return [
				COMMANDO_SUPPLY_RADIO_SOUND_PATH,
				COMMANDO_SUPPLY_AIRCRAFT_SOUND_PATH,
				COMMANDO_WEAPON_CHANGE_SOUND_PATH,
				COMMANDO_SLINGSHOT_FIRE_SOUND_PATH,
				COMMANDO_PISTOL_READY_SOUND_PATH,
				COMMANDO_PISTOL_FIRE_SOUND_PATH,
				COMMANDO_PISTOL_RELOAD_START_SOUND_PATH,
				COMMANDO_PISTOL_RELOAD_SOUND_PATH,
				COMMANDO_RELOAD_SOUND_PATH,
				COMMANDO_AK47_FIRE_SOUND_PATH,
				COMMANDO_BAZOOKA_FIRE_SOUND_PATH,
				COMMANDO_NET_CAPTURE_SOUND_PATH,
				COMMANDO_BOWLING_TRAP_INSTALL_SOUND_PATH,
				COMMANDO_BOWLING_TRAP_SNAP_SOUND_PATH,
				COMMANDO_SUICIDE_DRONE_SOUND_PATH,
			]
		3:
			return [
				ITEM_GET_SOUND_PATH,
				DRINK_SOUND_PATH,
				ACTIVE_ITEM_SOUND_PATH,
				TRADE_SOUND_PATH,
				BRICK_WALL_DESTROY_SOUND_PATH,
				TREASURE_HUNT_MINING_SOUND_PATH,
				ALCHEMY_SOUND_PATH,
				PANDORA_SOUND_PATH,
				LUCKY_COIN_SPAWN_SOUND_PATH,
				FOUL_WHISTLE_SOUND_PATH,
				MEGINGJORD_SOUND_PATH,
				LEGENDARY_OPEN_SOUND_PATH,
				ANGEL_BLESSING_ROLL_SOUND_PATH,
				ANGEL_BLESSING_ABSORB_SOUND_PATH,
				RESULT_BOX_OPEN_SOUND_PATH,
				DEFEAT_JEWEL_SOUND_PATH,
				DEFEAT_GEM_SHATTER_SOUND_PATH,
				LINGPET_ACQUIRE_CUTIN_SOUND_PATH,
				LINGPET_ACQUIRE_CLICK_DEEP_BASS_SOUND_PATH,
				LINGPET_ACQUIRE_CLICK_CRACKLE_SWEEP_SOUND_PATH,
				LINGPET_LUNABI_CLICK_VOICE_SOUND_PATH,
				LINGPET_VOLTY_CLICK_VOICE_SOUND_PATH,
				LINGPET_MILKRING_CLICK_VOICE_SOUND_PATH,
				LINGPET_RED_DRAGON_CLICK_VOICE_SOUND_PATH,
				LINGPET_PUPPET_GRAB_CAST_SOUND_PATH,
				LINGPET_PUPPET_GRAB_PULL_SOUND_PATH,
				LINGPET_PUPPET_GRAB_KISS_SOUND_PATH,
				LINGPET_PUPPET_GRAB_MISS_SOUND_PATH,
				LINGPET_SAND_PRISON_OPEN_SOUND_PATH,
				LINGPET_WILD_ROAR_SOUND_PATH,
				LINGPET_STAR_COIL_BIND_SOUND_PATH,
				LINGPET_RING_DASH_SOUND_PATH,
				LINGPET_AFFINITY_LEVEL_UP_SOUND_PATH,
				str(LINGPET_EGG_HIT_SOUND_PATHS[0]),
				str(LINGPET_EGG_HIT_SOUND_PATHS[1]),
				LEGENDARY_AFTER_SOUND_PATH,
				LEGENDARY_ENDING_SOUND_PATH,
				RAGNAROK_SHOT_SOUND_PATH,
				RAGNAROK_BOOM_SOUND_PATH,
				RAGNAROK_SHOCK_SOUND_PATH,
				ELECTRIC_SHOCK_SOUND_PATH,
				THUNDER_ORB_SHOT_SOUND_PATH,
				THUNDER_ORB_BOOM_SOUND_PATH,
				SOLAR_BOLT_STRIKE_SOUND_PATH,
				POSEIDON_WAVE_SOUND_PATH,
				POSEIDON_CHARGE_SOUND_PATH,
				TIMEWATCH_SOUND_PATH,
				THROW_BEFORE_SOUND_PATH,
				THROW_SOUND_PATH,
				HORN_STRAWBERRY_CHANGE_SOUND_PATH,
				HORN_STRAWBERRY_EAT_SOUND_PATH,
				HORN_STRAWBERRY_STEM_FIRE_SOUND_PATH,
				HORN_STRAWBERRY_STEM_HIT_SOUND_PATH,
				HORN_STRAWBERRY_HORN_CHARGE_SOUND_PATH,
				HORN_STRAWBERRY_FIELD_BUILD_SOUND_PATH,
				HORN_STRAWBERRY_FIELD_BREAK_SOUND_PATH,
				HORN_STRAWBERRY_FIELD_BUILD_BREAK_SOUND_PATH,
				HORN_STRAWBERRY_BOMB_TRIGGER_SOUND_PATH,
			]
		4:
			return [
				GRENADE_SOUND_PATH,
				FLASHBOMB_SOUND_PATH,
				SMOKEBOMB_SOUND_PATH,
				FIREBOMB_SOUND_PATH,
				BOOMERANG_SOUND_PATH,
				BOOMERANG_HIT_SOUND_PATH,
				BOOMERANG_BREAK_SOUND_PATH,
				SHRAPNEL_ARMOR_FIRE_SOUND_PATH,
				SHRAPNEL_ARMOR_HIT_SOUND_PATH,
				BANANA_THROW_SOUND_PATH,
				BANANA_SLIP_SOUND_PATH,
				SOAP_THROW_SOUND_PATH,
				SOAP_LAND_SOUND_PATH,
				SOAP_SLIP_SOUND_PATH,
				SPIDER_MINE_WALK_SOUND_PATH,
				SPIDER_MINE_SETUP_SOUND_PATH,
			]
		5:
			var stage_paths: Array[String] = [
				POWER_SMASH_SOUND_PATH,
				POWER_SMASH_LAUNCH_SOUND_PATH,
				ROUND_SET_SOUND_PATH,
				BALL_SPAWN_INTRO_SOUND_PATH,
				STAGE_LANDING_ZOOM_INTRO_SOUND_PATH,
				BALLOON_POP_SOUND_PATH,
				STAGE1_BALLOON_DOOR_SOUND_PATH,
				STAGE1_BALLOON_MACHINE_SOUND_PATH,
				STAR_COLLECT_SOUND_PATH,
				STAGE2_HYDRO_SOUND_PATH,
				STAGE2_STONEBREAK_SOUND_PATH,
				STAGE2_ROCKHIT_SOUND_PATH,
				STAGE2_ROCK_SPAWN_SOUND_PATH,
				STAGE2_QUAKE_SOUND_PATH,
				STAGE2_BOSS_CRY_SOUND_PATH,
				STAGE2_SPEED_DEFENSE_START_SOUND_PATH,
				STAGE2_SPEED_DEFENSE_HIT_SOUND_PATH,
				STAGE2_SPEED_DEFENSE_BLOCK_SOUND_PATH,
				STAGE3_TAIL_SOUND_PATH,
				STAGE3_PSYCHOBALL_SOUND_PATH,
				STAGE3_DOLLCURSE_SOUND_PATH,
				STAGE3_TEARS_SOUND_PATH,
				STAGE3_CHEST_LAND_SOUND_PATH,
				STAGE3_CURSE_EXPLODE_SOUND_PATH,
				STAGE3_KUROMI_AWAKE_SOUND_PATH,
				STAGE3_KUROMI_STONEBREAK_SOUND_PATH,
				STAGE3_KUROMI_TONGUE_SOUND_PATH,
				STAGE3_KUROMI_SWALLOW_SOUND_PATH,
				STAGE3_KUROMI_SPIT_SOUND_PATH,
				LINGPET_GHOST_SUMMON_SOUND_PATH,
				LINGPET_GHOST_SUMMON_OUT_SOUND_PATH,
				LINGPET_SKELETON_ARCHER_SUMMON_SOUND_PATH,
				LINGPET_SKELETON_ARCHER_DEATH_SOUND_PATH,
				LINGPET_SKELETON_ARCHER_ARROW_FIRE_SOUND_PATH,
				LINGPET_SKELETON_ARCHER_ARROW_HIT_SOUND_PATH,
				LINGPET_BONE_BARRIER_BUILD_SOUND_PATH,
				LINGPET_BONE_BARRIER_BREAK_SOUND_PATH,
				LINGPET_BONE_BARRIER_BUILD_BREAK_SOUND_PATH,
				STAGE4_MOON_SHOOT_SOUND_PATH,
				STAGE4_FRAGMENT_SHOOT_SOUND_PATH,
				STAGE4_TEMPLE_HIT_SOUND_PATH,
				STAGE4_BIRDKILL_SOUND_PATH,
				STAGE4_MAGNETIC_SOUND_PATH,
				STAGE4_MEDITATION_SOUND_PATH,
				STAGE4_MEDITATION_AFTER_SOUND_PATH,
				STAGE5_HONGRYUN_FIREBALL_SOUND_PATH,
				STAGE5_HONGRYUN_CHARGE_SOUND_PATH,
				STAGE5_HONGRYUN_SHOOT_SOUND_PATH,
				STAGE7_AKAMU_SHURIKEN_SHOOT_SOUND_PATH,
				STAGE7_AKAMU_SHURIKEN_HIT_SOUND_PATH,
				STAGE7_AKAMU_CLOUD_SOUND_PATH,
				STAGE7_AKAMU_AURA_BLOCK_SOUND_PATH,
				STAGE7_AKAMU_CLONE_SPAWN_SOUND_PATH,
				STAGE7_AKAMU_CLONE_OUT_SOUND_PATH,
				LEAF_SHIELD_SOUND_PATH,
				TRAMPOLINE_BOUNCE_SOUND_PATH,
			]
			for voice_path in MIKA_POWER_SMASHING_VOICE_PATHS:
				stage_paths.append(str(voice_path))
			for voice_path in MIKA_GHOST_SMASHING_VOICE_PATHS:
				stage_paths.append(str(voice_path))
			for hurt_path in STAGE5_HONGRYUN_HURT_SOUND_PATHS:
				stage_paths.append(str(hurt_path))
			return stage_paths
		6:
			return _get_required_bgm_stream_paths()
	return []


func _get_required_bgm_stream_paths() -> Array[String]:
	var paths: Array[String] = []
	for bgm_name in ["stage1", "stage1_alt", "stage1_alt2", "stage2", "stage2_alt", "stage3", "stage4", "stage4_phase2", "stage5", "stage6", "stage7"]:
		var bgm_key := str(bgm_name)
		if _should_setup_bgm_player(bgm_key):
			paths.append(_get_bgm_stream_path(bgm_key))
	return paths


func _get_bgm_stream_path(bgm_name: String) -> String:
	if bgm_name == "stage1":
		return STAGE1_BGM_PATH
	if bgm_name == "stage1_alt":
		return STAGE1_ALT_BGM_PATH
	if bgm_name == "stage1_alt2":
		return STAGE1_ALT2_BGM_PATH
	if bgm_name == "stage2":
		return STAGE2_BGM_PATH
	if bgm_name == "stage2_alt":
		return STAGE2_ALT_BGM_PATH
	if bgm_name == "stage3":
		return STAGE3_BGM_PATH
	if bgm_name == "stage4":
		return STAGE4_BGM_PATH
	if bgm_name == "stage4_phase2":
		return STAGE4_PHASE2_BGM_PATH
	if bgm_name == "stage5":
		return STAGE5_BGM_PATH
	if bgm_name == "stage6":
		return STAGE6_BGM_PATH
	if bgm_name == "stage7":
		return STAGE7_BGM_PATH
	return ""


func _should_prewarm_audio_stream(path: String) -> bool:
	return (
		path != ""
		and (FileAccess.file_exists(path) or ProjectResourceLoader.audio_resource_exists(path))
	)


func _is_setup_complete() -> bool:
	if _bgm_setup_step >= BGM_SETUP_STEP_COUNT and _are_all_bgm_players_ready():
		return true
	return _audio_setup_step > 6 and _bgm_setup_step >= BGM_SETUP_STEP_COUNT and _is_required_bgm_player_ready()


func _should_setup_bgm_player(bgm_name: String) -> bool:
	var setup_stage := _get_owner_current_stage()
	if setup_stage == 1:
		return STAGE1_BGM_NAMES.has(bgm_name)
	if setup_stage == 2:
		return bgm_name == "stage2" or bgm_name == "stage2_alt"
	if setup_stage == 3:
		return bgm_name == "stage3"
	if setup_stage == 4:
		return bgm_name == "stage4" or bgm_name == "stage4_phase2"
	if setup_stage == 5:
		return bgm_name == "stage5"
	if setup_stage == 6:
		return bgm_name == "stage6"
	if setup_stage == 7:
		return bgm_name == "stage7"
	return true


func _is_required_bgm_player_ready() -> bool:
	if _should_setup_bgm_player("stage1") and not _is_owned_player_ready(stage1_bgm):
		return false
	if _should_setup_bgm_player("stage1_alt") and not _is_owned_player_ready(stage1_alt_bgm):
		return false
	if _should_setup_bgm_player("stage1_alt2") and not _is_owned_player_ready(stage1_alt2_bgm):
		return false
	if _should_setup_bgm_player("stage2") and not _is_owned_player_ready(stage2_bgm):
		return false
	if _should_setup_bgm_player("stage2_alt") and not _is_owned_player_ready(stage2_alt_bgm):
		return false
	if _should_setup_bgm_player("stage3") and not _is_owned_player_ready(stage3_bgm):
		return false
	if _should_setup_bgm_player("stage4") and not _is_owned_player_ready(stage4_bgm):
		return false
	if _should_setup_bgm_player("stage4_phase2") and not _is_owned_player_ready(stage4_phase2_bgm):
		return false
	if _should_setup_bgm_player("stage5") and not _is_owned_player_ready(stage5_bgm):
		return false
	if _should_setup_bgm_player("stage6") and not _is_owned_player_ready(stage6_bgm):
		return false
	if _should_setup_bgm_player("stage7") and not _is_owned_player_ready(stage7_bgm):
		return false
	return true


func _are_all_bgm_players_ready() -> bool:
	return (
		_is_owned_player_ready(stage1_bgm)
		and _is_owned_player_ready(stage1_alt_bgm)
		and _is_owned_player_ready(stage1_alt2_bgm)
		and _is_owned_player_ready(stage2_bgm)
		and _is_owned_player_ready(stage2_alt_bgm)
		and _is_owned_player_ready(stage3_bgm)
		and _is_owned_player_ready(stage4_bgm)
		and _is_owned_player_ready(stage4_phase2_bgm)
		and _is_owned_player_ready(stage5_bgm)
		and _is_owned_player_ready(stage6_bgm)
		and _is_owned_player_ready(stage7_bgm)
	)


func _get_owner_current_stage() -> int:
	if owner_node == null:
		return 1
	var value: Variant = owner_node.get("current_stage")
	if typeof(value) == TYPE_INT:
		return int(value)
	if typeof(value) == TYPE_FLOAT:
		return int(value)
	return 1


func update(delta: float) -> void:
	paddle_sound_cooldown = max(0.0, paddle_sound_cooldown - delta)
	wall_sound_cooldown = max(0.0, wall_sound_cooldown - delta)


func play_drive() -> void:
	_play_with_pitch(drive_sfx, randf_range(0.98, 1.02))
	_play_with_pitch(mika_drive_voice_sfx, 1.0)


func play_plasma_charge() -> void:
	if plasma_charge_sfx == null or plasma_charge_sfx.stream == null:
		return
	if plasma_charge_sfx.playing:
		return
	plasma_charge_sfx.pitch_scale = 1.0
	plasma_charge_sfx.play()


func stop_plasma_charge() -> void:
	if plasma_charge_sfx != null and plasma_charge_sfx.playing:
		plasma_charge_sfx.stop()


func sync_plasma_charge(active: bool) -> void:
	if active:
		play_plasma_charge()
	else:
		stop_plasma_charge()


func play_plasma_shoot() -> void:
	_play_with_pitch(plasma_shoot_sfx, randf_range(0.98, 1.02))


func play_plasma_shock() -> void:
	if plasma_shock_sfx == null or plasma_shock_sfx.stream == null:
		return
	if plasma_shock_sfx.playing:
		return
	plasma_shock_sfx.pitch_scale = 1.0
	plasma_shock_sfx.play()


func stop_plasma_shock() -> void:
	if plasma_shock_sfx != null and plasma_shock_sfx.playing:
		plasma_shock_sfx.stop()


func sync_plasma_shock(active: bool) -> void:
	if active:
		play_plasma_shock()
	else:
		stop_plasma_shock()


func play_recovery() -> void:
	_play_with_pitch(recovery_sfx, randf_range(0.98, 1.02))


func play_defeat_jewel() -> void:
	_play_with_pitch(defeat_jewel_sfx, randf_range(0.98, 1.02))


func play_defeat_gem_shatter() -> void:
	_play_with_pitch(defeat_gem_shatter_sfx, randf_range(0.97, 1.03))


func play_cleanse() -> void:
	_play_with_pitch(cleanse_sfx, randf_range(0.98, 1.02))


func play_warp_gate_loop() -> void:
	if warp_gate_sfx == null or warp_gate_sfx.stream == null:
		return
	if warp_gate_sfx.playing:
		return
	warp_gate_sfx.pitch_scale = 1.0
	warp_gate_sfx.play()


func stop_warp_gate_loop() -> void:
	if warp_gate_sfx != null and warp_gate_sfx.playing:
		warp_gate_sfx.stop()


func sync_warp_gate_loop(active: bool) -> void:
	if active:
		play_warp_gate_loop()
	else:
		stop_warp_gate_loop()


func play_magnum_grip() -> void:
	if magnum_grip_sfx == null or magnum_grip_sfx.stream == null:
		return
	if magnum_grip_sfx.playing:
		return
	magnum_grip_sfx.pitch_scale = 1.0
	magnum_grip_sfx.play()


func stop_magnum_grip() -> void:
	if magnum_grip_sfx != null and magnum_grip_sfx.playing:
		magnum_grip_sfx.stop()


func sync_magnum_grip(active: bool) -> void:
	if active:
		play_magnum_grip()
	else:
		stop_magnum_grip()


func play_smasher_wheel_loop() -> void:
	if smasher_wheel_sfx == null or smasher_wheel_sfx.stream == null:
		return
	if smasher_wheel_sfx.playing:
		return
	smasher_wheel_sfx.pitch_scale = 1.0
	smasher_wheel_sfx.play()


func stop_smasher_wheel_loop() -> void:
	if smasher_wheel_sfx != null and smasher_wheel_sfx.playing:
		smasher_wheel_sfx.stop()


func sync_smasher_wheel_loop(active: bool) -> void:
	if active:
		play_smasher_wheel_loop()
	else:
		stop_smasher_wheel_loop()


func play_shield_kiting_wind_up() -> void:
	_play_with_pitch(shield_kiting_wind_up_sfx, randf_range(0.98, 1.02))


func stop_shield_kiting_wind_up() -> void:
	if shield_kiting_wind_up_sfx != null and shield_kiting_wind_up_sfx.playing:
		shield_kiting_wind_up_sfx.stop()


func is_shield_kiting_wind_up_playing() -> bool:
	return shield_kiting_wind_up_sfx != null and shield_kiting_wind_up_sfx.playing


func play_shield_kiting_launch() -> void:
	_play_with_pitch(shield_kiting_launch_sfx, randf_range(0.98, 1.02))


func play_shield_kiting_hit() -> void:
	_play_with_pitch(shield_kiting_hit_sfx, randf_range(0.98, 1.02))


func play_whip() -> void:
	_play_with_pitch(whip_sfx, randf_range(0.98, 1.02))


func play_gaksital_fan(volume: float = 0.35) -> void:
	_play_gaksital_fan_layer(volume, randf_range(0.98, 1.02))


func play_whipcrack(volume: float = 0.6) -> void:
	_set_sfx_player_linear_volume(whipcrack_sfx, volume)
	_play_with_pitch(whipcrack_sfx, randf_range(0.98, 1.02))


func stop_whip() -> void:
	if whip_sfx != null and whip_sfx.playing:
		whip_sfx.stop()


func play_viper_jetpack_loop() -> void:
	if viper_jetpack_sfx == null or viper_jetpack_sfx.stream == null:
		return
	if viper_jetpack_sfx.playing:
		return
	viper_jetpack_sfx.pitch_scale = 1.0
	viper_jetpack_sfx.play()


func stop_viper_jetpack_loop() -> void:
	if viper_jetpack_sfx != null and viper_jetpack_sfx.playing:
		viper_jetpack_sfx.stop()


func sync_viper_jetpack_loop(active: bool) -> void:
	if active:
		play_viper_jetpack_loop()
	else:
		stop_viper_jetpack_loop()


func play_thor_shield_open() -> void:
	_play_with_pitch(thor_shield_open_sfx, randf_range(0.98, 1.02))


func play_thor_shield_close() -> void:
	_play_with_pitch(thor_shield_close_sfx, randf_range(0.98, 1.02))


func play_thor_shield_swing() -> void:
	_play_with_pitch(thor_shield_swing_sfx, randf_range(0.98, 1.02))


func play_thor_shield_block() -> void:
	_play_with_pitch(thor_shield_block_sfx, randf_range(0.98, 1.02))


func play_viper_backstep() -> void:
	if not _play_with_pitch(viper_backstep_sfx, randf_range(0.98, 1.02)):
		play_dash_start(true)


func play_viper_shadow_kick() -> void:
	_play_with_pitch(viper_shadow_kick_sfx, randf_range(0.98, 1.02))


func play_viper_marshal_kick() -> void:
	_play_with_pitch(viper_marshal_kick_sfx, randf_range(0.98, 1.02))


func play_viper_dive_prep() -> void:
	_play_with_pitch(viper_dive_prep_sfx, randf_range(0.98, 1.02))


func play_viper_dive_strike() -> void:
	_play_with_pitch(viper_dive_strike_sfx, randf_range(0.98, 1.02))


func play_viper_ignition_aura() -> void:
	if not _play_with_pitch(viper_ignition_aura_sfx, 1.0):
		_play_with_pitch(viper_ignition_aura_fallback_sfx, 1.0)


func play_viper_phantom_show() -> void:
	_play_with_pitch(viper_phantom_show_sfx, randf_range(0.98, 1.02))


func play_viper_phantom_kick_hit() -> void:
	_play_with_pitch(viper_phantom_kick_hit_sfx, randf_range(0.98, 1.02))


func play_viper_blade() -> void:
	_play_with_pitch(viper_blade_sfx, randf_range(0.98, 1.02))


func play_viper_blade_spin() -> void:
	_play_with_pitch(viper_blade_spin_sfx, randf_range(0.98, 1.02))


func stop_viper_blade_spin() -> void:
	if viper_blade_spin_sfx != null and viper_blade_spin_sfx.playing:
		viper_blade_spin_sfx.stop()


func play_viper_venom_moving() -> void:
	_play_with_pitch(viper_venom_moving_sfx, randf_range(0.98, 1.02))


func play_viper_venom_attack() -> void:
	_play_with_pitch(viper_venom_attack_sfx, randf_range(0.98, 1.02))


func play_viper_hwarang_kick() -> void:
	if not _play_with_pitch(viper_hwarang_kick_sfx, randf_range(0.98, 1.02)):
		play_viper_marshal_kick()


func play_viper_kick_guard_knockback() -> void:
	if not _play_with_pitch(viper_kick_guard_knockback_sfx, randf_range(0.98, 1.02)):
		play_stage2_speed_defense_hit()


func play_viper_dual_glitch_windup() -> void:
	_play_with_pitch(viper_dual_glitch_windup_sfx, randf_range(0.98, 1.02))


func stop_viper_dual_glitch_windup() -> void:
	if viper_dual_glitch_windup_sfx != null:
		viper_dual_glitch_windup_sfx.stop()


func play_viper_dual_glitch_split() -> void:
	_play_with_pitch(viper_dual_glitch_split_sfx, randf_range(0.98, 1.02))


func play_chaos_spear_windup() -> void:
	_play_with_pitch(chaos_spear_windup_sfx, randf_range(0.98, 1.02))


func stop_chaos_spear_windup() -> void:
	if chaos_spear_windup_sfx != null and chaos_spear_windup_sfx.playing:
		chaos_spear_windup_sfx.stop()


func play_chaos_spear_flying() -> void:
	_play_with_pitch(chaos_spear_flying_sfx, randf_range(0.98, 1.02))


func stop_chaos_spear_flying() -> void:
	if chaos_spear_flying_sfx != null and chaos_spear_flying_sfx.playing:
		chaos_spear_flying_sfx.stop()


func play_chaos_spear_impact() -> void:
	_play_with_pitch(chaos_spear_impact_sfx, randf_range(0.98, 1.02))


func stop_chaos_spear_impact() -> void:
	if chaos_spear_impact_sfx != null and chaos_spear_impact_sfx.playing:
		chaos_spear_impact_sfx.stop()


func play_chaos_spear_blackhole_loop() -> void:
	if chaos_spear_blackhole_sfx == null or chaos_spear_blackhole_sfx.stream == null:
		return
	if chaos_spear_blackhole_sfx.playing:
		return
	chaos_spear_blackhole_sfx.pitch_scale = 1.0
	chaos_spear_blackhole_sfx.play()


func stop_chaos_spear_blackhole_loop() -> void:
	if chaos_spear_blackhole_sfx != null and chaos_spear_blackhole_sfx.playing:
		chaos_spear_blackhole_sfx.stop()


func sync_chaos_spear_blackhole_loop(active: bool) -> void:
	if active:
		play_chaos_spear_blackhole_loop()
	else:
		stop_chaos_spear_blackhole_loop()


func play_commando_supply_radio() -> void:
	if not _play_with_pitch(commando_supply_radio_sfx, randf_range(0.98, 1.02)):
		play_active_item()


func play_commando_supply_radio_loop() -> void:
	if commando_supply_radio_loop_sfx == null or commando_supply_radio_loop_sfx.stream == null:
		return
	if commando_supply_radio_loop_sfx.playing:
		return
	commando_supply_radio_loop_sfx.pitch_scale = 1.0
	commando_supply_radio_loop_sfx.play()


func stop_commando_supply_radio_loop() -> void:
	if commando_supply_radio_loop_sfx != null and commando_supply_radio_loop_sfx.playing:
		commando_supply_radio_loop_sfx.stop()


func sync_commando_supply_radio_loop(active: bool) -> void:
	if active:
		play_commando_supply_radio_loop()
	else:
		stop_commando_supply_radio_loop()


func play_commando_supply_aircraft_loop() -> void:
	if commando_supply_aircraft_sfx == null or commando_supply_aircraft_sfx.stream == null:
		return
	if commando_supply_aircraft_sfx.playing:
		return
	commando_supply_aircraft_sfx.pitch_scale = 1.0
	commando_supply_aircraft_sfx.play()


func stop_commando_supply_aircraft_loop() -> void:
	if commando_supply_aircraft_sfx != null and commando_supply_aircraft_sfx.playing:
		commando_supply_aircraft_sfx.stop()


func sync_commando_supply_aircraft_loop(active: bool) -> void:
	if active:
		play_commando_supply_aircraft_loop()
	else:
		stop_commando_supply_aircraft_loop()


func play_commando_supply_drop() -> void:
	if not _play_with_pitch(item_get_sfx, randf_range(0.96, 1.03)):
		play_active_item()


func play_commando_weapon_change() -> void:
	if not _play_with_pitch(commando_weapon_change_sfx, randf_range(0.98, 1.02)):
		play_commando_supply_drop()


func play_commando_fire_support_radio() -> void:
	if not _play_with_pitch(commando_fire_support_radio_sfx, randf_range(0.98, 1.02)):
		play_commando_supply_radio()


func play_commando_fire_support_aircraft_loop() -> void:
	if commando_fire_support_aircraft_sfx == null or commando_fire_support_aircraft_sfx.stream == null:
		return
	if commando_fire_support_aircraft_sfx.playing:
		return
	commando_fire_support_aircraft_sfx.pitch_scale = 1.0
	commando_fire_support_aircraft_sfx.play()


func stop_commando_fire_support_aircraft_loop() -> void:
	if commando_fire_support_aircraft_sfx != null and commando_fire_support_aircraft_sfx.playing:
		commando_fire_support_aircraft_sfx.stop()


func sync_commando_fire_support_aircraft_loop(active: bool) -> void:
	if active:
		play_commando_fire_support_aircraft_loop()
	else:
		stop_commando_fire_support_aircraft_loop()


func play_commando_firearm_fire(weapon_id: String) -> void:
	match weapon_id:
		"pistol":
			play_commando_pistol_fire()
		"bazooka":
			play_commando_bazooka_fire()
		"fire_support":
			play_commando_fire_support_radio()
		"suicide_drone":
			play_commando_suicide_drone_launch()
		"net_gun":
			play_commando_net_gun_fire()
		"bowling_trap":
			play_commando_bowling_trap_install()
		"ak47", "commando_pistol":
			if weapon_id == "ak47":
				play_commando_ak47_fire()
			else:
				play_commando_pistol_fire()
		_:
			play_active_item()


func play_commando_firearm_impact(weapon_id: String) -> void:
	match weapon_id:
		"pistol":
			play_commando_bullet_impact()
		"bazooka":
			play_commando_bazooka_impact()
		"fire_support":
			play_commando_fire_support_bomb()
		"suicide_drone":
			play_commando_suicide_drone_explosion()
		"net_gun":
			play_commando_net_gun_capture()
		"bowling_trap":
			play_commando_bowling_trap_snap()
		"ak47", "commando_pistol":
			play_commando_bullet_impact()
		_:
			play_paddle_hit()


func play_commando_slingshot_fire() -> void:
	if not _play_with_pitch(commando_slingshot_fire_sfx, randf_range(0.96, 1.04)):
		play_throw()


func play_commando_pistol_fire() -> void:
	if not _play_with_pitch(commando_pistol_fire_sfx, randf_range(0.98, 1.02)):
		play_shrapnel_armor_fire()


func play_commando_pistol_ready() -> void:
	if not _play_with_pitch(commando_pistol_ready_sfx, randf_range(0.98, 1.02)):
		play_throw_before()


func play_commando_pistol_reload_start() -> void:
	if not _play_with_pitch(commando_pistol_reload_start_sfx, randf_range(0.98, 1.02)):
		if not _play_with_pitch(commando_pistol_reload_sfx, randf_range(0.98, 1.02)):
			play_active_item()


func play_commando_pistol_reload_round() -> void:
	if not _play_with_pitch(commando_pistol_reload_sfx, randf_range(0.98, 1.02)):
		play_commando_pistol_reload_start()


func play_commando_reload() -> void:
	if not _play_with_pitch(commando_reload_sfx, randf_range(0.98, 1.02)):
		play_commando_pistol_reload_start()


func play_commando_ak47_fire() -> void:
	if not _play_commando_ak47_fire_layer(randf_range(0.98, 1.03)):
		play_shrapnel_armor_fire()


func play_commando_bazooka_fire() -> void:
	if not _play_with_pitch(commando_bazooka_fire_sfx, randf_range(0.98, 1.02)):
		play_ragnarok_shot()


func play_commando_net_gun_fire() -> void:
	if not _play_with_pitch(throw_sfx, randf_range(0.90, 0.97)):
		play_throw()


func play_commando_bowling_trap_install() -> void:
	if not _play_with_pitch(commando_bowling_trap_install_sfx, randf_range(0.98, 1.02)):
		play_stage2_rockhit()


func play_commando_suicide_drone_launch() -> void:
	if commando_suicide_drone_sfx != null and commando_suicide_drone_sfx.stream != null:
		if not commando_suicide_drone_sfx.playing:
			commando_suicide_drone_sfx.pitch_scale = 1.0
			commando_suicide_drone_sfx.play()
		return
	if not _play_with_pitch(ragnarok_shot_sfx, randf_range(1.05, 1.12)):
		play_active_item()


func stop_commando_suicide_drone_loop() -> void:
	if commando_suicide_drone_sfx != null and commando_suicide_drone_sfx.playing:
		commando_suicide_drone_sfx.stop()


func sync_commando_suicide_drone_loop(active: bool) -> void:
	if active:
		play_commando_suicide_drone_launch()
	else:
		stop_commando_suicide_drone_loop()


func play_commando_bullet_impact() -> void:
	play_shrapnel_armor_hit()


func play_commando_slingshot_impact() -> void:
	play_stage2_rockhit()


func play_commando_bazooka_impact() -> void:
	play_grenade_explosion()


func play_commando_fire_support_bomb() -> void:
	play_grenade_explosion()


func play_commando_net_gun_capture() -> void:
	if not _play_with_pitch(commando_net_capture_sfx, randf_range(0.98, 1.02)):
		play_boomerang_hit()


func play_commando_net_gun_constrict() -> void:
	if not _play_with_pitch(commando_net_constrict_sfx, randf_range(0.98, 1.02)):
		play_commando_net_gun_capture()


func play_commando_bowling_trap_snap() -> void:
	if not _play_with_pitch(commando_bowling_trap_snap_sfx, randf_range(0.98, 1.02)):
		play_stage2_rockhit()


func play_commando_suicide_drone_explosion() -> void:
	stop_commando_suicide_drone_loop()
	play_grenade_explosion()


func play_item_get() -> void:
	_play_with_pitch(item_get_sfx, randf_range(0.98, 1.02))


func play_drink() -> void:
	_play_with_pitch(drink_sfx, randf_range(0.98, 1.02))


func play_active_item() -> void:
	_play_with_pitch(active_item_sfx, randf_range(0.98, 1.02))


func play_hologram_disk() -> void:
	play_active_item()


func play_trade() -> void:
	_play_with_pitch(trade_sfx, randf_range(0.98, 1.02))


func play_brick_wall_destroy() -> void:
	if not _play_with_pitch(brick_wall_destroy_sfx, randf_range(0.94, 1.06)):
		play_wall_hit(0.0)


func play_treasure_hunt_mining() -> void:
	if not _play_with_pitch(treasure_hunt_mining_sfx, randf_range(0.98, 1.02)):
		play_stage2_rockhit()


func play_alchemy() -> void:
	if not _play_with_pitch(alchemy_sfx, randf_range(0.98, 1.04)):
		play_active_item()


func play_pandora() -> void:
	if not _play_with_pitch(pandora_sfx, randf_range(0.98, 1.02)):
		play_active_item()


func play_lucky_coin_spawn() -> void:
	if not _play_with_pitch(lucky_coin_spawn_sfx, randf_range(0.98, 1.02)):
		play_active_item()


func play_foul_whistle() -> void:
	if not _play_with_pitch(foul_whistle_sfx, randf_range(0.98, 1.02)):
		play_active_item()


func play_leaf_shield() -> void:
	if not _play_with_pitch(leaf_shield_sfx, randf_range(0.96, 1.04)):
		play_active_item()


func play_megingjord() -> void:
	if not _play_with_pitch(megingjord_sfx, randf_range(0.98, 1.02)):
		play_pandora()


func play_legendary_open() -> void:
	if not _play_with_pitch(legendary_open_sfx, randf_range(0.98, 1.02)):
		play_pandora()


func play_angel_blessing_roll() -> void:
	_play_with_pitch(angel_blessing_roll_sfx, 1.0)


func play_angel_blessing_absorb() -> void:
	_play_angel_blessing_absorb_layer()


func stop_angel_blessing_audio() -> void:
	if angel_blessing_roll_sfx != null and angel_blessing_roll_sfx.playing:
		angel_blessing_roll_sfx.stop()
	var players := [angel_blessing_absorb_sfx]
	players.append_array(angel_blessing_absorb_sfx_layers)
	for value: Variant in players:
		if value is AudioStreamPlayer and (value as AudioStreamPlayer).playing:
			(value as AudioStreamPlayer).stop()


func play_result_box_open() -> void:
	if not _play_with_pitch(result_box_open_sfx, randf_range(0.98, 1.03)):
		play_legendary_open()


func play_lingpet_acquire_cutin() -> void:
	if not _play_with_pitch(_ensure_lingpet_acquire_cutin_sfx(), randf_range(0.98, 1.02)):
		play_item_get()


func play_lingpet_acquire_click_reaction_backing() -> void:
	_play_with_pitch(_ensure_lingpet_acquire_click_deep_bass_sfx(), 1.0)
	_play_with_pitch(_ensure_lingpet_acquire_click_crackle_sweep_sfx(), 1.0)


# In-battle companion click-reaction voice. Pet-agnostic at the call site; this
# method owns the per-pet sound mapping. Pets without a dedicated click voice
# play nothing (silent), so callers can always pass the current pet id.
func play_lingpet_click_reaction(pet_id: String) -> void:
	var normalized_pet_id := pet_id.strip_edges().to_lower()
	if normalized_pet_id == "lunabi":
		_play_with_pitch(_ensure_lingpet_lunabi_click_voice_sfx(), randf_range(0.98, 1.02))
	elif normalized_pet_id == "volty":
		_play_with_pitch(_ensure_lingpet_volty_click_voice_sfx(), randf_range(0.98, 1.02))
	elif normalized_pet_id == "milkring":
		_play_with_pitch(_ensure_lingpet_milkring_click_voice_sfx(), randf_range(0.98, 1.02))
	elif normalized_pet_id == "red_dragon":
		_play_with_pitch(_ensure_lingpet_red_dragon_click_voice_sfx(), randf_range(0.98, 1.02))
	elif normalized_pet_id == "maribo":
		_play_with_pitch(_ensure_lingpet_maribo_click_voice_sfx(), randf_range(0.98, 1.02))
	elif normalized_pet_id == "rabi":
		_play_with_pitch(_ensure_lingpet_rabi_click_voice_sfx(), randf_range(0.98, 1.02))
	elif normalized_pet_id == "lumion":
		_play_with_pitch(_ensure_lingpet_lumion_click_voice_sfx(), randf_range(0.98, 1.02))
	elif normalized_pet_id == "monkeyring":
		_play_with_pitch(_ensure_lingpet_monkeyring_click_voice_sfx(), randf_range(0.98, 1.02))
	elif normalized_pet_id == "onimaru":
		_play_with_pitch(_ensure_lingpet_onimaru_click_voice_sfx(), randf_range(0.98, 1.02))
	elif normalized_pet_id == "orosha":
		_play_with_pitch(_ensure_lingpet_orosha_click_voice_sfx(), randf_range(0.98, 1.02))
	elif normalized_pet_id == "koyora":
		_play_with_pitch(_ensure_lingpet_koyora_click_voice_sfx(), randf_range(0.98, 1.02))


func play_lingpet_puppet_grab_cast() -> void:
	if not _play_with_pitch(lingpet_puppet_grab_cast_sfx, randf_range(0.98, 1.02)):
		play_active_item()


func play_lingpet_puppet_grab_pull() -> void:
	if not _play_with_pitch(lingpet_puppet_grab_pull_sfx, randf_range(0.98, 1.02)):
		play_active_item()


func play_lingpet_puppet_grab_kiss() -> void:
	if not _play_with_pitch(lingpet_puppet_grab_kiss_sfx, randf_range(0.98, 1.02)):
		play_active_item()


func play_lingpet_puppet_grab_miss() -> void:
	if not _play_with_pitch(lingpet_puppet_grab_miss_sfx, randf_range(0.98, 1.02)):
		play_active_item()


func play_lingpet_sand_prison_cast() -> void:
	if not _play_with_pitch(lingpet_sand_prison_open_sfx, randf_range(0.97, 1.03)):
		play_active_item()


func play_lingpet_wild_roar() -> void:
	if not _play_with_pitch(lingpet_wild_roar_sfx, randf_range(0.96, 1.04)):
		play_active_item()


func play_lingpet_star_coil_bind() -> void:
	if not _play_with_pitch(lingpet_star_coil_bind_sfx, randf_range(0.97, 1.03)):
		play_active_item()


func stop_lingpet_star_coil_bind() -> void:
	if lingpet_star_coil_bind_sfx != null and lingpet_star_coil_bind_sfx.playing:
		lingpet_star_coil_bind_sfx.stop()


func play_lingpet_star_coil_move() -> void:
	if lingpet_star_coil_move_sfx == null or lingpet_star_coil_move_sfx.stream == null:
		return
	if lingpet_star_coil_move_sfx.playing:
		return
	lingpet_star_coil_move_sfx.pitch_scale = 1.0
	lingpet_star_coil_move_sfx.play()


func stop_lingpet_star_coil_move() -> void:
	if lingpet_star_coil_move_sfx != null and lingpet_star_coil_move_sfx.playing:
		lingpet_star_coil_move_sfx.stop()


func play_lingpet_dwarf_magic_cast() -> void:
	if not _play_with_pitch(lingpet_dwarf_magic_cast_sfx, randf_range(0.97, 1.03)):
		play_active_item()


func play_lingpet_dwarf_magic_hit() -> void:
	if not _play_with_pitch(lingpet_dwarf_magic_hit_sfx, randf_range(0.97, 1.03)):
		play_active_item()


func play_lingpet_gravity_accel_cast() -> void:
	if not _play_with_pitch(lingpet_gravity_accel_cast_sfx, randf_range(0.97, 1.03)):
		play_active_item()


func play_lingpet_ring_dash() -> void:
	if not _play_with_pitch(lingpet_ring_dash_sfx, randf_range(0.97, 1.03)):
		play_active_item()


func play_lingpet_affinity_level_up() -> void:
	if not _play_with_pitch(lingpet_affinity_level_up_sfx, randf_range(0.99, 1.01)):
		play_item_get()


func play_lingpet_egg_hit() -> void:
	# 링펫알이 공에 맞을 때: 뼈 부러지는 임팩트 2종 중 하나를 랜덤 재생(피치 지터)해
	# 연속 히트가 똑같이 들리지 않게 한다.
	_play_random_stream_with_pitch(lingpet_egg_hit_sfx, lingpet_egg_hit_streams, randf_range(0.94, 1.06))


func play_lingpet_doll_curse() -> void:
	if not _play_with_pitch(stage3_dollcurse_sfx, randf_range(0.97, 1.03)):
		play_active_item()


func play_legendary_after() -> void:
	if not _play_with_pitch(legendary_after_sfx, randf_range(0.98, 1.02)):
		play_pandora()


func stop_legendary_after() -> void:
	if legendary_after_sfx != null and legendary_after_sfx.playing:
		legendary_after_sfx.stop()


func play_legendary_ending() -> void:
	if not _play_with_pitch(legendary_ending_sfx, randf_range(0.98, 1.02)):
		play_item_get()


func play_rainbow_fur_glove() -> void:
	if not _play_with_pitch(active_item_sfx, randf_range(1.16, 1.28)):
		play_active_item()


func play_poseidon_wave() -> void:
	if not _play_with_pitch(poseidon_wave_sfx, randf_range(0.97, 1.03)):
		play_active_item()


func play_poseidon_charge() -> void:
	if not _play_with_pitch(poseidon_charge_sfx, randf_range(0.98, 1.02)):
		play_active_item()


func play_ragnarok_shot() -> void:
	if not _play_with_pitch(ragnarok_shot_sfx, randf_range(0.98, 1.02)):
		play_active_item()


func play_ragnarok_boom() -> void:
	if not _play_with_pitch(ragnarok_boom_sfx, randf_range(0.96, 1.03)):
		play_grenade_explosion()


func play_thunder_orb_shot() -> void:
	if not _play_with_pitch(thunder_orb_shot_sfx, 1.0):
		play_active_item()


func play_thunder_orb_boom() -> void:
	if not _play_with_pitch(thunder_orb_boom_sfx, 1.0):
		play_grenade_explosion()


func play_solar_bolt_strike() -> void:
	# Parity: original SolarBolt _sound.play() plays at fixed pitch (no modulation).
	if not _play_with_pitch(solar_bolt_strike_sfx, 1.0):
		play_ragnarok_shot()


func play_mini_spark() -> void:
	# One random spark zap (spark1/2/3) per mini-spark appearance, lightly
	# pitch-jittered so consecutive sparks in a chain do not sound identical.
	_play_random_stream_with_pitch(mini_spark_sfx, mini_spark_streams, randf_range(0.92, 1.08))


func play_ragnarok_shock_loop() -> void:
	if ragnarok_shock_sfx == null or ragnarok_shock_sfx.stream == null:
		return
	if ragnarok_shock_sfx.playing:
		return
	ragnarok_shock_sfx.pitch_scale = 1.0
	ragnarok_shock_sfx.play()


func stop_ragnarok_shock_loop() -> void:
	if ragnarok_shock_sfx != null and ragnarok_shock_sfx.playing:
		ragnarok_shock_sfx.stop()


func sync_ragnarok_shock_loop(active: bool) -> void:
	if active:
		play_ragnarok_shock_loop()
	else:
		stop_ragnarok_shock_loop()


func play_electric_shock_loop() -> void:
	if electric_shock_sfx == null or electric_shock_sfx.stream == null:
		return
	if electric_shock_sfx.playing:
		return
	electric_shock_sfx.pitch_scale = 1.0
	electric_shock_sfx.play()


func stop_electric_shock_loop() -> void:
	if electric_shock_sfx != null and electric_shock_sfx.playing:
		electric_shock_sfx.stop()


func sync_electric_shock_loop(active: bool) -> void:
	if active:
		play_electric_shock_loop()
	else:
		stop_electric_shock_loop()


func play_timewatch() -> void:
	_play_with_pitch(timewatch_sfx, randf_range(0.98, 1.02))


func play_throw_before() -> void:
	_play_with_pitch(throw_before_sfx, randf_range(0.98, 1.02))


func play_throw() -> void:
	_play_with_pitch(throw_sfx, randf_range(0.98, 1.02))


func play_horn_strawberry_change() -> void:
	if not _play_with_pitch(horn_strawberry_change_sfx, 1.0):
		play_megingjord()


func play_horn_strawberry_eat() -> void:
	if not _play_with_pitch(horn_strawberry_eat_sfx, 1.0):
		play_drink()


func stop_horn_strawberry_eat() -> void:
	if horn_strawberry_eat_sfx != null and horn_strawberry_eat_sfx.playing:
		horn_strawberry_eat_sfx.stop()


func play_horn_strawberry_stem_fire() -> void:
	if not _play_with_pitch(horn_strawberry_stem_fire_sfx, 1.0):
		play_shrapnel_armor_fire()


func play_horn_strawberry_stem_hit() -> void:
	if not _play_with_pitch(horn_strawberry_stem_hit_sfx, 1.0):
		play_shrapnel_armor_hit()


func play_horn_strawberry_field() -> void:
	if not _play_with_pitch(horn_strawberry_field_build_sfx, 1.0):
		play_active_item()


func play_horn_strawberry_field_break() -> void:
	if not _play_with_pitch(horn_strawberry_field_break_sfx, 1.0):
		play_active_item()


func play_horn_strawberry_field_build_break() -> void:
	if not _play_with_pitch(horn_strawberry_field_build_break_sfx, 1.0):
		play_active_item()


func play_horn_charge() -> void:
	if not _play_with_pitch(horn_strawberry_horn_charge_sfx, 1.0):
		play_active_item()


func play_horn_strawberry_horn_charge() -> void:
	if not _play_with_pitch(horn_strawberry_horn_charge_sfx, 1.0):
		play_active_item()


func play_horn_strawberry_horn_impact() -> void:
	pass


func play_horn_strawberry_bomb_throw() -> void:
	if not _play_with_pitch(horn_strawberry_bomb_trigger_sfx, 1.0):
		play_horn_strawberry_stem_hit()


func play_horn_strawberry_bomb_explosion() -> void:
	pass


func play_grenade_explosion() -> void:
	_play_with_pitch(grenade_sfx, randf_range(0.98, 1.02))


func play_dynamite_fuse() -> AudioStreamPlayer:
	if owner_node == null:
		return null
	var player: AudioStreamPlayer = player_factory.create(owner_node, "DynamiteFuseSfx", DYNAMITE_FUSE_SOUND_PATH, -4.0)
	if player == null or player.stream == null:
		if player != null:
			player.queue_free()
		return null
	_configure_sfx_player(player)
	player.finished.connect(Callable(player, "queue_free"))
	player.pitch_scale = randf_range(0.98, 1.02)
	player.play()
	return player


func stop_dynamite_fuse(player: Variant) -> void:
	if typeof(player) != TYPE_OBJECT or not is_instance_valid(player):
		return
	if not (player is AudioStreamPlayer):
		return
	var fuse_player: AudioStreamPlayer = player
	if fuse_player.playing:
		fuse_player.stop()
	if fuse_player.is_inside_tree():
		fuse_player.queue_free()


func play_dynamite_explosion() -> void:
	_play_with_pitch(grenade_sfx, randf_range(0.88, 0.96))


func play_molotov_explosion() -> void:
	_play_with_pitch(firebomb_sfx, randf_range(0.95, 1.04))


func play_dragon_breath_fire(_low_volume: bool = false) -> void:
	_play_with_pitch(firebomb_sfx, randf_range(0.92, 1.08))


# Short, higher-pitched fire "deflect" tick for when the breath strikes the ball
# (distinct from the heavier fire whoosh above) so the hit is audibly felt.
func play_dragon_breath_ball_hit() -> void:
	_play_with_pitch(firebomb_sfx, randf_range(1.20, 1.38))


func play_flashbomb() -> void:
	_play_with_pitch(flashbomb_sfx, randf_range(0.98, 1.02))


func play_smokebomb() -> void:
	if not _play_with_pitch(smokebomb_sfx, randf_range(0.96, 1.04)):
		play_active_item()


func play_boomerang_loop() -> void:
	if boomerang_sfx == null or boomerang_sfx.stream == null:
		return
	if boomerang_sfx.playing:
		return
	boomerang_sfx.pitch_scale = 1.0
	boomerang_sfx.play()


func stop_boomerang_loop() -> void:
	if boomerang_sfx != null and boomerang_sfx.playing:
		boomerang_sfx.stop()


func play_boomerang_hit() -> void:
	_play_with_pitch(boomerang_hit_sfx, randf_range(0.98, 1.02))


func play_boomerang_break() -> void:
	_play_with_pitch(boomerang_break_sfx, 1.0)


func play_shrapnel_armor_fire() -> void:
	if not _play_with_pitch(shrapnel_armor_fire_sfx, randf_range(0.96, 1.04)):
		play_throw()


func play_shrapnel_armor_hit() -> void:
	if not _play_with_pitch(shrapnel_armor_hit_sfx, randf_range(0.96, 1.05)):
		play_boomerang_hit()


func play_banana_throw() -> void:
	_play_with_pitch(banana_throw_sfx, randf_range(0.94, 1.02))


func play_banana_slip() -> void:
	_play_with_pitch(banana_slip_sfx, randf_range(0.92, 1.06))


func play_soap_throw() -> void:
	_play_with_pitch(soap_throw_sfx, randf_range(0.94, 1.02))


func play_soap_land() -> void:
	_play_with_pitch(soap_land_sfx, randf_range(0.96, 1.04))


func play_soap_slip() -> void:
	_play_with_pitch(soap_slip_sfx, randf_range(0.92, 1.06))


func play_spider_mine_walk_loop() -> void:
	if spider_mine_walk_sfx == null or spider_mine_walk_sfx.stream == null:
		return
	if spider_mine_walk_sfx.playing:
		return
	spider_mine_walk_sfx.pitch_scale = 1.0
	spider_mine_walk_sfx.play()


func stop_spider_mine_walk_loop() -> void:
	if spider_mine_walk_sfx != null and spider_mine_walk_sfx.playing:
		spider_mine_walk_sfx.stop()


func sync_spider_mine_walk_loop(active: bool) -> void:
	if active:
		play_spider_mine_walk_loop()
	else:
		stop_spider_mine_walk_loop()


func play_spider_mine_setup() -> void:
	_play_with_pitch(spider_mine_setup_sfx, randf_range(0.98, 1.02))


func play_bomb_surprise_attach() -> void:
	_play_with_pitch(bomb_surprise_attach_sfx, 1.0)


func play_bomb_surprise_transfer() -> void:
	_play_with_pitch(bomb_surprise_transfer_sfx, 1.0)


func play_bomb_surprise_tick(use_second_tick: bool, fuse_ratio: float) -> void:
	var player := bomb_surprise_tick2_sfx if use_second_tick else bomb_surprise_tick1_sfx
	var volume_linear := minf(0.4, 0.1 + 0.2 * clampf(fuse_ratio, 0.0, 1.0))
	_set_sfx_player_linear_volume(player, volume_linear)
	_play_with_pitch(player, 1.0)


func play_bomb_surprise_urgent_tick() -> void:
	if bomb_surprise_urgent_tick_sfx == null or bomb_surprise_urgent_tick_sfx.stream == null:
		return
	if bomb_surprise_urgent_tick_sfx.playing:
		return
	bomb_surprise_urgent_tick_sfx.volume_db = BOMB_SURPRISE_URGENT_TICK_GAIN_DB
	bomb_surprise_urgent_tick_sfx.pitch_scale = 1.0
	bomb_surprise_urgent_tick_sfx.play()


func stop_bomb_surprise_urgent_tick() -> void:
	if bomb_surprise_urgent_tick_sfx != null and bomb_surprise_urgent_tick_sfx.playing:
		bomb_surprise_urgent_tick_sfx.stop()


func play_bomb_surprise_explosion(self_explosion: bool) -> void:
	stop_bomb_surprise_urgent_tick()
	var player := bomb_surprise_self_explosion_sfx if self_explosion else bomb_surprise_explosion_sfx
	if not _play_with_pitch(player, 1.0):
		if self_explosion:
			_play_with_pitch(stage3_curse_explode_sfx, 1.0)
		else:
			_play_with_pitch(grenade_sfx, 1.0)


func play_lingpet_gatling_transform() -> void:
	if not _play_with_pitch(lingpet_gatling_transform_sfx, 1.0):
		play_active_item()


func play_lingpet_gatling_fire() -> void:
	_play_with_pitch(lingpet_gatling_fire_sfx, randf_range(0.98, 1.02))


func play_lingpet_gatling_hit() -> void:
	if not _play_with_pitch(lingpet_gatling_hit_sfx, randf_range(0.98, 1.02)):
		play_paddle_hit()


func play_lingpet_gatling_loop() -> void:
	if lingpet_gatling_loop_sfx == null or lingpet_gatling_loop_sfx.stream == null:
		return
	if lingpet_gatling_loop_sfx.playing:
		return
	lingpet_gatling_loop_sfx.pitch_scale = 1.0
	lingpet_gatling_loop_sfx.play()


func stop_lingpet_gatling_loop() -> void:
	if lingpet_gatling_loop_sfx != null and lingpet_gatling_loop_sfx.playing:
		lingpet_gatling_loop_sfx.stop()


func sync_lingpet_gatling_loop(active: bool) -> void:
	if active:
		play_lingpet_gatling_loop()
	else:
		stop_lingpet_gatling_loop()


func play_power_smash() -> void:
	_play_with_pitch(power_smash_sfx, randf_range(0.98, 1.02))


func play_power_smashing_cutin_voice() -> void:
	_play_random_stream_with_pitch(mika_power_smashing_voice_sfx, mika_power_smashing_voice_streams, 1.0)


func play_ghost_smashing_cutin_voice() -> void:
	_play_random_stream_with_pitch(mika_ghost_smashing_voice_sfx, mika_ghost_smashing_voice_streams, 1.0)


func play_power_smash_launch() -> void:
	_play_with_pitch(power_smash_launch_sfx, randf_range(0.98, 1.02))


func play_paddle_hit(source_x: float = PLAYFIELD_CENTER_X) -> void:
	if paddle_sound_cooldown > 0.0:
		return
	_ensure_hit_pan_buses()
	if _play_with_pitch_at(paddle_hit_sfx, randf_range(0.98, 1.02), source_x, paddle_hit_panner):
		paddle_sound_cooldown = PADDLE_HIT_SOUND_COOLDOWN


func play_rally_tier_accent(tier: int, source_x: float = PLAYFIELD_CENTER_X) -> void:
	var clamped_tier: int = clampi(tier, 1, 5)
	var pitch: float = 1.08 + float(clamped_tier) * 0.035
	_ensure_hit_pan_buses()
	_play_with_pitch_at(wall_hit_sfx, pitch, source_x, wall_hit_panner)


func play_serve(ball_visual_type: String = "") -> void:
	var player: AudioStreamPlayer = serve_sfx
	if ball_visual_type == "pingpong" and pingpong_serve_sfx != null and pingpong_serve_sfx.stream != null:
		player = pingpong_serve_sfx
	_play_with_pitch(player, randf_range(0.98, 1.02))


func play_dash_start(is_half: bool) -> void:
	var player: AudioStreamPlayer = half_dash_sfx if is_half else dash_sfx
	_play_with_pitch(player, randf_range(0.98, 1.02))


func play_burst_up_dash() -> void:
	if not _play_with_pitch(bust_up_dash_sfx, randf_range(0.98, 1.03)):
		play_dash_start(false)


func play_dash_charge() -> void:
	_play_with_pitch(dash_charge_sfx, randf_range(0.98, 1.04))


func play_boost_charging() -> void:
	if not _play_with_pitch(boost_charging_sfx, randf_range(0.98, 1.04)):
		play_dash_charge()


func play_soul_burst_dash() -> void:
	if not _play_with_pitch(soul_burst_dash_sfx, randf_range(0.98, 1.03)):
		play_dash_start(false)


func play_dash_spirit_delete() -> void:
	_play_with_pitch(dash_spirit_delete_sfx, randf_range(0.98, 1.02))


func sync_dash_delay(recovering: bool) -> void:
	if recovering:
		play_dash_delay()
	else:
		stop_dash_delay()


func play_dash_delay() -> void:
	if dash_delay_sfx == null or dash_delay_sfx.stream == null:
		return
	if dash_delay_sfx.playing:
		return
	dash_delay_sfx.pitch_scale = 1.0
	dash_delay_sfx.play()


func stop_dash_delay() -> void:
	if dash_delay_sfx != null and dash_delay_sfx.playing:
		dash_delay_sfx.stop()


func play_wall_hit(impact_speed: float = 0.0, source_x: float = PLAYFIELD_CENTER_X) -> void:
	if wall_sound_cooldown > 0.0:
		return
	var pitch: float = clamp(0.94 + impact_speed / 90.0, 0.94, 1.22) * randf_range(0.98, 1.02)
	_ensure_hit_pan_buses()
	if _play_with_pitch_at(wall_hit_sfx, pitch, source_x, wall_hit_panner):
		wall_sound_cooldown = WALL_HIT_SOUND_COOLDOWN


func play_trampoline_bounce(impact_speed: float = 0.0) -> void:
	# Faster incoming ball -> slightly brighter boing, with light per-hit jitter.
	var pitch: float = clamp(0.94 + impact_speed / 90.0, 0.94, 1.14) * randf_range(0.97, 1.03)
	if _play_with_pitch(trampoline_bounce_sfx, pitch):
		return
	# Fallback (asset missing): the original pitched wall-hit springboard cue.
	_ensure_hit_pan_buses()
	var fallback_pitch: float = clamp(1.20 + impact_speed / 60.0, 1.20, 1.48) * randf_range(0.97, 1.03)
	if not _play_with_pitch_at(wall_hit_sfx, fallback_pitch, PLAYFIELD_CENTER_X, wall_hit_panner):
		play_wall_hit(impact_speed)


func play_trampoline_catch() -> void:
	_ensure_hit_pan_buses()
	_play_with_pitch_at(wall_hit_sfx, 0.68 * randf_range(0.96, 1.04), PLAYFIELD_CENTER_X, wall_hit_panner)


func play_round_set() -> void:
	if round_set_sfx == null or round_set_sfx.stream == null:
		return
	if round_set_sfx.playing:
		round_set_sfx.stop()
	round_set_sfx.play()


func play_ball_spawn_intro() -> void:
	if ball_spawn_intro_sfx == null or ball_spawn_intro_sfx.stream == null:
		return
	if ball_spawn_intro_sfx.playing:
		ball_spawn_intro_sfx.stop()
	ball_spawn_intro_sfx.pitch_scale = 1.0
	ball_spawn_intro_sfx.play()


func stop_ball_spawn_intro() -> void:
	if ball_spawn_intro_sfx != null and ball_spawn_intro_sfx.playing:
		ball_spawn_intro_sfx.stop()


func play_stage_landing_zoom_intro() -> void:
	if stage_landing_zoom_intro_sfx == null or stage_landing_zoom_intro_sfx.stream == null:
		return
	if stage_landing_zoom_intro_sfx.playing:
		stage_landing_zoom_intro_sfx.stop()
	stage_landing_zoom_intro_sfx.pitch_scale = 1.0
	stage_landing_zoom_intro_sfx.play()


func play_stage1_balloon_pop() -> void:
	_play_with_pitch(balloon_pop_sfx, randf_range(0.98, 1.04))


func play_hologram_decoy_pop() -> void:
	play_stage1_balloon_pop()


func play_stage1_balloon_door() -> void:
	_play_with_pitch(stage1_balloon_door_sfx, randf_range(0.98, 1.02))


func play_stage1_balloon_machine() -> void:
	_play_with_pitch(stage1_balloon_machine_sfx, randf_range(0.98, 1.02))


func play_starpoint_collect() -> void:
	_play_with_pitch(star_collect_sfx, randf_range(0.98, 1.04))


func play_runtime_perk_choice_open() -> void:
	if not _play_with_pitch(star_collect_sfx, randf_range(1.02, 1.08)):
		play_legendary_open()


func play_stage2_hydro() -> void:
	_play_with_pitch(stage2_hydro_sfx, randf_range(0.98, 1.03))


func play_stage2_stonebreak() -> void:
	_play_with_pitch(stage2_stonebreak_sfx, randf_range(0.94, 1.06))


func play_stage2_stonebreak_for_size(size: float) -> void:
	var pitch := 1.0
	if size <= 45.0:
		pitch = 1.12
	elif size <= 65.0:
		pitch = 1.0
	else:
		pitch = 0.88
	_play_with_pitch(stage2_stonebreak_sfx, pitch + randf_range(-0.04, 0.04))


func play_stage2_rockhit() -> void:
	_play_with_pitch(stage2_rockhit_sfx, randf_range(0.94, 1.08))


func play_stage2_rock_spawn() -> void:
	_play_with_pitch(stage2_rock_spawn_sfx, randf_range(0.95, 1.04))


func play_stage2_boss_cry() -> void:
	_play_with_pitch(stage2_boss_cry_sfx, randf_range(0.96, 1.04))


func play_stage2_speed_defense_start() -> void:
	_play_with_pitch(stage2_speed_defense_start_sfx, randf_range(0.97, 1.03))


func play_stage2_speed_defense_hit() -> void:
	_play_with_pitch(stage2_speed_defense_hit_sfx, randf_range(0.97, 1.04))


func play_stage2_speed_defense_block() -> void:
	_play_with_pitch(stage2_speed_defense_block_sfx, randf_range(0.96, 1.04))


func play_stage2_quake_loop() -> void:
	if stage2_quake_sfx == null or stage2_quake_sfx.stream == null:
		return
	if stage2_quake_sfx.playing:
		return
	stage2_quake_sfx.pitch_scale = 1.0
	stage2_quake_sfx.play()


func stop_stage2_quake_loop() -> void:
	if stage2_quake_sfx != null and stage2_quake_sfx.playing:
		stage2_quake_sfx.stop()


func sync_stage2_quake_loop(active: bool) -> void:
	if active:
		play_stage2_quake_loop()
	else:
		stop_stage2_quake_loop()


func play_stage3_tail() -> void:
	_play_with_pitch(stage3_tail_sfx, randf_range(0.96, 1.04))


func play_stage3_dollcurse() -> void:
	_play_with_pitch(stage3_dollcurse_sfx, randf_range(0.97, 1.03))


func play_stage3_tears() -> void:
	_play_with_pitch(stage3_tears_sfx, randf_range(0.95, 1.06))


func play_stage3_chest_land() -> void:
	_play_with_pitch(stage3_chest_land_sfx, randf_range(0.94, 1.04))


func play_stage3_curse_explode() -> void:
	_play_with_pitch(stage3_curse_explode_sfx, randf_range(0.94, 1.06))


func play_stage3_kuromi_awake() -> void:
	_play_with_pitch(stage3_kuromi_awake_sfx, 1.0)


func play_stage3_kuromi_stonebreak() -> void:
	_play_with_pitch(stage3_kuromi_stonebreak_sfx, 1.0)


func play_stage3_kuromi_tongue() -> void:
	_play_with_pitch(stage3_kuromi_tongue_sfx, randf_range(0.97, 1.03))


func play_stage3_kuromi_swallow() -> void:
	_play_with_pitch(stage3_kuromi_swallow_sfx, randf_range(0.97, 1.03))


func play_stage3_kuromi_spit() -> void:
	_play_with_pitch(stage3_kuromi_spit_sfx, randf_range(0.97, 1.03))


func play_lingpet_ghost_summon() -> void:
	_play_with_pitch(lingpet_ghost_summon_sfx, randf_range(0.97, 1.03))


func play_lingpet_ghost_summon_out() -> void:
	_play_with_pitch(lingpet_ghost_summon_out_sfx, randf_range(0.97, 1.03))


# Skeleton Archer cues play at native pitch (1.0) to match the original pygame
# Sound.play(), which applies no pitch variation.
func play_lingpet_skeleton_archer_summon() -> void:
	_play_with_pitch(lingpet_skeleton_archer_summon_sfx, 1.0)


func play_lingpet_skeleton_archer_death() -> void:
	_play_with_pitch(lingpet_skeleton_archer_death_sfx, 1.0)


func play_lingpet_skeleton_archer_arrow_fire() -> void:
	_play_with_pitch(lingpet_skeleton_archer_arrow_fire_sfx, 1.0)


func play_lingpet_skeleton_archer_arrow_hit() -> void:
	_play_with_pitch(lingpet_skeleton_archer_arrow_hit_sfx, 1.0)


func play_lingpet_bone_barrier_build() -> void:
	_play_with_pitch(lingpet_bone_barrier_build_sfx, 1.0)


func play_lingpet_bone_barrier_break() -> void:
	_play_with_pitch(lingpet_bone_barrier_break_sfx, 1.0)


func play_lingpet_bone_barrier_build_break() -> void:
	_play_with_pitch(lingpet_bone_barrier_build_break_sfx, 1.0)


func play_stage3_psychoball_loop() -> void:
	if stage3_psychoball_sfx == null or stage3_psychoball_sfx.stream == null:
		return
	if stage3_psychoball_sfx.playing:
		return
	stage3_psychoball_sfx.pitch_scale = 1.0
	stage3_psychoball_sfx.play()


func stop_stage3_psychoball_loop() -> void:
	if stage3_psychoball_sfx != null and stage3_psychoball_sfx.playing:
		stage3_psychoball_sfx.stop()


func sync_stage3_psychoball_loop(active: bool) -> void:
	if active:
		play_stage3_psychoball_loop()
	else:
		stop_stage3_psychoball_loop()


func play_stage4_moon_shoot() -> void:
	_play_with_pitch(stage4_moon_shoot_sfx, randf_range(0.97, 1.03))


func play_stage4_fragment_shoot() -> void:
	_play_with_pitch(stage4_fragment_shoot_sfx, randf_range(0.96, 1.04))


func play_stage4_temple_hit() -> void:
	_play_with_pitch(stage4_temple_hit_sfx, randf_range(0.94, 1.05))


func play_stage4_birdkill() -> void:
	_play_with_pitch(stage4_birdkill_sfx, randf_range(0.96, 1.04))


func play_stage4_meditation() -> void:
	_play_with_pitch(stage4_meditation_sfx, 1.0)


func play_stage4_meditation_after() -> void:
	_play_with_pitch(stage4_meditation_after_sfx, 1.0)


func play_stage4_magnetic_loop() -> void:
	if stage4_magnetic_sfx == null or stage4_magnetic_sfx.stream == null:
		return
	if stage4_magnetic_sfx.playing:
		return
	stage4_magnetic_sfx.pitch_scale = 1.0
	stage4_magnetic_sfx.play()


func stop_stage4_magnetic_loop() -> void:
	if stage4_magnetic_sfx != null and stage4_magnetic_sfx.playing:
		stage4_magnetic_sfx.stop()


func sync_stage4_magnetic_loop(active: bool) -> void:
	if active:
		play_stage4_magnetic_loop()
	else:
		stop_stage4_magnetic_loop()


func play_stage5_hongryun_fireball() -> void:
	_play_with_pitch(stage5_hongryun_fireball_sfx, randf_range(0.96, 1.04))


func stop_stage5_hongryun_fireball() -> void:
	if stage5_hongryun_fireball_sfx != null and stage5_hongryun_fireball_sfx.playing:
		stage5_hongryun_fireball_sfx.stop()


func play_stage5_hongryun_charge() -> void:
	_play_with_pitch(stage5_hongryun_charge_sfx, randf_range(0.97, 1.03))


func stop_stage5_hongryun_charge() -> void:
	if stage5_hongryun_charge_sfx != null and stage5_hongryun_charge_sfx.playing:
		stage5_hongryun_charge_sfx.stop()


func play_stage5_hongryun_shoot() -> void:
	_play_with_pitch(stage5_hongryun_shoot_sfx, randf_range(0.96, 1.04))


func stop_stage5_hongryun_shoot() -> void:
	if stage5_hongryun_shoot_sfx != null and stage5_hongryun_shoot_sfx.playing:
		stage5_hongryun_shoot_sfx.stop()


func play_stage6_tetriser_break() -> void:
	_play_with_pitch(stage6_tetriser_break_sfx, randf_range(0.94, 1.06))


func play_stage6_tetriser_wall() -> void:
	_play_with_pitch(stage6_tetriser_wall_sfx, randf_range(0.97, 1.03))


func play_stage6_tetriser_super() -> void:
	_play_with_pitch(stage6_tetriser_super_sfx, 1.0)


func play_stage6_tetriser_big() -> void:
	_play_with_pitch(stage6_tetriser_big_sfx, randf_range(0.96, 1.04))


func play_stage6_tetriser_shield() -> void:
	_play_with_pitch(stage6_tetriser_shield_sfx, randf_range(0.97, 1.03))


func play_stage6_tetriser_laser() -> void:
	_play_with_pitch(stage6_tetriser_laser_sfx, 1.0)


func play_stage7_akamu_shuriken_shoot() -> void:
	_play_with_pitch(stage7_akamu_shuriken_shoot_sfx, randf_range(0.97, 1.03))


func play_stage7_akamu_shuriken_hit() -> void:
	_play_with_pitch(stage7_akamu_shuriken_hit_sfx, randf_range(0.96, 1.04))


func play_stage7_akamu_cloud() -> void:
	_play_with_pitch(stage7_akamu_cloud_sfx, 1.0)


func play_stage7_akamu_wind_aura_block() -> void:
	_play_with_pitch(stage7_akamu_aura_block_sfx, randf_range(0.97, 1.03))


func play_stage7_akamu_clone_spawn() -> void:
	_play_with_pitch(stage7_akamu_clone_spawn_sfx, 1.0)


func play_stage7_akamu_clone_out() -> void:
	_play_with_pitch(stage7_akamu_clone_out_sfx, randf_range(0.96, 1.04))


func play_stage5_hongryun_hurt() -> void:
	var valid_players: Array[AudioStreamPlayer] = []
	for value in stage5_hongryun_hurt_sfx:
		if value is AudioStreamPlayer and (value as AudioStreamPlayer).stream != null:
			valid_players.append(value as AudioStreamPlayer)
	if valid_players.is_empty():
		return
	_play_with_pitch(valid_players[randi() % valid_players.size()], randf_range(0.96, 1.04))


func play_stage4_phase2_bgm() -> bool:
	return play_bgm("stage4_phase2")


func play_stage_bgm(stage: int) -> bool:
	if stage == 1:
		return play_bgm(_select_stage1_bgm_name())
	if stage == 2:
		return play_bgm(_select_stage2_bgm_name())
	if stage == 3:
		return play_bgm("stage3")
	if stage == 4:
		return play_bgm("stage4")
	if stage == 5:
		return play_bgm("stage5")
	if stage == 6:
		return play_bgm("stage6")
	if stage == 7:
		return play_bgm("stage7")
	stop_bgm()
	return false


func prime_stage_bgm(stage: int) -> bool:
	if stage == 1:
		return prime_bgm(_select_stage1_bgm_name())
	if stage == 2:
		return prime_bgm(_select_stage2_bgm_name())
	if stage == 3:
		return prime_bgm("stage3")
	if stage == 4:
		var stage4_ready: bool = prime_bgm("stage4")
		var phase2_ready: bool = prime_bgm("stage4_phase2")
		return stage4_ready or phase2_ready
	if stage == 5:
		return prime_bgm("stage5")
	if stage == 6:
		return prime_bgm("stage6")
	if stage == 7:
		return prime_bgm("stage7")
	return false


func prime_bgm(bgm_name: String) -> bool:
	var player: AudioStreamPlayer = _ensure_bgm_player(bgm_name)
	if player == null or player.stream == null:
		return false
	if bgm_muted:
		current_bgm_name = bgm_name
		muted_bgm_name = bgm_name
		return true
	if player.playing:
		return true
	if not primed_bgm_volumes.has(bgm_name):
		primed_bgm_volumes[bgm_name] = player.volume_db
	player.volume_db = -80.0
	player.pitch_scale = 1.0
	player.play()
	current_bgm_name = bgm_name
	return true


func play_bgm(bgm_name: String) -> bool:
	var player: AudioStreamPlayer = _ensure_bgm_player(bgm_name)
	if player == null or player.stream == null:
		return false
	var target_volume_db: float = player.volume_db
	if primed_bgm_volumes.has(bgm_name):
		target_volume_db = float(primed_bgm_volumes[bgm_name])
	if bgm_muted:
		if player.playing:
			player.stop()
		player.volume_db = target_volume_db
		current_bgm_name = bgm_name
		muted_bgm_name = bgm_name
		primed_bgm_volumes.erase(bgm_name)
		return true
	if current_bgm_name == bgm_name and player.playing:
		player.seek(0.0)
		player.volume_db = target_volume_db
		primed_bgm_volumes.erase(bgm_name)
		return true
	stop_bgm()
	player.volume_db = target_volume_db
	player.pitch_scale = 1.0
	player.play()
	current_bgm_name = bgm_name
	primed_bgm_volumes.erase(bgm_name)
	return true


func stop_bgm() -> void:
	var player: AudioStreamPlayer = _get_bgm_player(current_bgm_name)
	if player != null and player.playing:
		player.stop()
	if primed_bgm_volumes.has(current_bgm_name):
		if player != null:
			player.volume_db = float(primed_bgm_volumes[current_bgm_name])
		primed_bgm_volumes.erase(current_bgm_name)
	current_bgm_name = ""
	muted_bgm_name = ""


func toggle_bgm() -> bool:
	return set_bgm_muted(not bgm_muted)


func set_bgm_muted(muted: bool) -> bool:
	if bgm_muted == muted:
		BgmMuteState.set_muted(_get_owner_tree(), bgm_muted)
		return bgm_muted
	bgm_muted = BgmMuteState.set_muted(_get_owner_tree(), muted)
	if bgm_muted:
		muted_bgm_name = current_bgm_name
		var muted_player: AudioStreamPlayer = _get_bgm_player(current_bgm_name)
		if muted_player != null and muted_player.playing:
			muted_player.stop()
		if primed_bgm_volumes.has(current_bgm_name):
			if muted_player != null:
				muted_player.volume_db = float(primed_bgm_volumes[current_bgm_name])
			primed_bgm_volumes.erase(current_bgm_name)
		return true

	var target_bgm_name: String = muted_bgm_name
	if target_bgm_name.is_empty():
		target_bgm_name = current_bgm_name
	muted_bgm_name = ""
	if not target_bgm_name.is_empty():
		current_bgm_name = ""
		play_bgm(target_bgm_name)
	return false


func is_bgm_muted() -> bool:
	return bgm_muted


func _restore_bgm_muted() -> void:
	bgm_muted = BgmMuteState.is_muted(_get_owner_tree())


func _get_owner_tree() -> SceneTree:
	if owner_node != null and owner_node.is_inside_tree():
		return owner_node.get_tree()
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		return main_loop as SceneTree
	return null


func get_current_bgm_name() -> String:
	return current_bgm_name


func get_bgm_volume() -> float:
	return bgm_volume


func set_bgm_volume(value: float) -> float:
	bgm_volume = clampf(value, 0.0, 1.0)
	_apply_bgm_bus_volume()
	return bgm_volume


func get_sfx_volume() -> float:
	return sfx_volume


func set_sfx_volume(value: float) -> float:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_sfx_bus_volume()
	return sfx_volume


func play_ui_move() -> void:
	_play_with_pitch(ui_move_sfx, randf_range(0.96, 1.05))


func play_ui_confirm() -> void:
	_play_with_pitch(ui_confirm_sfx, 1.0)


func play_ui_back() -> void:
	_play_with_pitch(ui_back_sfx, 1.0)


func play_runtime_perk_select() -> void:
	# 퍽 확정 순간의 확인음. 살짝의 피치 지터로 연속 픽이 기계적으로 들리지 않게 한다.
	if not _play_with_pitch(ui_perk_select_sfx, randf_range(0.98, 1.03)):
		play_ui_confirm()


func _play_with_pitch(player: AudioStreamPlayer, pitch: float) -> bool:
	if player == null or player.stream == null:
		return false
	player.pitch_scale = pitch
	if player.playing:
		player.stop()
	player.play()
	return true


func _play_with_pitch_at(player: AudioStreamPlayer, pitch: float, source_x: float, panner: AudioEffectPanner) -> bool:
	if player == null or player.stream == null:
		return false
	if panner != null:
		panner.set_pan(_get_hit_pan_from_source_x(source_x))
	player.pitch_scale = pitch
	if player.playing:
		player.stop()
	player.play()
	return true


func _get_hit_pan_from_source_x(source_x: float) -> float:
	var clamped_x: float = clampf(source_x, PLAYFIELD_LEFT_X, PLAYFIELD_RIGHT_X)
	var half_width: float = maxf((PLAYFIELD_RIGHT_X - PLAYFIELD_LEFT_X) * 0.5, 1.0)
	var normalized_x: float = (clamped_x - PLAYFIELD_CENTER_X) / half_width
	return clampf(normalized_x * HIT_PAN_STRENGTH, -1.0, 1.0)


func _play_random_stream_with_pitch(player: AudioStreamPlayer, streams: Array[AudioStream], pitch: float) -> bool:
	if player == null:
		return false
	var valid_streams: Array[AudioStream] = []
	for stream in streams:
		if stream != null:
			valid_streams.append(stream)
	if valid_streams.is_empty():
		return _play_with_pitch(player, pitch)
	player.stream = valid_streams[randi() % valid_streams.size()]
	return _play_with_pitch(player, pitch)


func _load_audio_stream_candidates(paths: Array) -> Array[AudioStream]:
	var streams: Array[AudioStream] = []
	for path_value in paths:
		var path := str(path_value)
		var stream: AudioStream = ProjectResourceLoader.load_audio_stream(
			path,
			"Missing sound at %s",
			"Failed to load sound at %s"
		)
		if stream != null:
			streams.append(stream)
	return streams


func _set_sfx_player_linear_volume(player: AudioStreamPlayer, volume: float) -> void:
	if player != null:
		player.volume_db = _volume_to_db(volume)


func _play_gaksital_fan_layer(volume: float, pitch: float) -> bool:
	var players := [gaksital_fan_sfx]
	players.append_array(gaksital_fan_sfx_layers)
	var valid_players: Array[AudioStreamPlayer] = []
	for value in players:
		if value is AudioStreamPlayer and (value as AudioStreamPlayer).stream != null:
			valid_players.append(value as AudioStreamPlayer)
	if valid_players.is_empty():
		return false
	var clamped_volume: float = clampf(volume, 0.0, 1.0)
	for offset in range(valid_players.size()):
		var index: int = (gaksital_fan_sfx_cursor + offset) % valid_players.size()
		var player: AudioStreamPlayer = valid_players[index]
		if not player.playing:
			gaksital_fan_sfx_cursor = (index + 1) % valid_players.size()
			_set_sfx_player_linear_volume(player, clamped_volume)
			player.pitch_scale = pitch
			player.play()
			return true
	var fallback_index: int = gaksital_fan_sfx_cursor % valid_players.size()
	var fallback_player: AudioStreamPlayer = valid_players[fallback_index]
	gaksital_fan_sfx_cursor = (fallback_index + 1) % valid_players.size()
	_set_sfx_player_linear_volume(fallback_player, clamped_volume)
	fallback_player.pitch_scale = pitch
	fallback_player.stop()
	fallback_player.play()
	return true


func _play_commando_ak47_fire_layer(pitch: float) -> bool:
	var players := [commando_ak47_fire_sfx]
	players.append_array(commando_ak47_fire_sfx_layers)
	var valid_players: Array[AudioStreamPlayer] = []
	for value in players:
		if value is AudioStreamPlayer and (value as AudioStreamPlayer).stream != null:
			valid_players.append(value as AudioStreamPlayer)
	if valid_players.is_empty():
		return false
	for offset in range(valid_players.size()):
		var index: int = (commando_ak47_fire_sfx_cursor + offset) % valid_players.size()
		var player: AudioStreamPlayer = valid_players[index]
		if not player.playing:
			commando_ak47_fire_sfx_cursor = (index + 1) % valid_players.size()
			player.pitch_scale = pitch
			player.play()
			return true
	var fallback_index: int = commando_ak47_fire_sfx_cursor % valid_players.size()
	var fallback_player: AudioStreamPlayer = valid_players[fallback_index]
	commando_ak47_fire_sfx_cursor = (fallback_index + 1) % valid_players.size()
	fallback_player.pitch_scale = pitch
	fallback_player.stop()
	fallback_player.play()
	return true


func _play_angel_blessing_absorb_layer() -> bool:
	var players := [angel_blessing_absorb_sfx]
	players.append_array(angel_blessing_absorb_sfx_layers)
	var valid_players: Array[AudioStreamPlayer] = []
	for value: Variant in players:
		if value is AudioStreamPlayer and (value as AudioStreamPlayer).stream != null:
			valid_players.append(value as AudioStreamPlayer)
	if valid_players.is_empty():
		return false
	for offset: int in range(valid_players.size()):
		var index: int = (angel_blessing_absorb_sfx_cursor + offset) % valid_players.size()
		var player: AudioStreamPlayer = valid_players[index]
		if player.playing:
			continue
		angel_blessing_absorb_sfx_cursor = (index + 1) % valid_players.size()
		player.pitch_scale = 1.0
		player.play()
		return true
	var fallback_index: int = angel_blessing_absorb_sfx_cursor % valid_players.size()
	var fallback_player: AudioStreamPlayer = valid_players[fallback_index]
	angel_blessing_absorb_sfx_cursor = (fallback_index + 1) % valid_players.size()
	fallback_player.pitch_scale = 1.0
	fallback_player.stop()
	fallback_player.play()
	return true


func _create_optional_sfx(name: String, path: String, volume_db: float) -> AudioStreamPlayer:
	if FileAccess.file_exists(path) or ProjectResourceLoader.audio_resource_exists(path):
		return _configure_sfx_player(player_factory.create(owner_node, name, path, volume_db))
	var player := AudioStreamPlayer.new()
	player.name = name
	player.bus = "Master"
	player.volume_db = volume_db
	if owner_node != null:
		owner_node.add_child(player)
	return _configure_sfx_player(player)


func _create_optional_sfx_layers(name_prefix: String, path: String, volume_db: float, count: int) -> Array:
	var players: Array = []
	for index in range(max(0, count)):
		players.append(_create_optional_sfx("%s%d" % [name_prefix, index + 2], path, volume_db))
	return players


func _ensure_lingpet_acquire_cutin_sfx() -> AudioStreamPlayer:
	if lingpet_acquire_cutin_sfx != null and lingpet_acquire_cutin_sfx.stream != null:
		return lingpet_acquire_cutin_sfx
	lingpet_acquire_cutin_sfx = _create_optional_sfx(
		"LingpetAcquireCutinSfx",
		LINGPET_ACQUIRE_CUTIN_SOUND_PATH,
		LINGPET_ACQUIRE_CUTIN_GAIN_DB
	)
	return lingpet_acquire_cutin_sfx


func _ensure_lingpet_acquire_click_deep_bass_sfx() -> AudioStreamPlayer:
	if lingpet_acquire_click_deep_bass_sfx != null and lingpet_acquire_click_deep_bass_sfx.stream != null:
		return lingpet_acquire_click_deep_bass_sfx
	lingpet_acquire_click_deep_bass_sfx = _create_optional_sfx(
		"LingpetAcquireClickDeepBassSfx",
		LINGPET_ACQUIRE_CLICK_DEEP_BASS_SOUND_PATH,
		LINGPET_ACQUIRE_CLICK_DEEP_BASS_GAIN_DB
	)
	return lingpet_acquire_click_deep_bass_sfx


func _ensure_lingpet_acquire_click_crackle_sweep_sfx() -> AudioStreamPlayer:
	if lingpet_acquire_click_crackle_sweep_sfx != null and lingpet_acquire_click_crackle_sweep_sfx.stream != null:
		return lingpet_acquire_click_crackle_sweep_sfx
	lingpet_acquire_click_crackle_sweep_sfx = _create_optional_sfx(
		"LingpetAcquireClickCrackleSweepSfx",
		LINGPET_ACQUIRE_CLICK_CRACKLE_SWEEP_SOUND_PATH,
		LINGPET_ACQUIRE_CLICK_CRACKLE_SWEEP_GAIN_DB
	)
	return lingpet_acquire_click_crackle_sweep_sfx


func _ensure_lingpet_lunabi_click_voice_sfx() -> AudioStreamPlayer:
	if lingpet_lunabi_click_voice_sfx != null and lingpet_lunabi_click_voice_sfx.stream != null:
		return lingpet_lunabi_click_voice_sfx
	lingpet_lunabi_click_voice_sfx = _create_optional_sfx(
		"LingpetLunabiClickVoiceSfx",
		LINGPET_LUNABI_CLICK_VOICE_SOUND_PATH,
		LINGPET_LUNABI_CLICK_VOICE_GAIN_DB
	)
	return lingpet_lunabi_click_voice_sfx


func _ensure_lingpet_volty_click_voice_sfx() -> AudioStreamPlayer:
	if lingpet_volty_click_voice_sfx != null and lingpet_volty_click_voice_sfx.stream != null:
		return lingpet_volty_click_voice_sfx
	lingpet_volty_click_voice_sfx = _create_optional_sfx(
		"LingpetVoltyClickVoiceSfx",
		LINGPET_VOLTY_CLICK_VOICE_SOUND_PATH,
		LINGPET_VOLTY_CLICK_VOICE_GAIN_DB
	)
	return lingpet_volty_click_voice_sfx


func _ensure_lingpet_milkring_click_voice_sfx() -> AudioStreamPlayer:
	if lingpet_milkring_click_voice_sfx != null and lingpet_milkring_click_voice_sfx.stream != null:
		return lingpet_milkring_click_voice_sfx
	lingpet_milkring_click_voice_sfx = _create_optional_sfx(
		"LingpetMilkringClickVoiceSfx",
		LINGPET_MILKRING_CLICK_VOICE_SOUND_PATH,
		LINGPET_MILKRING_CLICK_VOICE_GAIN_DB
	)
	return lingpet_milkring_click_voice_sfx


func _ensure_lingpet_red_dragon_click_voice_sfx() -> AudioStreamPlayer:
	if lingpet_red_dragon_click_voice_sfx != null and lingpet_red_dragon_click_voice_sfx.stream != null:
		return lingpet_red_dragon_click_voice_sfx
	lingpet_red_dragon_click_voice_sfx = _create_optional_sfx(
		"LingpetRedDragonClickVoiceSfx",
		LINGPET_RED_DRAGON_CLICK_VOICE_SOUND_PATH,
		LINGPET_RED_DRAGON_CLICK_VOICE_GAIN_DB
	)
	return lingpet_red_dragon_click_voice_sfx


func _ensure_lingpet_maribo_click_voice_sfx() -> AudioStreamPlayer:
	if lingpet_maribo_click_voice_sfx != null and lingpet_maribo_click_voice_sfx.stream != null:
		return lingpet_maribo_click_voice_sfx
	lingpet_maribo_click_voice_sfx = _create_optional_sfx(
		"LingpetMariboClickVoiceSfx",
		LINGPET_MARIBO_CLICK_VOICE_SOUND_PATH,
		LINGPET_MARIBO_CLICK_VOICE_GAIN_DB
	)
	return lingpet_maribo_click_voice_sfx


func _ensure_lingpet_rabi_click_voice_sfx() -> AudioStreamPlayer:
	if lingpet_rabi_click_voice_sfx != null and lingpet_rabi_click_voice_sfx.stream != null:
		return lingpet_rabi_click_voice_sfx
	lingpet_rabi_click_voice_sfx = _create_optional_sfx(
		"LingpetRabiClickVoiceSfx",
		LINGPET_RABI_CLICK_VOICE_SOUND_PATH,
		LINGPET_RABI_CLICK_VOICE_GAIN_DB
	)
	return lingpet_rabi_click_voice_sfx


func _ensure_lingpet_lumion_click_voice_sfx() -> AudioStreamPlayer:
	if lingpet_lumion_click_voice_sfx != null and lingpet_lumion_click_voice_sfx.stream != null:
		return lingpet_lumion_click_voice_sfx
	lingpet_lumion_click_voice_sfx = _create_optional_sfx(
		"LingpetLumionClickVoiceSfx",
		LINGPET_LUMION_CLICK_VOICE_SOUND_PATH,
		LINGPET_LUMION_CLICK_VOICE_GAIN_DB
	)
	return lingpet_lumion_click_voice_sfx


func _ensure_lingpet_monkeyring_click_voice_sfx() -> AudioStreamPlayer:
	if lingpet_monkeyring_click_voice_sfx != null and lingpet_monkeyring_click_voice_sfx.stream != null:
		return lingpet_monkeyring_click_voice_sfx
	lingpet_monkeyring_click_voice_sfx = _create_optional_sfx(
		"LingpetMonkeyringClickVoiceSfx",
		LINGPET_MONKEYRING_CLICK_VOICE_SOUND_PATH,
		LINGPET_MONKEYRING_CLICK_VOICE_GAIN_DB
	)
	return lingpet_monkeyring_click_voice_sfx


func _ensure_lingpet_onimaru_click_voice_sfx() -> AudioStreamPlayer:
	if lingpet_onimaru_click_voice_sfx != null and lingpet_onimaru_click_voice_sfx.stream != null:
		return lingpet_onimaru_click_voice_sfx
	lingpet_onimaru_click_voice_sfx = _create_optional_sfx(
		"LingpetOnimaruClickVoiceSfx",
		LINGPET_ONIMARU_CLICK_VOICE_SOUND_PATH,
		LINGPET_ONIMARU_CLICK_VOICE_GAIN_DB
	)
	return lingpet_onimaru_click_voice_sfx


func _ensure_lingpet_orosha_click_voice_sfx() -> AudioStreamPlayer:
	if lingpet_orosha_click_voice_sfx != null and lingpet_orosha_click_voice_sfx.stream != null:
		return lingpet_orosha_click_voice_sfx
	lingpet_orosha_click_voice_sfx = _create_optional_sfx(
		"LingpetOroshaClickVoiceSfx",
		LINGPET_OROSHA_CLICK_VOICE_SOUND_PATH,
		LINGPET_OROSHA_CLICK_VOICE_GAIN_DB
	)
	return lingpet_orosha_click_voice_sfx


func _ensure_lingpet_koyora_click_voice_sfx() -> AudioStreamPlayer:
	if lingpet_koyora_click_voice_sfx != null and lingpet_koyora_click_voice_sfx.stream != null:
		return lingpet_koyora_click_voice_sfx
	lingpet_koyora_click_voice_sfx = _create_optional_sfx(
		"LingpetKoyoraClickVoiceSfx",
		LINGPET_KOYORA_CLICK_VOICE_SOUND_PATH,
		LINGPET_KOYORA_CLICK_VOICE_GAIN_DB
	)
	return lingpet_koyora_click_voice_sfx


func _ensure_bgm_player(bgm_name: String) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = _get_bgm_player(bgm_name)
	if _is_owned_player_ready(player):
		return player
	match bgm_name:
		"stage1":
			stage1_bgm = _create_bgm_player("Stage1Bgm", STAGE1_BGM_PATH, STAGE1_BGM_GAIN)
			return stage1_bgm
		"stage1_alt":
			stage1_alt_bgm = _create_bgm_player("Stage1AltBgm", STAGE1_ALT_BGM_PATH, STAGE1_BGM_GAIN)
			return stage1_alt_bgm
		"stage1_alt2":
			stage1_alt2_bgm = _create_bgm_player("Stage1Alt2Bgm", STAGE1_ALT2_BGM_PATH, STAGE1_BGM_GAIN)
			return stage1_alt2_bgm
		"stage2":
			stage2_bgm = _create_bgm_player("Stage2Bgm", STAGE2_BGM_PATH, STAGE2_BGM_GAIN)
			return stage2_bgm
		"stage2_alt":
			stage2_alt_bgm = _create_bgm_player("Stage2AltBgm", STAGE2_ALT_BGM_PATH, STAGE2_BGM_GAIN)
			return stage2_alt_bgm
		"stage3":
			stage3_bgm = _create_bgm_player("Stage3Bgm", STAGE3_BGM_PATH, STAGE3_BGM_GAIN)
			return stage3_bgm
		"stage4":
			stage4_bgm = _create_bgm_player("Stage4Bgm", STAGE4_BGM_PATH, STAGE4_BGM_GAIN)
			return stage4_bgm
		"stage4_phase2":
			stage4_phase2_bgm = _create_bgm_player("Stage4Phase2Bgm", STAGE4_PHASE2_BGM_PATH, STAGE4_BGM_GAIN)
			return stage4_phase2_bgm
		"stage5":
			stage5_bgm = _create_bgm_player("Stage5Bgm", STAGE5_BGM_PATH, STAGE5_BGM_GAIN)
			return stage5_bgm
		"stage6":
			stage6_bgm = _create_bgm_player("Stage6Bgm", STAGE6_BGM_PATH, STAGE6_BGM_GAIN)
			return stage6_bgm
		"stage7":
			stage7_bgm = _create_bgm_player("Stage7Bgm", STAGE7_BGM_PATH, STAGE7_BGM_GAIN)
			return stage7_bgm
	return null


func _create_bgm_player(name: String, path: String, gain: float) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = player_factory.create(owner_node, name, path, _volume_to_db(gain))
	_enable_loop(player)
	if player != null:
		player.bus = BGM_BUS_NAME
	_apply_bgm_bus_volume()
	return player


func _get_bgm_player(bgm_name: String) -> AudioStreamPlayer:
	if bgm_name == "stage1":
		return stage1_bgm
	if bgm_name == "stage1_alt":
		return stage1_alt_bgm
	if bgm_name == "stage1_alt2":
		return stage1_alt2_bgm
	if bgm_name == "stage2":
		return stage2_bgm
	if bgm_name == "stage2_alt":
		return stage2_alt_bgm
	if bgm_name == "stage3":
		return stage3_bgm
	if bgm_name == "stage4":
		return stage4_bgm
	if bgm_name == "stage4_phase2":
		return stage4_phase2_bgm
	if bgm_name == "stage5":
		return stage5_bgm
	if bgm_name == "stage6":
		return stage6_bgm
	if bgm_name == "stage7":
		return stage7_bgm
	return null


func _apply_audio_buses_and_volumes() -> void:
	_adopt_existing_audio_bus_volumes()
	_ensure_audio_bus(BGM_BUS_NAME)
	_ensure_audio_bus(SFX_BUS_NAME)
	_ensure_hit_pan_buses()
	_apply_bgm_bus_to_players()
	_apply_sfx_bus_to_players()
	_apply_bgm_bus_volume()
	_apply_sfx_bus_volume()


func _adopt_existing_audio_bus_volumes() -> void:
	if audio_bus_volumes_adopted:
		return
	audio_bus_volumes_adopted = true
	bgm_volume = _get_existing_audio_bus_volume(BGM_BUS_NAME, bgm_volume)
	sfx_volume = _get_existing_audio_bus_volume(SFX_BUS_NAME, sfx_volume)


func _get_existing_audio_bus_volume(bus_name: String, fallback: float) -> float:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return fallback
	var volume_db: float = AudioServer.get_bus_volume_db(bus_index)
	if volume_db <= -79.0:
		return 0.0
	return clampf(db_to_linear(volume_db), 0.0, 1.0)


func _apply_bgm_bus_to_players() -> void:
	for player in [stage1_bgm, stage1_alt_bgm, stage1_alt2_bgm, stage2_bgm, stage2_alt_bgm, stage3_bgm, stage4_bgm, stage4_phase2_bgm, stage5_bgm, stage6_bgm, stage7_bgm]:
		if player is AudioStreamPlayer:
			(player as AudioStreamPlayer).bus = BGM_BUS_NAME


func _apply_sfx_bus_to_players() -> void:
	for player in _get_sfx_players():
		if player == null:
			continue
		if player == paddle_hit_sfx:
			(player as AudioStreamPlayer).bus = SFX_PAN_PADDLE_BUS_NAME
		elif player == wall_hit_sfx:
			(player as AudioStreamPlayer).bus = SFX_PAN_WALL_BUS_NAME
		elif player is AudioStreamPlayer:
			(player as AudioStreamPlayer).bus = SFX_BUS_NAME


func _ensure_hit_pan_buses() -> void:
	if AudioServer.get_bus_index(SFX_BUS_NAME) < 0:
		_ensure_audio_bus(SFX_BUS_NAME)
	paddle_hit_panner = _ensure_sfx_pan_bus(SFX_PAN_PADDLE_BUS_NAME, paddle_hit_panner)
	wall_hit_panner = _ensure_sfx_pan_bus(SFX_PAN_WALL_BUS_NAME, wall_hit_panner)


func _ensure_sfx_pan_bus(bus_name: String, current_panner: AudioEffectPanner) -> AudioEffectPanner:
	var bus_index: int = _ensure_audio_bus(bus_name)
	if bus_index < 0:
		return current_panner
	AudioServer.set_bus_send(bus_index, SFX_BUS_NAME)
	AudioServer.set_bus_volume_db(bus_index, 0.0)
	if current_panner != null:
		return current_panner
	var effect_count: int = AudioServer.get_bus_effect_count(bus_index)
	for effect_index in range(effect_count):
		var effect: AudioEffect = AudioServer.get_bus_effect(bus_index, effect_index)
		if effect is AudioEffectPanner:
			var existing_panner: AudioEffectPanner = effect as AudioEffectPanner
			existing_panner.set_pan(0.0)
			return existing_panner
	var panner := AudioEffectPanner.new()
	panner.set_pan(0.0)
	AudioServer.add_bus_effect(bus_index, panner)
	return panner


func _configure_sfx_player(player: AudioStreamPlayer) -> AudioStreamPlayer:
	if player != null:
		_ensure_audio_bus(SFX_BUS_NAME)
		player.bus = SFX_BUS_NAME
		_apply_sfx_bus_volume()
	return player


func _apply_bgm_bus_volume() -> void:
	var bus_index: int = _ensure_audio_bus(BGM_BUS_NAME)
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, _volume_to_db(bgm_volume))


func _apply_sfx_bus_volume() -> void:
	var bus_index: int = _ensure_audio_bus(SFX_BUS_NAME)
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, _volume_to_db(sfx_volume))


func _ensure_audio_bus(bus_name: String) -> int:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		return bus_index
	AudioServer.add_bus(AudioServer.get_bus_count())
	bus_index = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, bus_name)
	return bus_index


func _volume_to_db(volume: float) -> float:
	var clamped: float = clampf(volume, 0.0, 1.0)
	if clamped <= 0.0:
		return -80.0
	return linear_to_db(clamped)


func _get_sfx_players() -> Array:
	return [
		ui_move_sfx,
		ui_confirm_sfx,
		ui_back_sfx,
		ui_perk_select_sfx,
		paddle_hit_sfx,
		serve_sfx,
		pingpong_serve_sfx,
		wall_hit_sfx,
		dash_sfx,
		half_dash_sfx,
		dash_delay_sfx,
		dash_charge_sfx,
		bust_up_dash_sfx,
		boost_charging_sfx,
		soul_burst_dash_sfx,
		dash_spirit_delete_sfx,
		drive_sfx,
		mika_drive_voice_sfx,
		plasma_charge_sfx,
		plasma_shoot_sfx,
		plasma_shock_sfx,
		recovery_sfx,
		cleanse_sfx,
		warp_gate_sfx,
		magnum_grip_sfx,
		smasher_wheel_sfx,
		shield_kiting_wind_up_sfx,
		shield_kiting_launch_sfx,
		shield_kiting_hit_sfx,
		whip_sfx,
		gaksital_fan_sfx,
		whipcrack_sfx,
		thor_shield_open_sfx,
		thor_shield_close_sfx,
		thor_shield_swing_sfx,
		thor_shield_block_sfx,
		viper_jetpack_sfx,
		viper_backstep_sfx,
		viper_shadow_kick_sfx,
		viper_marshal_kick_sfx,
		viper_dive_prep_sfx,
		viper_dive_strike_sfx,
		viper_ignition_aura_sfx,
		viper_ignition_aura_fallback_sfx,
		viper_phantom_show_sfx,
		viper_phantom_kick_hit_sfx,
		viper_blade_sfx,
		viper_blade_spin_sfx,
		viper_venom_moving_sfx,
		viper_venom_attack_sfx,
		viper_hwarang_kick_sfx,
		viper_kick_guard_knockback_sfx,
		viper_dual_glitch_windup_sfx,
		viper_dual_glitch_split_sfx,
		chaos_spear_windup_sfx,
		chaos_spear_flying_sfx,
		chaos_spear_impact_sfx,
		chaos_spear_blackhole_sfx,
		commando_supply_radio_sfx,
		commando_supply_radio_loop_sfx,
		commando_supply_aircraft_sfx,
		commando_fire_support_radio_sfx,
		commando_fire_support_aircraft_sfx,
		commando_slingshot_fire_sfx,
		commando_pistol_ready_sfx,
		commando_pistol_fire_sfx,
		commando_pistol_reload_start_sfx,
		commando_pistol_reload_sfx,
		commando_reload_sfx,
		commando_ak47_fire_sfx,
		commando_bazooka_fire_sfx,
		commando_net_capture_sfx,
		commando_net_constrict_sfx,
		commando_bowling_trap_install_sfx,
		commando_bowling_trap_snap_sfx,
		commando_suicide_drone_sfx,
		item_get_sfx,
		drink_sfx,
		active_item_sfx,
		trade_sfx,
		brick_wall_destroy_sfx,
		treasure_hunt_mining_sfx,
		alchemy_sfx,
		pandora_sfx,
		lucky_coin_spawn_sfx,
		foul_whistle_sfx,
		megingjord_sfx,
		legendary_open_sfx,
		angel_blessing_roll_sfx,
		angel_blessing_absorb_sfx,
		result_box_open_sfx,
		defeat_jewel_sfx,
		defeat_gem_shatter_sfx,
		lingpet_acquire_cutin_sfx,
		lingpet_acquire_click_deep_bass_sfx,
		lingpet_acquire_click_crackle_sweep_sfx,
		lingpet_lunabi_click_voice_sfx,
		lingpet_volty_click_voice_sfx,
		lingpet_milkring_click_voice_sfx,
		lingpet_red_dragon_click_voice_sfx,
		lingpet_maribo_click_voice_sfx,
		lingpet_rabi_click_voice_sfx,
		lingpet_lumion_click_voice_sfx,
		lingpet_monkeyring_click_voice_sfx,
		lingpet_onimaru_click_voice_sfx,
		lingpet_orosha_click_voice_sfx,
		lingpet_koyora_click_voice_sfx,
		lingpet_puppet_grab_cast_sfx,
		lingpet_puppet_grab_pull_sfx,
		lingpet_puppet_grab_kiss_sfx,
		lingpet_puppet_grab_miss_sfx,
		lingpet_sand_prison_open_sfx,
		lingpet_wild_roar_sfx,
		lingpet_star_coil_bind_sfx,
		lingpet_star_coil_move_sfx,
		lingpet_ring_dash_sfx,
		lingpet_affinity_level_up_sfx,
		lingpet_egg_hit_sfx,
		lingpet_gatling_transform_sfx,
		lingpet_gatling_loop_sfx,
		lingpet_gatling_fire_sfx,
		lingpet_gatling_hit_sfx,
		lingpet_dwarf_magic_cast_sfx,
		lingpet_dwarf_magic_hit_sfx,
		lingpet_gravity_accel_cast_sfx,
		legendary_after_sfx,
		legendary_ending_sfx,
		ragnarok_shot_sfx,
		ragnarok_boom_sfx,
		ragnarok_shock_sfx,
		electric_shock_sfx,
		thunder_orb_shot_sfx,
		thunder_orb_boom_sfx,
		solar_bolt_strike_sfx,
		mini_spark_sfx,
		poseidon_wave_sfx,
		poseidon_charge_sfx,
		timewatch_sfx,
		throw_before_sfx,
		throw_sfx,
		horn_strawberry_change_sfx,
		horn_strawberry_eat_sfx,
		horn_strawberry_stem_fire_sfx,
		horn_strawberry_stem_hit_sfx,
		horn_strawberry_horn_charge_sfx,
		horn_strawberry_field_build_sfx,
		horn_strawberry_field_break_sfx,
		horn_strawberry_field_build_break_sfx,
		horn_strawberry_bomb_trigger_sfx,
		grenade_sfx,
		flashbomb_sfx,
		smokebomb_sfx,
		firebomb_sfx,
		boomerang_sfx,
		boomerang_hit_sfx,
		boomerang_break_sfx,
		shrapnel_armor_fire_sfx,
		shrapnel_armor_hit_sfx,
		banana_throw_sfx,
		banana_slip_sfx,
		soap_throw_sfx,
		soap_land_sfx,
		soap_slip_sfx,
		spider_mine_walk_sfx,
		spider_mine_setup_sfx,
		bomb_surprise_attach_sfx,
		bomb_surprise_transfer_sfx,
		bomb_surprise_tick1_sfx,
		bomb_surprise_tick2_sfx,
		bomb_surprise_urgent_tick_sfx,
		bomb_surprise_explosion_sfx,
		bomb_surprise_self_explosion_sfx,
		power_smash_sfx,
		mika_power_smashing_voice_sfx,
		mika_ghost_smashing_voice_sfx,
		power_smash_launch_sfx,
		round_set_sfx,
		ball_spawn_intro_sfx,
		stage_landing_zoom_intro_sfx,
		balloon_pop_sfx,
		stage1_balloon_door_sfx,
		stage1_balloon_machine_sfx,
		star_collect_sfx,
		stage2_hydro_sfx,
		stage2_stonebreak_sfx,
		stage2_rockhit_sfx,
		stage2_rock_spawn_sfx,
		stage2_quake_sfx,
		stage2_boss_cry_sfx,
		stage2_speed_defense_start_sfx,
		stage2_speed_defense_hit_sfx,
		stage2_speed_defense_block_sfx,
		stage3_tail_sfx,
		stage3_psychoball_sfx,
		stage3_dollcurse_sfx,
		stage3_tears_sfx,
		stage3_chest_land_sfx,
		stage3_curse_explode_sfx,
		stage3_kuromi_awake_sfx,
		stage3_kuromi_stonebreak_sfx,
		stage3_kuromi_tongue_sfx,
		stage3_kuromi_swallow_sfx,
		stage3_kuromi_spit_sfx,
		lingpet_ghost_summon_sfx,
		lingpet_ghost_summon_out_sfx,
		stage4_moon_shoot_sfx,
		stage4_fragment_shoot_sfx,
		stage4_temple_hit_sfx,
		stage4_birdkill_sfx,
		stage4_magnetic_sfx,
		stage4_meditation_sfx,
		stage4_meditation_after_sfx,
		stage5_hongryun_fireball_sfx,
		stage5_hongryun_charge_sfx,
		stage5_hongryun_shoot_sfx,
		stage6_tetriser_break_sfx,
		stage6_tetriser_wall_sfx,
		stage6_tetriser_super_sfx,
		stage6_tetriser_big_sfx,
		stage6_tetriser_shield_sfx,
		stage6_tetriser_laser_sfx,
		stage7_akamu_shuriken_shoot_sfx,
		stage7_akamu_shuriken_hit_sfx,
		stage7_akamu_cloud_sfx,
		stage7_akamu_aura_block_sfx,
		stage7_akamu_clone_spawn_sfx,
		stage7_akamu_clone_out_sfx,
		leaf_shield_sfx,
		trampoline_bounce_sfx,
	] + gaksital_fan_sfx_layers + commando_ak47_fire_sfx_layers + angel_blessing_absorb_sfx_layers + stage5_hongryun_hurt_sfx


func _select_stage1_bgm_name() -> String:
	if STAGE1_BGM_NAMES.has(current_bgm_name):
		var current_player: AudioStreamPlayer = _get_bgm_player(current_bgm_name)
		if bgm_muted or (current_player != null and current_player.playing):
			return current_bgm_name
	var candidates: Array[String] = _get_stage1_bgm_candidates()
	if candidates.is_empty():
		return "stage1"
	if candidates.size() == 1:
		return candidates[0]
	if not stage1_bgm_rng_ready:
		stage1_bgm_rng.randomize()
		stage1_bgm_rng_ready = true
	return candidates[stage1_bgm_rng.randi_range(0, candidates.size() - 1)]


func _get_stage1_bgm_candidates() -> Array[String]:
	var candidates: Array[String] = []
	for bgm_name in STAGE1_BGM_NAMES:
		var player: AudioStreamPlayer = _ensure_bgm_player(str(bgm_name))
		if player != null and player.stream != null:
			candidates.append(str(bgm_name))
	return candidates


func _select_stage2_bgm_name() -> String:
	if STAGE2_BGM_NAMES.has(current_bgm_name):
		var current_player: AudioStreamPlayer = _get_bgm_player(current_bgm_name)
		if bgm_muted or (current_player != null and current_player.playing):
			return current_bgm_name
	var candidates: Array[String] = _get_stage2_bgm_candidates()
	if candidates.is_empty():
		return "stage2"
	if candidates.size() == 1:
		return candidates[0]
	if not stage2_bgm_rng_ready:
		stage2_bgm_rng.randomize()
		stage2_bgm_rng_ready = true
	return candidates[stage2_bgm_rng.randi_range(0, candidates.size() - 1)]


func _get_stage2_bgm_candidates() -> Array[String]:
	var candidates: Array[String] = []
	for bgm_name in STAGE2_BGM_NAMES:
		var player: AudioStreamPlayer = _ensure_bgm_player(str(bgm_name))
		if player != null and player.stream != null:
			candidates.append(str(bgm_name))
	return candidates


func _is_owned_player_ready(player: AudioStreamPlayer) -> bool:
	return player != null and is_instance_valid(player) and player.get_parent() == owner_node


func _enable_loop(player: AudioStreamPlayer) -> void:
	if player == null or player.stream == null:
		return
	# ProjectResourceLoader.load_audio_stream caches by path and the player factory
	# assigns that cached AudioStream RAW, so one AudioStream instance can back
	# several players (gravityaccel.wav is shared by chaos_spear_blackhole_sfx AND
	# lingpet_gravity_accel_cast_sfx). Flipping loop_mode on the shared instance
	# force-loops EVERY player pointing at it -- that is what made Serabi's 중력가속
	# one-shot cast cue loop forever and bleed into the next round. Duplicate first
	# so only THIS player's stream loops; every other user keeps the one-shot cache
	# instance untouched.
	var stream: AudioStream = player.stream.duplicate() as AudioStream
	player.stream = stream
	if stream is AudioStreamWAV:
		var wav_stream: AudioStreamWAV = stream
		wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav_stream.loop_begin = 0
		wav_stream.loop_end = max(0, int(round(wav_stream.get_length() * float(wav_stream.mix_rate))))
	elif stream is AudioStreamMP3:
		var mp3_stream: AudioStreamMP3 = stream
		mp3_stream.loop = true
	elif stream is AudioStreamOggVorbis:
		var ogg_stream: AudioStreamOggVorbis = stream
		ogg_stream.loop = true
