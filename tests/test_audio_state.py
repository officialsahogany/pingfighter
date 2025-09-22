import importlib

from game_state import audio


def test_volume_clamping_and_sync():
    # 초기 상태 확인
    importlib.reload(audio)
    assert audio.get_bgm_volume() == 0.4
    assert audio.get_sfx_volume() == 0.7

    # 범위 밖 입력은 클램프된다
    assert audio.set_bgm_volume(1.5) == 1.0
    assert audio.get_bgm_volume() == 1.0
    assert audio.set_sfx_volume(-0.2) == 0.0
    assert audio.get_sfx_volume() == 0.0

    # 정상 범위는 그대로 저장
    assert audio.set_bgm_volume(0.33) == 0.33
    assert audio.get_bgm_volume() == 0.33
    assert audio.set_sfx_volume(0.55) == 0.55
    assert audio.get_sfx_volume() == 0.55

    # export/load 라운드트립
    exported = audio.export_audio_state()
    audio.set_bgm_volume(0.1)
    audio.set_sfx_volume(0.2)
    audio.load_audio_state(exported)
    assert audio.get_bgm_volume() == 0.33
    assert audio.get_sfx_volume() == 0.55
