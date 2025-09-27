"""사운드 이펙트를 일괄 로드하는 헬퍼."""

from __future__ import annotations

from typing import Dict

import pygame

SOUND_PATHS = {
    "SERVE": "sounds/serve.wav",
    "WALL": "sounds/wall_hit.wav",
    "BRICK_DESTROY": "sounds/stonebreak2.wav",
    "PADDLE": "sounds/paddle_hit.wav",
    "QUAKE": "sounds/quake_sound.wav",
    "WHIP": "sounds/whip_effect.wav",
    "AIRPLANE": "sounds/airplane.wav",
    "DEFENSE_HIT": "sounds/defense_hit.wav",
    "DEFENSE_START": "sounds/speed_defense_start.wav",
    "DEFENSE_BLOCK": "sounds/defense_hit.wav",
    "FIREBALL": "sounds/fireball.wav",
    "DASH": "sounds/dash.wav",
    "BURST_UP": "sounds/bustup.wav",
    "DRIVE": "sounds/drive.wav",
    "MEDITATION_AFTER": "sounds/meditationafter.wav",
    "HALF_DASH": "sounds/halfdash.wav",
    "DASH_SPIRIT_DELETE": "sounds/dashspiritdelete.wav",
    "ACTIVE_ITEM": "sounds/activeitem.wav",
    "STONEBREAK_SMALL": "sounds/stonebreak1.wav",
    "STONEBREAK_MEDIUM": "sounds/stonebreak2.wav",
    "STONEBREAK_LARGE": "sounds/stonebreak3.wav",
    "BARRIER": "sounds/barrior.wav",
    "BALLOON_BOOM": "sounds/balloonboom.wav",
    "POWER_SMASH": "sounds/power_smash.wav",
    "POWER_SMASH_LAUNCH": "sounds/power_smash_launch.wav",
    "MISSILE": "sounds/missle.wav",
    "PISTOL_RELOAD_START": "sounds/pistolreloadstart.wav",
    "RAGNAROK_SHOT": "sounds/ragnarokshot.wav",
    "AK47": "sounds/ak47.wav",
    "RAGNAROK_BOOM": "sounds/ragnarokboom.wav",
    "RAGNAROK_SHOCK": "sounds/ragnarokshock.wav",
    "CONSTRUCTION": "sounds/construction.wav",
    "BLACKSMITH_UMBRELLA_SWING": "sounds/swing.wav",
    "BLACKSMITH_UMBRELLA_OPEN": "sounds/umbopen.wav",
    "BLACKSMITH_UMBRELLA_CLOSE": "sounds/umbclose.wav",
    "BLACKSMITH_UMBRELLA_BLOCK": "sounds/blocking.wav",
    "BLACKSMITH_HAMMER_CHARGE": "sounds/hammercharge.wav",
    "BLACKSMITH_HAMMER_THROW": "sounds/hammertrhow.wav",
    "BLACKSMITH_HAMMER_EXPLOSION": "sounds/hammerbomb.wav",
    "STAGE6_BOSS_HIT": "sounds/stage6bosshit.wav",
    "STAGE6_BEAM": "sounds/stage6beam.wav",
    "STAGE6_BEAM_CHARGE": "sounds/stage6beamcharge.wav",
    "STAGE6_INTERCEPTOR_HIT": "sounds/stage6carrior.wav",
    "CRY": "sounds/cry.wav",
    "THROW_BEFORE": "sounds/throwbefore.wav",
    "GRENADE": "sounds/grenade.wav",
    "FIREBOMB": "sounds/firebomb.wav",
    "FLAME": "sounds/flame.wav",
    "SMOKEBOMB": "sounds/smokebomb.wav",
    "FLASHBOMB": "sounds/flashbomb.wav",
    "TIMEWATCH": "sounds/timewatch.wav",
    "PANDORA": "sounds/pandora.wav",
    "DRINK": "sounds/drink.wav",
    "STAGE1_DOOR": "sounds/stage1door.wav",
    "STAGE1_MACHINE": "sounds/stage1muchine.wav",
    "BIRDKILL": "sounds/birdkill.wav",
    "THROW": "sounds/throw.wav",
    "ITEM_GET": "sounds/itemget.wav",
    "NOTIFICATION": "sounds/item_pickup.wav",
    "HONGRYUN_CHARGE": "sounds/hongcharge.wav",
    "HONGRYUN_SHOOT": "sounds/hongshoot.wav",
    "BAZOOKA_GOING": "sounds/bazukagoing.wav",
    "BUTTON_CLICK": "sounds/button_click.wav",
    "BUTTON_HOVER": "sounds/button_hover.wav",
}


def load_sound_effects(resource_path) -> Dict[str, pygame.mixer.Sound]:
    """resource_path 함수를 이용해 사운드 이펙트를 전부 로드."""

    sounds: Dict[str, pygame.mixer.Sound] = {}
    for key, rel_path in SOUND_PATHS.items():
        try:
            full_path = resource_path(rel_path)
            sounds[key] = pygame.mixer.Sound(full_path)
        except Exception as exc:  # pragma: no cover
            print(f"[WARN] Failed to load sound {rel_path}: {exc}")
            sounds[key] = None
    return sounds
