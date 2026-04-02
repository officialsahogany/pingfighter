"""
온라인 멀티플레이 프로토콜 정의
메시지 포맷, 직렬화 헬퍼, 상수
"""

from enum import IntEnum


class OnlinePacketType(IntEnum):
    """온라인 대전 전용 패킷 타입 (기존 PacketType과 충돌 방지: 0x20~)"""
    # 로비
    LOBBY_STATE = 0x20       # 로비 상태 동기화
    CHAR_SELECT = 0x21       # 캐릭터 선택
    STAGE_SELECT = 0x22      # 스테이지/아이템 모드 선택
    LOBBY_READY = 0x23       # 레디 상태
    LOBBY_START = 0x24       # 게임 시작 신호
    LOBBY_CHAT = 0x25        # 로비 채팅 (향후)

    # 게임 진행
    GAME_INPUT = 0x30        # P2 입력 (클라이언트 → 호스트)
    GAME_FRAME = 0x31        # 프레임 상태 (호스트 → 클라이언트)
    GAME_EVENT = 0x32        # 이벤트 (득점, 라운드 시작, 게임 오버)
    GAME_SOUND = 0x33        # 사운드 트리거
    GAME_EFFECT = 0x34       # 이펙트 트리거

    # 연결 관리
    ONLINE_PING = 0x40       # 핑 측정
    ONLINE_PONG = 0x41       # 핑 응답
    ONLINE_DISCONNECT = 0x42 # 정상 종료
    ONLINE_PAUSE = 0x43      # 일시정지 요청


# 기본 설정
DEFAULT_PORT = 12345
MAX_CONNECT_TIMEOUT = 5.0    # 접속 타임아웃 (초)
DISCONNECT_TIMEOUT = 3.0     # 끊김 판정 (초)
RECONNECT_TIMEOUT = 10.0     # 재접속 대기 (초)

# 프레임 전송 주기
FRAME_SEND_RATE = 60         # 초당 상태 전송 횟수
INPUT_SEND_RATE = 60         # 초당 입력 전송 횟수

# 게임 설정
WIN_GOAL_DEFAULT = 5         # 기본 승리 목표
STAGE_MULTIPLAYER = 40       # 멀티플레이 스테이지 번호


def serialize_input(keys_state):
    """클라이언트 입력을 컴팩트하게 직렬화

    Args:
        keys_state: dict with bool values for each action

    Returns:
        dict - 직렬화된 입력
    """
    return {
        'l': keys_state.get('left', False),
        'r': keys_state.get('right', False),
        'u': keys_state.get('up', False),
        'd': keys_state.get('down', False),
        'da': keys_state.get('dash', False),
        'q': keys_state.get('skill_q', False),
        'w': keys_state.get('skill_w', False),
        'e': keys_state.get('skill_e', False),
        'ml': keys_state.get('mouse_left', False),
        'mr': keys_state.get('mouse_right', False),
        'mx': keys_state.get('mouse_x', 0),
        'my': keys_state.get('mouse_y', 0),
    }


def deserialize_input(data):
    """직렬화된 입력을 복원

    Args:
        data: 직렬화된 입력 dict

    Returns:
        dict - 복원된 입력 상태
    """
    return {
        'left': data.get('l', False),
        'right': data.get('r', False),
        'up': data.get('u', False),
        'down': data.get('d', False),
        'dash': data.get('da', False),
        'skill_q': data.get('q', False),
        'skill_w': data.get('w', False),
        'skill_e': data.get('e', False),
        'mouse_left': data.get('ml', False),
        'mouse_right': data.get('mr', False),
        'mouse_x': data.get('mx', 0),
        'mouse_y': data.get('my', 0),
    }


def serialize_game_frame(frame_data):
    """게임 프레임 상태를 컴팩트하게 직렬화

    Args:
        frame_data: dict with game state

    Returns:
        dict - 직렬화된 게임 상태
    """
    return {
        'f': frame_data.get('frame_num', 0),
        'b': frame_data.get('ball', [0, 0, 0, 0]),     # [x, y, vx, vy]
        'p1': frame_data.get('p1', [0, 0, 0]),          # [x, gauge, score]
        'p2': frame_data.get('p2', [0, 0, 0]),          # [x, gauge, score]
        'it': frame_data.get('items', []),               # 필드 아이템
        'snd': frame_data.get('sounds', []),             # 사운드 트리거
        'ef': frame_data.get('effects', []),             # 이펙트
        'go': frame_data.get('game_over', None),         # 게임 종료 (None/"p1"/"p2")
        'ws': frame_data.get('waiting_serve', False),    # 서브 대기
        'ps': frame_data.get('player_serve', False),     # 누구 서브인지
        'rw': frame_data.get('round_wins', 0),
        'rl': frame_data.get('round_losses', 0),
        # P1 상태 상세
        'p1s': frame_data.get('p1_stunned', False),
        'p1d': frame_data.get('p1_dashing', False),
        # P2 상태 상세
        'p2s': frame_data.get('p2_stunned', False),
        'p2d': frame_data.get('p2_dashing', False),
        # 공 추가 상태
        'bs': frame_data.get('ball_spin', 0),
        'bi': frame_data.get('ball_intensity', 0),
        # 애니메이션 상태
        'p1a': frame_data.get('p1_anim', None),
    }


def deserialize_game_frame(data):
    """직렬화된 게임 프레임을 복원"""
    return {
        'frame_num': data.get('f', 0),
        'ball': data.get('b', [0, 0, 0, 0]),
        'p1': data.get('p1', [0, 0, 0]),
        'p2': data.get('p2', [0, 0, 0]),
        'items': data.get('it', []),
        'sounds': data.get('snd', []),
        'effects': data.get('ef', []),
        'game_over': data.get('go', None),
        'waiting_serve': data.get('ws', False),
        'player_serve': data.get('ps', False),
        'round_wins': data.get('rw', 0),
        'round_losses': data.get('rl', 0),
        'p1_stunned': data.get('p1s', False),
        'p1_dashing': data.get('p1d', False),
        'p2_stunned': data.get('p2s', False),
        'p2_dashing': data.get('p2d', False),
        'ball_spin': data.get('bs', 0),
        'p1_anim': data.get('p1a', None),
        'ball_intensity': data.get('bi', 0),
    }


def serialize_lobby_state(lobby_data):
    """로비 상태 직렬화"""
    return {
        'h_char': lobby_data.get('host_character', None),
        'c_char': lobby_data.get('client_character', None),
        'stage': lobby_data.get('stage', 1),
        'items': lobby_data.get('items_enabled', True),
        'h_ready': lobby_data.get('host_ready', False),
        'c_ready': lobby_data.get('client_ready', False),
        'h_name': lobby_data.get('host_name', 'Player 1'),
        'c_name': lobby_data.get('client_name', 'Player 2'),
    }


def deserialize_lobby_state(data):
    """로비 상태 복원"""
    return {
        'host_character': data.get('h_char', None),
        'client_character': data.get('c_char', None),
        'stage': data.get('stage', 1),
        'items_enabled': data.get('items', True),
        'host_ready': data.get('h_ready', False),
        'client_ready': data.get('c_ready', False),
        'host_name': data.get('h_name', 'Player 1'),
        'client_name': data.get('c_name', 'Player 2'),
    }
