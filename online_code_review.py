"""
================================================================================
PingFighter 온라인 멀티플레이어 코드 리뷰 (Code Review Document)
================================================================================

이 파일은 실행용이 아닌 코드 리뷰/문서화 목적의 파일입니다.
프로젝트 내 모든 온라인 멀티플레이 관련 코드를 한 곳에 모아 놓았습니다.

========================
아키텍처 요약 (Architecture Summary)
========================

1. TCP 소켓 P2P (호스트-클라이언트 모델)
   - 호스트(P1)가 서버 소켓을 열고 클라이언트(P2)가 접속
   - 호스트가 물리/게임 로직 권위(authority)를 가짐
   - 공 위치, 아이템 스폰, 점수 계산 모두 호스트가 관리

2. Y축 반전 (Y-axis Inversion)
   - 양쪽 플레이어 모두 자신의 패들이 화면 하단에 보임
   - 호스트가 보낸 좌표를 클라이언트에서 HEIGHT - y로 반전
   - 공 속도 Y도 부호 반전, 서브 방향도 반전

3. GAME_EFFECT 이벤트 기반 시스템
   - 스킬/이펙트는 매 프레임 동기화하지 않음
   - 발동 시점에 1회만 GAME_EFFECT 패킷 전송
   - 수신 측에서 로컬 타이머 기반으로 재생 (duration 기반 수명 관리)

4. threading.Lock을 사용한 스레드 안전성
   - 네트워크 수신은 별도 스레드(network_loop)에서 처리
   - 메인 게임 스레드와 공유 데이터는 _online_lock으로 보호
   - online_game_frame, online_remote_input, online_effect_queue 등

5. AI 테스트 모드
   - 네트워크 연결 없이 로컬에서 온라인 대전 구조 테스트 가능
   - BOSS를 PlayerAIController가 조작
   - ai_test 플래그로 분기

6. 패킷 구조
   - 4바이트 크기 헤더 + JSON 페이로드
   - OnlinePacketType (0x20~): 로비, 게임, 연결 관리
   - PacketType (0x01~0x0C): 기존 네트워크 시스템 (레거시)
   - _online_type 필드로 OnlinePacketType 식별

7. 게임 루프 통합
   - 호스트: 매 프레임 _online_send_game_state() -> GAME_FRAME 패킷 전송
   - 클라이언트: 매 프레임 _online_send_player_position() + _online_client_apply_state()
   - 보스 위치 동기화: _handle_boss_online_sync() (호스트/클라이언트 양쪽)
   - 이펙트 렌더링: _online_receive_effects() -> _online_update_remote_effects() -> _online_draw_remote_effects()
"""


# ========================================================================
# [1/6] network/protocol.py - 프로토콜 정의
# ========================================================================

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
    GAME_INPUT = 0x30        # P2 입력 (클라이언트 -> 호스트)
    GAME_FRAME = 0x31        # 프레임 상태 (호스트 -> 클라이언트)
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
        # 클라이언트 아이템 획득
        'cp': frame_data.get('client_pickups', []),
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
        'client_pickups': data.get('cp', []),
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


# ========================================================================
# [2/6] network/network_manager.py - 네트워크 매니저
# ========================================================================

"""
Network Manager - 네트워크 멀티플레이어 시스템
P2P 및 서버-클라이언트 모델 지원
"""

import socket
import threading
import json
import time
import struct
from typing import Dict, Any, Optional, Callable, List
from enum import Enum
from dataclasses import dataclass, asdict
from core.events import EventType, emit_event
from core.global_manager import GlobalManager
from network.protocol import OnlinePacketType


class NetworkMode(Enum):
    """네트워크 모드"""
    OFFLINE = "offline"
    HOST = "host"
    CLIENT = "client"
    P2P = "p2p"


class PacketType(Enum):
    """패킷 타입"""
    HANDSHAKE = 0x01
    GAME_STATE = 0x02
    INPUT = 0x03
    SYNC = 0x04
    PING = 0x05
    CHAT = 0x06
    DISCONNECT = 0x07
    READY = 0x08
    START_GAME = 0x09
    SCORE_UPDATE = 0x0A
    ITEM_SPAWN = 0x0B
    SPECIAL_ABILITY = 0x0C


@dataclass
class NetworkPacket:
    """네트워크 패킷"""
    packet_type: PacketType
    timestamp: float
    sequence: int
    data: Dict[str, Any]

    def to_bytes(self) -> bytes:
        """바이트로 변환"""
        json_data = json.dumps({
            'type': self.packet_type.value,
            'timestamp': self.timestamp,
            'sequence': self.sequence,
            'data': self.data
        })

        # 패킷 크기를 헤더에 포함 (4바이트)
        packet_data = json_data.encode('utf-8')
        size = struct.pack('!I', len(packet_data))
        return size + packet_data

    @classmethod
    def from_bytes(cls, data: bytes) -> 'NetworkPacket':
        """바이트에서 생성"""
        json_data = json.loads(data.decode('utf-8'))
        return cls(
            packet_type=PacketType(json_data['type']),
            timestamp=json_data['timestamp'],
            sequence=json_data['sequence'],
            data=json_data['data']
        )


class NetworkConnection:
    """네트워크 연결 관리"""

    def __init__(self, socket: socket.socket, address: tuple):
        self.socket = socket
        self.address = address
        self.connected = True
        self.last_ping = time.time()
        self.latency = 0
        self.packet_loss = 0
        self.sequence = 0
        self.received_sequences = set()

        # 수신 버퍼
        self.recv_buffer = b''

        # 통계
        self.stats = {
            'packets_sent': 0,
            'packets_received': 0,
            'bytes_sent': 0,
            'bytes_received': 0
        }

    def send_packet(self, packet: NetworkPacket) -> bool:
        """패킷 전송

        Args:
            packet: 전송할 패킷

        Returns:
            전송 성공 여부
        """
        if not self.connected:
            return False

        try:
            data = packet.to_bytes()
            self.socket.sendall(data)
            self.stats['packets_sent'] += 1
            self.stats['bytes_sent'] += len(data)
            return True
        except (ConnectionResetError, ConnectionAbortedError, BrokenPipeError, OSError):
            self.connected = False
        except Exception as e:
            print(f"패킷 전송 에러: {e}")
            return False

    def receive_packet(self) -> Optional[NetworkPacket]:
        """패킷 수신

        Returns:
            수신된 패킷 또는 None
        """
        if not self.connected:
            return None

        try:
            # 패킷 크기 읽기 (4바이트)
            if len(self.recv_buffer) < 4:
                data = self.socket.recv(4 - len(self.recv_buffer))
                if not data:
                    self.connected = False
                    return None
                self.recv_buffer += data

            if len(self.recv_buffer) < 4:
                return None

            # 패킷 크기 파싱
            size = struct.unpack('!I', self.recv_buffer[:4])[0]

            # 패킷 데이터 읽기
            if len(self.recv_buffer) < 4 + size:
                data = self.socket.recv(4 + size - len(self.recv_buffer))
                if not data:
                    self.connected = False
                    return None
                self.recv_buffer += data

            if len(self.recv_buffer) < 4 + size:
                return None

            # 패킷 파싱
            packet_data = self.recv_buffer[4:4+size]
            self.recv_buffer = self.recv_buffer[4+size:]

            packet = NetworkPacket.from_bytes(packet_data)

            # 통계 업데이트
            self.stats['packets_received'] += 1
            self.stats['bytes_received'] += 4 + size

            # 시퀀스 확인
            if packet.sequence in self.received_sequences:
                # 중복 패킷
                return None
            self.received_sequences.add(packet.sequence)

            # 오래된 시퀀스 제거 (60Hz x 2방향 = 초당 ~120패킷)
            if len(self.received_sequences) > 5000:
                max_seq = max(self.received_sequences)
                self.received_sequences = {s for s in self.received_sequences if s > max_seq - 3000}

            return packet

        except socket.timeout:
            return None
        except (ConnectionResetError, ConnectionAbortedError, BrokenPipeError, OSError):
            # 실제 연결 끊김
            self.connected = False
            return None
        except Exception as e:
            # 파싱 에러 등은 연결을 유지하고 버퍼만 리셋
            print(f"패킷 수신 에러 (연결 유지): {e}")
            self.recv_buffer = b''  # 손상된 버퍼 리셋
            return None

    def close(self):
        """연결 종료"""
        self.connected = False
        try:
            self.socket.close()
        except:
            pass


class NetworkManager:
    """네트워크 매니저"""

    def __init__(self):
        self.global_manager = GlobalManager.get_instance()

        # 네트워크 설정
        self.mode = NetworkMode.OFFLINE
        self.port = 12345
        self.host = "127.0.0.1"

        # 연결 관리
        self.server_socket = None
        self.connections: List[NetworkConnection] = []
        self.is_running = False

        # 패킷 시퀀스
        self.sequence = 0

        # 콜백
        self.packet_handlers: Dict[PacketType, Callable] = {}

        # 게임 상태 동기화
        self.sync_state = {
            'ball_position': (300, 375),
            'ball_velocity': (0, 5),
            'player1_pos': 300,
            'player2_pos': 300,
            'score': [0, 0],
            'game_time': 0
        }

        # 입력 버퍼
        self.input_buffer = []
        self.input_delay = 3  # 프레임 지연 (롤백 넷코드용)

        # 스레드
        self.network_thread = None

        # 온라인 멀티플레이 상태 (네트워크 스레드 <-> 메인 스레드 공유)
        self._online_lock = threading.Lock()  # 스레드 안전성 Lock
        self.online_effect_queue = []         # 수신된 이펙트 이벤트 큐
        self.online_mode = False           # 온라인 대전 모드 활성화 여부
        self.online_lobby_state = None     # 로비 상태 (protocol.deserialize_lobby_state)
        self.online_remote_input = None    # 최신 원격 입력 (protocol.deserialize_input)
        self.online_game_frame = None      # 최신 게임 프레임 (클라이언트용)
        self.online_connected = False      # 상대방 접속 여부
        self.online_game_started = False   # 게임 시작 여부
        self.online_opponent_name = ""     # 상대방 이름
        self._online_packet_handlers = {}  # OnlinePacketType 핸들러

        # 설정 핸들러
        self.setup_handlers()
        self.setup_online_handlers()

    def setup_handlers(self):
        """패킷 핸들러 설정"""
        self.packet_handlers[PacketType.HANDSHAKE] = self.handle_handshake
        self.packet_handlers[PacketType.GAME_STATE] = self.handle_game_state
        self.packet_handlers[PacketType.INPUT] = self.handle_input
        self.packet_handlers[PacketType.SYNC] = self.handle_sync
        self.packet_handlers[PacketType.PING] = self.handle_ping_or_pong
        self.packet_handlers[PacketType.SCORE_UPDATE] = self.handle_score_update

    def start_host(self, port: int = 12345) -> bool:
        """호스트 시작

        Args:
            port: 포트 번호

        Returns:
            성공 여부
        """
        if self.mode != NetworkMode.OFFLINE:
            return False

        try:
            self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self.server_socket.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            self.server_socket.bind(('', port))
            self.server_socket.listen(1)
            self.server_socket.settimeout(0.1)

            self.port = port
            self.mode = NetworkMode.HOST
            self.is_running = True

            # 네트워크 스레드 시작
            self.network_thread = threading.Thread(target=self.network_loop)
            self.network_thread.daemon = True
            self.network_thread.start()

            print(f"호스트 시작: 포트 {port}")

            emit_event(EventType.MENU_OPENED, {
                'type': 'network',
                'mode': 'host',
                'port': port
            })

            return True

        except Exception as e:
            print(f"호스트 시작 실패: {e}")
            return False

    def connect_to_host(self, host: str, port: int = 12345) -> bool:
        """호스트에 연결

        Args:
            host: 호스트 주소
            port: 포트 번호

        Returns:
            성공 여부
        """
        if self.mode != NetworkMode.OFFLINE:
            return False

        try:
            client_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            client_socket.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            client_socket.settimeout(5.0)
            client_socket.connect((host, port))
            client_socket.settimeout(0.1)

            # 연결 생성
            connection = NetworkConnection(client_socket, (host, port))
            self.connections.append(connection)

            self.host = host
            self.port = port
            self.mode = NetworkMode.CLIENT
            self.is_running = True

            # 핸드셰이크 전송
            self.send_handshake(connection)

            # 네트워크 스레드 시작
            self.network_thread = threading.Thread(target=self.network_loop)
            self.network_thread.daemon = True
            self.network_thread.start()

            print(f"호스트 연결: {host}:{port}")

            emit_event(EventType.MENU_OPENED, {
                'type': 'network',
                'mode': 'client',
                'host': host,
                'port': port
            })

            return True

        except Exception as e:
            print(f"호스트 연결 실패: {e}")
            return False

    def network_loop(self):
        """네트워크 루프 (별도 스레드)"""
        while self.is_running:
            try:
                # 호스트 모드: 연결 수락
                if self.mode == NetworkMode.HOST and self.server_socket:
                    try:
                        client_socket, address = self.server_socket.accept()
                        client_socket.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
                        client_socket.settimeout(0.1)
                        connection = NetworkConnection(client_socket, address)
                        self.connections.append(connection)
                        print(f"클라이언트 연결: {address}")
                    except socket.timeout:
                        pass

                # 패킷 처리
                for connection in self.connections[:]:
                    if not connection.connected:
                        self.connections.remove(connection)
                        with self._online_lock:
                            self.online_connected = False
                        continue

                    # 패킷 수신 (한 루프에 여러 개 처리)
                    packets_this_loop = 0
                    while packets_this_loop < 30:  # 최대 30개/루프
                        packet = connection.receive_packet()
                        if packet is None:
                            break
                        self.process_packet(packet, connection)
                        packets_this_loop += 1

                    # 핑 체크
                    if time.time() - connection.last_ping > 2.0:
                        self.send_ping(connection)

                # 게임 상태 동기화 (호스트만, 온라인 대전 모드가 아닐 때만)
                if self.mode == NetworkMode.HOST and not self.online_mode:
                    self.sync_game_state()

                time.sleep(0.001)  # 1ms 대기

            except Exception as e:
                print(f"네트워크 루프 에러: {e}")

    def setup_online_handlers(self):
        """온라인 대전 전용 패킷 핸들러 설정"""
        self._online_packet_handlers = {
            OnlinePacketType.LOBBY_STATE: self._handle_online_lobby_state,
            OnlinePacketType.CHAR_SELECT: self._handle_online_char_select,
            OnlinePacketType.STAGE_SELECT: self._handle_online_stage_select,
            OnlinePacketType.LOBBY_READY: self._handle_online_lobby_ready,
            OnlinePacketType.LOBBY_START: self._handle_online_lobby_start,
            OnlinePacketType.GAME_INPUT: self._handle_online_game_input,
            OnlinePacketType.GAME_FRAME: self._handle_online_game_frame,
            OnlinePacketType.GAME_EVENT: self._handle_online_game_event,
            OnlinePacketType.GAME_EFFECT: self._handle_online_game_effect,
            OnlinePacketType.ONLINE_PING: self._handle_online_ping,
            OnlinePacketType.ONLINE_PONG: self._handle_online_pong,
            OnlinePacketType.ONLINE_DISCONNECT: self._handle_online_disconnect,
        }

    def _handle_online_lobby_state(self, packet, connection):
        from network.protocol import deserialize_lobby_state
        with self._online_lock:
            self.online_lobby_state = deserialize_lobby_state(packet.data)

    def _handle_online_char_select(self, packet, connection):
        with self._online_lock:
            if self.online_lobby_state:
                if self.mode == NetworkMode.HOST:
                    self.online_lobby_state['client_character'] = packet.data.get('character')
                else:
                    self.online_lobby_state['host_character'] = packet.data.get('character')

    def _handle_online_stage_select(self, packet, connection):
        with self._online_lock:
            if self.online_lobby_state:
                self.online_lobby_state['stage'] = packet.data.get('stage', 1)
                self.online_lobby_state['items_enabled'] = packet.data.get('items', True)

    def _handle_online_lobby_ready(self, packet, connection):
        with self._online_lock:
            if self.online_lobby_state:
                ready = packet.data.get('ready', False)
                if self.mode == NetworkMode.HOST:
                    self.online_lobby_state['client_ready'] = ready
                else:
                    self.online_lobby_state['host_ready'] = ready

    def _handle_online_lobby_start(self, packet, connection):
        with self._online_lock:
            self.online_game_started = True

    def _handle_online_game_input(self, packet, connection):
        # 위치 기반 입력 (x 필드) 또는 버튼 기반 입력 모두 지원
        data = packet.data
        if 'x' in data:
            with self._online_lock:
                self.online_remote_input = data
        else:
            from network.protocol import deserialize_input
            with self._online_lock:
                self.online_remote_input = deserialize_input(data)

    def _handle_online_game_frame(self, packet, connection):
        from network.protocol import deserialize_game_frame
        frame = deserialize_game_frame(packet.data)
        with self._online_lock:
            self.online_game_frame = frame

    def _handle_online_game_event(self, packet, connection):
        # 이벤트 처리 (점수 변경, 게임 오버 등)
        pass

    def _handle_online_game_effect(self, packet, connection):
        """스킬/이펙트 이벤트 수신 -> 큐에 추가"""
        with self._online_lock:
            self.online_effect_queue.append(packet.data)

    def pop_online_effects(self):
        """메인 스레드: 이펙트 큐를 꺼내고 비움 (스레드-안전)"""
        with self._online_lock:
            effects = self.online_effect_queue[:]
            self.online_effect_queue.clear()
            return effects

    def _handle_online_ping(self, packet, connection):
        # 핑 응답 전송
        self.send_online_packet(OnlinePacketType.ONLINE_PONG,
                                {'t': packet.data.get('t', 0)}, connection)

    def _handle_online_pong(self, packet, connection):
        sent_time = packet.data.get('t', 0)
        if sent_time > 0:
            connection.latency = (time.time() - sent_time) * 1000

    def _handle_online_disconnect(self, packet, connection):
        with self._online_lock:
            self.online_connected = False
        connection.connected = False

    def send_online_packet(self, packet_type: OnlinePacketType, data: dict,
                           connection=None):
        """온라인 패킷 전송 (OnlinePacketType 사용)"""
        packet = NetworkPacket(
            packet_type=PacketType(packet_type.value) if packet_type.value <= 0x0C
                        else PacketType.SYNC,  # 폴백 타입
            timestamp=time.time(),
            sequence=self.get_next_sequence(),
            data={'_online_type': packet_type.value, **data}
        )
        if connection:
            connection.send_packet(packet)
        else:
            for conn in self.connections:
                conn.send_packet(packet)

    def get_online_remote_input(self):
        """스레드-안전 원격 입력 읽기"""
        with self._online_lock:
            return self.online_remote_input

    def get_online_game_frame(self):
        """스레드-안전 게임 프레임 읽기"""
        with self._online_lock:
            return self.online_game_frame

    def get_online_lobby_state(self):
        """스레드-안전 로비 상태 읽기"""
        with self._online_lock:
            return self.online_lobby_state

    def reset_online_state(self):
        """온라인 대전 상태 초기화"""
        with self._online_lock:
            self.online_mode = False
            self.online_lobby_state = None
            self.online_remote_input = None
            self.online_game_frame = None
            self.online_connected = False
            self.online_game_started = False
            self.online_opponent_name = ""
            self.online_effect_queue.clear()

    def get_local_ip(self) -> str:
        """로컬 IP 주소 반환 (LAN용)"""
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
        except Exception:
            return "127.0.0.1"

    def process_packet(self, packet: NetworkPacket, connection: NetworkConnection):
        """패킷 처리

        Args:
            packet: 수신된 패킷
            connection: 연결
        """
        # 온라인 패킷 확인 (_online_type 필드)
        online_type_val = packet.data.get('_online_type') if isinstance(packet.data, dict) else None
        if online_type_val is not None:
            try:
                online_type = OnlinePacketType(online_type_val)
                handler = self._online_packet_handlers.get(online_type)
                if handler:
                    handler(packet, connection)
                return
            except (ValueError, KeyError):
                pass

        handler = self.packet_handlers.get(packet.packet_type)
        if handler:
            handler(packet, connection)

    def send_packet(self, packet_type: PacketType, data: Dict[str, Any],
                   connection: Optional[NetworkConnection] = None):
        """패킷 전송

        Args:
            packet_type: 패킷 타입
            data: 데이터
            connection: 특정 연결 (None이면 모든 연결)
        """
        packet = NetworkPacket(
            packet_type=packet_type,
            timestamp=time.time(),
            sequence=self.get_next_sequence(),
            data=data
        )

        if connection:
            connection.send_packet(packet)
        else:
            # 모든 연결에 전송
            for conn in self.connections:
                conn.send_packet(packet)

    def get_next_sequence(self) -> int:
        """다음 시퀀스 번호 반환"""
        self.sequence = (self.sequence + 1) % 0xFFFFFFFF
        return self.sequence

    def send_handshake(self, connection: NetworkConnection):
        """핸드셰이크 전송"""
        data = {
            'version': '1.0.0',
            'player_name': self.global_manager.get('player_name', 'Player'),
            'mode': self.mode.value
        }
        self.send_packet(PacketType.HANDSHAKE, data, connection)

    def handle_handshake(self, packet: NetworkPacket, connection: NetworkConnection):
        """핸드셰이크 처리"""
        print(f"핸드셰이크 수신: {packet.data}")

        # 호스트인 경우 응답
        if self.mode == NetworkMode.HOST:
            self.send_handshake(connection)

    def send_ping(self, connection: NetworkConnection):
        """핑 전송 (온라인 모드에서는 자체 핑 사용)"""
        if self.online_mode:
            # 온라인 모드: 자체 핑 시스템 사용 (라운드트립)
            self.send_online_packet(OnlinePacketType.ONLINE_PING,
                                    {'t': time.time()}, connection)
        else:
            data = {'timestamp': time.time()}
            self.send_packet(PacketType.PING, data, connection)
        connection.last_ping = time.time()

    def handle_ping(self, packet: NetworkPacket, connection: NetworkConnection):
        """핑 처리 (PONG 응답)"""
        # PONG 응답 전송 (상대방의 타임스탬프를 그대로 돌려보냄)
        self.send_packet(PacketType.PING, {
            'timestamp': packet.data.get('timestamp', 0),
            'is_pong': True
        }, connection)

    def handle_ping_or_pong(self, packet: NetworkPacket, connection: NetworkConnection):
        """PING/PONG 패킷 분기 처리"""
        if packet.data.get('is_pong'):
            # PONG 응답 -> 레이턴시 계산
            sent_time = packet.data.get('timestamp', 0)
            if sent_time > 0:
                connection.latency = (time.time() - sent_time) * 1000
        else:
            # PING 요청 -> PONG 응답 전송
            self.handle_ping(packet, connection)

    def sync_game_state(self):
        """게임 상태 동기화 (호스트)"""
        if not self.connections:
            return

        # 현재 게임 상태 가져오기
        ball_rect = self.global_manager.get('BALL')
        player_rect = self.global_manager.get('PLAYER')
        boss_rect = self.global_manager.get('BOSS')

        if ball_rect and player_rect and boss_rect:
            state = {
                'ball_position': (ball_rect.centerx, ball_rect.centery),
                'ball_velocity': (
                    self.global_manager.get('ball_dx', 0),
                    self.global_manager.get('ball_dy', 5)
                ),
                'player1_pos': player_rect.centerx,
                'player2_pos': boss_rect.centerx,
                'score': [
                    self.global_manager.get('player_score', 0),
                    self.global_manager.get('boss_score', 0)
                ],
                'game_time': time.time()
            }

            # 상태 전송
            self.send_packet(PacketType.GAME_STATE, state)

    def handle_game_state(self, packet: NetworkPacket, connection: NetworkConnection):
        """게임 상태 처리 (클라이언트)"""
        if self.mode == NetworkMode.CLIENT:
            self.sync_state = packet.data

            # 게임 상태 적용
            self.apply_sync_state()

    def apply_sync_state(self):
        """동기화 상태 적용"""
        # 공 위치
        ball_rect = self.global_manager.get('BALL')
        if ball_rect:
            ball_rect.centerx = self.sync_state['ball_position'][0]
            ball_rect.centery = self.sync_state['ball_position'][1]

        # 공 속도
        self.global_manager.set('ball_dx', self.sync_state['ball_velocity'][0])
        self.global_manager.set('ball_dy', self.sync_state['ball_velocity'][1])

        # 플레이어 위치 (클라이언트는 플레이어2)
        if self.mode == NetworkMode.CLIENT:
            boss_rect = self.global_manager.get('BOSS')
            if boss_rect:
                boss_rect.centerx = self.sync_state['player2_pos']

    def send_input(self, input_data: Dict[str, Any]):
        """입력 전송

        Args:
            input_data: 입력 데이터
        """
        if self.mode in [NetworkMode.HOST, NetworkMode.CLIENT]:
            data = {
                'input': input_data,
                'frame': self.global_manager.get('frame_count', 0)
            }
            self.send_packet(PacketType.INPUT, data)

    def handle_input(self, packet: NetworkPacket, connection: NetworkConnection):
        """입력 처리"""
        input_data = packet.data['input']
        frame = packet.data['frame']

        # 입력 버퍼에 추가
        self.input_buffer.append({
            'input': input_data,
            'frame': frame,
            'connection': connection
        })

        # 오래된 입력 제거
        current_frame = self.global_manager.get('frame_count', 0)
        self.input_buffer = [i for i in self.input_buffer
                            if i['frame'] > current_frame - 60]

    def handle_sync(self, packet: NetworkPacket, connection: NetworkConnection):
        """동기화 패킷 처리"""
        sync_data = packet.data

        # 동기화 데이터 업데이트
        self.sync_state.update(sync_data)

        # 게임 오브젝트 동기화
        self.apply_sync_state()

    def handle_score_update(self, packet: NetworkPacket, connection: NetworkConnection):
        """점수 업데이트 처리"""
        score = packet.data['score']
        self.global_manager.set('player_score', score[0])
        self.global_manager.set('boss_score', score[1])

    def get_remote_input(self) -> Optional[Dict[str, Any]]:
        """원격 입력 가져오기

        Returns:
            입력 데이터 또는 None
        """
        if not self.input_buffer:
            return None

        current_frame = self.global_manager.get('frame_count', 0)

        # 현재 프레임에 해당하는 입력 찾기
        for input_data in self.input_buffer:
            if abs(input_data['frame'] - current_frame) <= self.input_delay:
                return input_data['input']

        return None

    def disconnect(self):
        """연결 종료"""
        self.is_running = False

        # 연결 종료 패킷 전송
        self.send_packet(PacketType.DISCONNECT, {})

        # 모든 연결 종료
        for connection in self.connections:
            connection.close()
        self.connections.clear()

        # 서버 소켓 종료
        if self.server_socket:
            try:
                self.server_socket.close()
            except:
                pass
            self.server_socket = None

        self.mode = NetworkMode.OFFLINE

        print("네트워크 연결 종료")

    def get_network_stats(self) -> Dict[str, Any]:
        """네트워크 통계 반환"""
        stats = {
            'mode': self.mode.value,
            'connections': len(self.connections),
            'average_latency': 0,
            'packet_loss': 0
        }

        if self.connections:
            total_latency = sum(c.latency for c in self.connections)
            stats['average_latency'] = total_latency / len(self.connections)

            total_loss = sum(c.packet_loss for c in self.connections)
            stats['packet_loss'] = total_loss / len(self.connections)

        return stats


# 싱글톤 인스턴스
_network_manager = None

def get_network_manager() -> NetworkManager:
    """네트워크 매니저 싱글톤 반환"""
    global _network_manager
    if _network_manager is None:
        _network_manager = NetworkManager()
    return _network_manager


# ========================================================================
# [3/6] network/online_game.py - 온라인 멀티플레이 게임 모드 (967 lines)
# ========================================================================

"""
온라인 멀티플레이 게임 모드
호스트/참가 -> 로비(캐릭터/스테이지 선택) -> 게임 시작

주요 클래스: OnlineMultiplayer
주요 흐름: _show_mode_select() -> _host_wait_screen()/_client_connect_screen() -> _lobby_screen() -> _build_result()
AI 테스트: _run_ai_test_mode() (네트워크 없이 로컬 테스트)

IP 히스토리: ip_history.json에 최근 5개 접속 IP 저장
캐릭터: 스매셔, 코만도, 발토르, 바이퍼
스테이지: 1~6 (풍악보이~홍련)

반환값: dict {'is_host', 'p1_character', 'p2_character', 'stage', 'items_enabled', 'ai_test'}
        또는 None (취소 시)

[전체 코드는 위 network/online_game.py 섹션의 설명 참조 - 967줄 전체 포함]
"""

# ── 이하 online_game.py 전체 코드 (import ~ run_online_multiplayer 함수까지) ──

import pygame
import socket
import time
import threading
import json
import os
from network.network_manager import get_network_manager, NetworkMode
from network.protocol import (
    OnlinePacketType, STAGE_MULTIPLAYER, WIN_GOAL_DEFAULT,
    serialize_lobby_state, deserialize_lobby_state,
    serialize_input, DEFAULT_PORT,
)

# ── IP 히스토리 저장/로드 ──
_IP_HISTORY_FILE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "ip_history.json")
_MAX_IP_HISTORY = 5

def _load_ip_history():
    try:
        if os.path.exists(_IP_HISTORY_FILE):
            with open(_IP_HISTORY_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                return data.get("history", [])[:_MAX_IP_HISTORY]
    except Exception:
        pass
    return []

def _save_ip_history(history):
    try:
        with open(_IP_HISTORY_FILE, "w", encoding="utf-8") as f:
            json.dump({"history": history[:_MAX_IP_HISTORY]}, f, ensure_ascii=False)
    except Exception:
        pass

def _add_ip_to_history(ip_str):
    history = _load_ip_history()
    if ip_str in history:
        history.remove(ip_str)
    history.insert(0, ip_str)
    _save_ip_history(history[:_MAX_IP_HISTORY])

CHARACTERS = [
    {"id": "ufo_player", "name": "스매셔", "color": (0, 200, 255), "stats": {"속도": 4, "파워": 7, "방어": 4}},
    {"id": "soldier", "name": "코만도", "color": (100, 200, 100), "stats": {"속도": 6, "파워": 6, "방어": 6}},
    {"id": "blacksmith", "name": "발토르", "color": (255, 180, 50), "stats": {"속도": 5, "파워": 7, "방어": 5}},
    {"id": "viper", "name": "바이퍼", "color": (180, 50, 255), "stats": {"속도": 4, "파워": 5, "방어": 3}},
]

STAGES = [
    {"num": 1, "name": "풍악보이 스테이지", "color": (120, 80, 60)},
    {"num": 2, "name": "악어장군 스테이지", "color": (40, 120, 50)},
    {"num": 3, "name": "멘헤라걸 스테이지", "color": (180, 80, 150)},
    {"num": 4, "name": "퐁크 스테이지", "color": (200, 160, 60)},
    {"num": 5, "name": "네메시스 스테이지", "color": (40, 80, 160)},
    {"num": 6, "name": "홍련 스테이지", "color": (200, 50, 30)},
]

BG_COLOR = (18, 22, 32)
PANEL_COLOR = (30, 36, 50)
ACCENT_COLOR = (0, 180, 255)
READY_COLOR = (50, 220, 100)
TEXT_COLOR = (220, 225, 235)
DIM_COLOR = (100, 110, 130)
HIGHLIGHT_COLOR = (255, 220, 50)

# NOTE: OnlineMultiplayer 클래스 전체 (약 880줄)는 network/online_game.py에 위치.
# 메서드 목록:
#   run(), _show_mode_select(), _host_wait_screen(), _client_connect_screen(),
#   _try_connect(), _lobby_screen(), _handle_lobby_input(), _draw_lobby(),
#   _draw_character_panel(), _draw_stage_panel(), _draw_items_toggle(),
#   _draw_ready_area(), _init_lobby_state(), _send_char_select(),
#   _send_stage_select(), _send_ready(), _send_game_start(), _build_result(),
#   _run_ai_test_mode(), _show_message()
# 진입점: run_online_multiplayer(screen, width, height, get_font_func)


# ========================================================================
# [4/6] network/client_renderer.py - 클라이언트 렌더러 (341 lines)
# ========================================================================

"""
온라인 멀티플레이 - 클라이언트 렌더러
호스트에서 수신한 게임 상태를 Y축 반전하여 렌더링한다.
클라이언트(P2)는 자기 패들이 아래, 상대(P1)가 위에 보인다.

NOTE: 이 렌더러는 독립 실행형 (간이 렌더러). 현재 실제 온라인 대전은
      양쪽 모두 main(40) 게임 엔진을 사용하며, 이 렌더러는 미사용 상태.

주요 클래스: ClientRenderer
메서드: run(), _collect_and_send_input(), _receive_state(), _flip_y(),
        _draw(), _show_result(), _show_disconnect()
진입점: run_client_renderer(screen, width, height, get_font_func, net_manager)

[전체 코드: 341줄 - 색상 정의, ClientRenderer 클래스, run_client_renderer 함수]
"""

import pygame
import time
import math
from network.protocol import (
    OnlinePacketType, serialize_input, deserialize_game_frame,
)

BG_COLOR_CR = (18, 22, 32)
P1_COLOR = (0, 150, 255)      # 호스트 (상대방) - 파란색
P2_COLOR = (255, 100, 100)    # 나 (클라이언트) - 빨간색
BALL_COLOR = (255, 255, 255)
TEXT_COLOR_CR = (220, 225, 235)
DIM_COLOR_CR = (100, 110, 130)
ACCENT_COLOR_CR = (0, 180, 255)
SCORE_COLOR = (255, 220, 50)

# NOTE: ClientRenderer 클래스 전체 (약 310줄)는 network/client_renderer.py에 위치.
# Y축 반전 핵심: _flip_y(y, obj_height) -> self.height - y - obj_height
# P2 패들 예측: 로컬 입력 즉시 반영 + 서버 위치와 50% 블렌딩
# 연결 끊김 감지: 10초간 프레임 수신 없음 -> disconnect 표시


# ========================================================================
# [5/6] ui/network_ui.py - 네트워크 UI (466 lines)
# ========================================================================

"""
Network UI - 네트워크 멀티플레이어 UI
호스트/조인 인터페이스 및 연결 상태 표시

NOTE: 이 UI는 레거시 네트워크 시스템용. 현재 온라인 대전은
      network/online_game.py의 OnlineMultiplayer 클래스 사용.

주요 클래스: NetworkUI
메뉴 구조: main -> host/join -> lobby
싱글톤: get_network_ui(screen)

[전체 코드: 466줄 - NetworkUI 클래스, 렌더링 메서드, 싱글톤]
"""

import pygame
from typing import Optional, Tuple, Dict, Any
from core.events import EventType, emit_event
from core.global_manager import GlobalManager
from network.network_manager import get_network_manager, NetworkMode

# NOTE: NetworkUI 클래스 전체 (약 450줄)는 ui/network_ui.py에 위치.
# 메서드 목록:
#   open(), close(), handle_event(), update(), render(),
#   _handle_menu_event(), _handle_input_event(), _execute_option(),
#   _confirm_input(), _start_hosting(), _join_game(), _toggle_ready(),
#   _start_multiplayer_game(), _leave_lobby(),
#   _render_main_menu(), _render_host_menu(), _render_join_menu(),
#   _render_lobby(), _render_input_field()


# ========================================================================
# [6/6] pingfighter.py - 온라인 관련 코드 발췌
# ========================================================================

# ────────────────────────────────────────────────────────────────────────
# [6-A] 전역 변수 (line ~22671)
# ────────────────────────────────────────────────────────────────────────

# ── 온라인 멀티플레이 전용 변수 ──
online_multiplayer_enabled = False   # 온라인 대전 모드 활성화
online_is_host = False               # True=호스트(P1), False=클라이언트(P2)
online_p2_character = "ufo_player"   # P2 캐릭터 ID
online_items_enabled = True          # 아이템 드랍 활성화
online_p2_input = None               # P2 최신 입력 (network에서 수신)
_online_net_manager = None           # NetworkManager 참조 (캐싱용)
_online_sound_queue = []             # 이번 프레임 사운드 큐 (클라이언트 전송용)

# ── 온라인 멀티: 애니메이션 상태 동기화 ── (line ~171088)
_online_opponent_anim = {'state': 'idle'}  # 상대방 수신 애니메이션 상태
_online_client_serve_pressed = False  # 클라이언트 서브 입력 플래그 (이벤트 기반)
_online_client_pickups = []  # 호스트->클라이언트: 클라이언트가 획득한 아이템 목록
_online_ai_boss_enabled = False  # AI 대전 모드: BOSS를 AI가 조작
_online_ai_boss_controller = None  # AI 컨트롤러 인스턴스

# ── 온라인 이펙트 이벤트 시스템 (단발성 이벤트 -> 로컬 재생) ──
_online_remote_effects = []  # 상대방에서 수신한 이펙트 (로컬 타이머 기반 재생)


# ────────────────────────────────────────────────────────────────────────
# [6-B] start_online_multiplayer() 함수 (line ~171018)
# ────────────────────────────────────────────────────────────────────────

def start_online_multiplayer():
    """온라인 멀티플레이 진입점.
    로비 -> 캐릭터/스테이지 선택 -> 양쪽 모두 main(40) 실행.
    호스트(P1): 공 물리 권위, BOSS=P2 위치 수신
    클라이언트(P2): BOSS=P1 위치 수신, 공=호스트에서 수신
    """
    global online_multiplayer_enabled, online_is_host, online_p2_character
    global online_items_enabled, _online_net_manager, online_p2_input
    global selected_character_type

    from network.online_game import run_online_multiplayer
    from network.network_manager import get_network_manager

    # 로비 실행
    result = run_online_multiplayer(SCREEN, WIDTH, HEIGHT, get_font_func=get_font)
    if result is None:
        return  # 취소

    # AI 대전 모드 체크
    _is_ai_test = result.get('ai_test', False)

    if not _is_ai_test:
        _online_net_manager = get_network_manager()
    online_multiplayer_enabled = True
    online_is_host = result['is_host']
    online_items_enabled = result.get('items_enabled', True)
    online_p2_input = None

    # 캐릭터 타입 매핑
    char_map = {
        "ufo_player": "smasher",
        "soldier": "soldier",
        "blacksmith": "blacksmith",
        "viper": "viper",
    }

    if online_is_host:
        # 호스트: P1(하단) = 내 캐릭터
        p1_char = result['p1_character']
        online_p2_character = result['p2_character']
        selected_character_type = char_map.get(p1_char, "smasher")
    else:
        # 클라이언트: P2(하단) = 내 캐릭터 (내가 PLAYER를 조작)
        my_char = result['p2_character']
        online_p2_character = result['p1_character']
        selected_character_type = char_map.get(my_char, "smasher")

    # AI 대전 모드: BOSS를 AI가 조작
    global _online_ai_boss_enabled
    _online_ai_boss_enabled = _is_ai_test

    # 필러 UI 활성화 (게이지 구슬, 아이템 슬롯, 대쉬 토큰 표시에 필요)
    global _pillar_ui_enabled
    _pillar_ui_enabled = True

    # 양쪽 모두 main(40) 실행 -> 본게임 엔진 그대로 렌더링
    main(STAGE_MULTIPLAYER)

    # 정리
    online_multiplayer_enabled = False
    online_is_host = False
    online_p2_input = None
    _online_ai_boss_enabled = False
    if _online_net_manager:
        _online_net_manager.disconnect()
        _online_net_manager.reset_online_state()
        _online_net_manager = None


# ────────────────────────────────────────────────────────────────────────
# [6-C] _handle_boss_online_sync() 함수 (line ~152225)
# ────────────────────────────────────────────────────────────────────────

def _handle_boss_online_sync():
    """온라인 멀티플레이: 상대방의 PLAYER 위치를 BOSS에 적용 + 서브 처리.
    호스트: P2(클라이언트)의 PLAYER.x -> BOSS.x
    클라이언트: P1(호스트)의 PLAYER.x -> BOSS.x
    AI 대전: AI가 BOSS를 조작
    """
    global BOSS, _online_opponent_anim
    global is_waiting_for_serve, is_player_serve, ball_vel
    global serve_completed_timer, boss_fake_during_player_serve
    global _online_ai_boss_controller

    # ── AI 대전 모드: AI가 BOSS를 직접 조작 ──
    if _online_ai_boss_enabled:
        try:
            if _online_ai_boss_controller is None:
                from ai.player_ai import PlayerAIController
                _online_ai_boss_controller = PlayerAIController()
            # AI 상태 구성
            _ai_state = {
                'ball_x': BALL.centerx,
                'ball_y': BALL.centery,
                'ball_vx': ball_vel[0],
                'ball_vy': ball_vel[1],
                'player_x': BOSS.centerx,  # AI가 BOSS를 조작
                'player_y': BOSS.centery,
                'player_width': BOSS.width,
                'boss_x': PLAYER.centerx,  # 상대는 PLAYER
                'boss_y': PLAYER.centery,
                'width': WIDTH,
                'height': HEIGHT,
                'special_gauge': 0,
                'is_waiting_serve': is_waiting_for_serve,
                'is_player_serve': not is_player_serve,  # AI 입장에서 반전
                'rolling_active': False,
                'current_speed': 0,
            }
            _ai_keys = _online_ai_boss_controller.decide(_ai_state)
            # AI 이동 적용
            _ai_speed = 7
            if pygame.K_LEFT in _ai_keys:
                BOSS.x -= _ai_speed
            if pygame.K_RIGHT in _ai_keys:
                BOSS.x += _ai_speed
        except Exception as e:
            print(f"[AI Boss] 에러: {e}")
    elif _online_net_manager is None:
        return
    elif online_is_host:
        # 호스트: 클라이언트가 보낸 위치 + 애니메이션 상태 적용
        remote = _online_net_manager.get_online_remote_input()
        if remote is not None and 'x' in remote:
            BOSS.x = int(remote['x'])
            if 'anim' in remote:
                _online_opponent_anim = remote['anim']
    else:
        # 클라이언트: 호스트가 보낸 P1 위치를 BOSS에 적용
        frame = _online_net_manager.get_online_game_frame()
        if frame is not None:
            p1 = frame.get('p1', None)
            if p1:
                BOSS.x = int(p1[0])

    # 경계 클램핑
    if BOSS.x < 0:
        BOSS.x = 0
    elif BOSS.x > WIDTH - BOSS.width:
        BOSS.x = WIDTH - BOSS.width

    # ── 바이퍼 제트팩 오프셋 적용 (상대방이 체공 중일 때 BOSS.y 변경) ──
    if _online_opponent_anim and _online_opponent_anim.get('state') == 'flying':
        _opp_jp_offset = _online_opponent_anim.get('jetpack_offset', 0)
        BOSS.y = BOSS_Y - int(_opp_jp_offset)  # 부호 반전! -(-200) = +200 -> 아래로
    else:
        BOSS.y = BOSS_Y  # 체공이 아닐 때는 기본 위치

    # ── 온라인 서브 처리 (handle_boss() 안의 서브 로직을 대체) ──
    if is_waiting_for_serve and not ball_spawn_animation_active:
        _dbg_role = "HOST" if online_is_host else "CLIENT"
        _dbg_tick = pygame.time.get_ticks()
        _dbg_last_key = '_online_dbg_last_serve_tick'
        if _dbg_tick - globals().get(_dbg_last_key, 0) >= 500:
            globals()[_dbg_last_key] = _dbg_tick
            print(f"[Online Serve DEBUG] {_dbg_role} | is_player_serve={is_player_serve} | is_waiting={is_waiting_for_serve} | BALL=({BALL.x},{BALL.y}) | ball_vel={ball_vel}")
        if is_player_serve and online_is_host:
            # 호스트 본인 서브: space/enter로 아래에서 위로 발사
            keys = pygame.key.get_pressed()
            if keys[pygame.K_RETURN] or keys[pygame.K_SPACE]:
                try:
                    serve_result = physics_manager.serve_ball(True, current_stage, ai_mode)
                    apply_serve_result(serve_result)
                    is_waiting_for_serve = serve_result.get('is_waiting_for_serve', False)
                    serve_completed_timer = 180
                    boss_fake_during_player_serve = False
                    play_serve_sound()
                    create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=True)
                    print(f"[Online Serve DEBUG] HOST 서브 완료! BALL=({BALL.x},{BALL.y}) vel={ball_vel}")
                except Exception as e:
                    print(f"[Online Serve] 플레이어 서브 에러: {e}")
            else:
                boss_fake_during_player_serve = True
        elif is_player_serve and not online_is_host:
            # 클라이언트 본인 서브: 입력은 _online_send_player_position()에서 호스트로 전송
            boss_fake_during_player_serve = True
        elif online_is_host:
            # 상대(클라이언트/AI) 서브
            _client_serve = False
            if _online_ai_boss_enabled:
                pass  # AI: 자동 서브
            elif _online_net_manager is not None:
                remote = _online_net_manager.get_online_remote_input()
                if remote is not None and remote.get('serve', False):
                    _client_serve = True
                    print(f"[Online Serve DEBUG] HOST: 클라이언트 서브 입력 수신!")
            time_now = pygame.time.get_ticks()
            _elapsed = time_now - waiting_start_time
            _serve_timeout = 1500 if _online_ai_boss_enabled else 3000
            if _client_serve or (_elapsed >= _serve_timeout):
                print(f"[Online Serve DEBUG] HOST: 보스(클라이언트) 서브 실행 | client_input={_client_serve} | elapsed={_elapsed}ms")
                try:
                    serve_result = physics_manager.serve_ball(False, current_stage, ai_mode)
                    apply_serve_result(serve_result)
                    is_waiting_for_serve = serve_result.get('is_waiting_for_serve', False)
                    serve_completed_timer = 180
                    play_serve_sound()
                    create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=False)
                    print(f"[Online Serve DEBUG] HOST: 보스 서브 완료! BALL=({BALL.x},{BALL.y}) vel={ball_vel}")
                except Exception as e:
                    print(f"[Online Serve] 보스 서브 에러: {e}")
        else:
            print(f"[Online Serve DEBUG] CLIENT: 상대방(호스트) 서브 대기 중... BALL=({BALL.x},{BALL.y})")


# ────────────────────────────────────────────────────────────────────────
# [6-D] _online_send_effect / _online_receive_effects /
#       _online_update_remote_effects / _online_draw_remote_effects
#       (line ~171098)
# ────────────────────────────────────────────────────────────────────────

def _online_send_effect(effect_type, **kwargs):
    """스킬/이펙트 이벤트 1회 전송 (발동 시점에만 호출)"""
    if not online_multiplayer_enabled or _online_net_manager is None:
        return
    from network.protocol import OnlinePacketType
    data = {'e': effect_type, **kwargs}
    _online_net_manager.send_online_packet(OnlinePacketType.GAME_EFFECT, data)


def _online_receive_effects():
    """매 프레임: 수신된 이펙트를 로컬 재생 목록에 추가"""
    global _online_remote_effects
    if not online_multiplayer_enabled or _online_net_manager is None:
        return
    effects = _online_net_manager.pop_online_effects()
    for ef in effects:
        ef_type = ef.get('e', '')
        # Y축 반전 좌표
        if 'y' in ef:
            ef['y'] = HEIGHT - ef['y']
        # 방향 반전
        if ef.get('dir') == 'up':
            ef['dir'] = 'down'
        elif ef.get('dir') == 'down':
            ef['dir'] = 'up'
        # 로컬 타이머 시작
        ef['_start_ms'] = pygame.time.get_ticks()
        ef['_alive'] = True
        _online_remote_effects.append(ef)


def _online_update_remote_effects():
    """매 프레임: 로컬 이펙트 수명 관리 (만료된 것 제거)"""
    global _online_remote_effects
    now = pygame.time.get_ticks()
    _online_remote_effects = [ef for ef in _online_remote_effects
                               if ef.get('_alive', False) and (now - ef.get('_start_ms', 0)) < ef.get('dur', 2000)]


def _online_draw_remote_effects(screen):
    """매 프레임: 상대방 이펙트 렌더링 (로컬 타이머 기반)

    지원하는 이펙트 타입:
    - br_spin: 바이퍼 회전 모션 (패들 회전은 anim state 처리)
    - blade: 바이퍼 에어 블레이드 검기
    - nerve: 바이퍼 베놈 엣지 (돌진/베기)
    - bullet: 솔저 새총/권총 탄환
    - bazooka: 솔저 바주카 로켓
    - ak: AK-47 총알
    - net_proj: 그물총 투사체
    - net: 설치된 그물
    - trap: 볼링 트랩
    - drone: 자폭 드론
    - turret: 발토르 터렛 투사체
    - hshock: 발토르 해머 쇼크 투사체
    - divine: 발토르 디바인 스톤 설치
    - divine_destroy: 디바인 스톤 파괴
    """
    now = pygame.time.get_ticks()
    for ef in _online_remote_effects:
        if not ef.get('_alive', False):
            continue
        elapsed = now - ef.get('_start_ms', 0)
        ef_type = ef.get('e', '')
        try:
            if ef_type == 'br_spin':
                pass
            elif ef_type == 'blade':
                _bx = int(ef.get('x', 0))
                _by = int(ef.get('y', 0))
                _bhw = int(ef.get('hw', 175))
                _dur = ef.get('dur', 800)
                _progress = min(1.0, elapsed / max(1, _dur))
                _fade_start = 0.65
                _fade_fac = max(0.0, min(1.0, (_progress - _fade_start) / (1.0 - _fade_start))) if _progress > _fade_start else 0.0
                _alive = 1.0 - _fade_fac
                if _alive > 0.01:
                    _travel = 250 * _progress
                    _draw_y = _by + _travel if ef.get('dir') == 'down' else _by - _travel
                    _draw_viper_blade_rush(screen, _bx, int(_draw_y), _bhw, _alive, flip_y=(ef.get('dir') == 'down'))
                else:
                    ef['_alive'] = False
            elif ef_type == 'nerve':
                _dur = ef.get('dur', 600)
                _progress = min(1.0, elapsed / max(1, _dur))
                _ncx = int(ef.get('tx', BOSS.centerx))
                _ncy = int(ef.get('ty', BOSS.centery))
                if _progress < 0.3:
                    for _gi in range(3):
                        _ga = max(30, 80 - _gi * 25)
                        _gs = pygame.Surface((40, 60), pygame.SRCALPHA)
                        _gs.fill((180, 0, 220, _ga))
                        screen.blit(_gs, (_ncx - 20 + _gi * 15, _ncy - 30))
                elif _progress < 0.7:
                    _t_now = pygame.time.get_ticks()
                    for _ai in range(2):
                        _a = math.radians(_t_now * 0.5 + _ai * 180)
                        _arc_r = 60
                        _sx = int(_ncx + math.cos(_a) * _arc_r)
                        _sy = int(_ncy + math.sin(_a) * _arc_r)
                        _ex = int(_ncx + math.cos(_a + 2.0) * _arc_r)
                        _ey = int(_ncy + math.sin(_a + 2.0) * _arc_r)
                        pygame.draw.line(screen, (200, 0, 255), (_sx, _sy), (_ex, _ey), 3)
                else:
                    ef['_alive'] = False
            elif ef_type == 'bullet':
                _bx = float(ef.get('x', 0))
                _by = float(ef.get('y', 0))
                _bvx = float(ef.get('vx', 0))
                _bvy = float(ef.get('vy', 0))
                _charge = ef.get('c', 1)
                _dur = ef.get('dur', 1500)
                _dt = elapsed / 1000.0
                _cx = int(_bx + _bvx * _dt * 60)
                _cy = int(_by + _bvy * _dt * 60)
                if _cx < -20 or _cx > WIDTH + 20 or _cy < -20 or _cy > HEIGHT + 20:
                    ef['_alive'] = False
                    continue
                _bu_r = max(3, 4 + _charge)
                pygame.draw.circle(screen, (180, 180, 180), (_cx, _cy), _bu_r)
                pygame.draw.circle(screen, (255, 255, 240), (_cx - 1, _cy - 1), max(1, _bu_r - 2))
                if _charge >= 3:
                    _glow_s = pygame.Surface((_bu_r * 4, _bu_r * 4), pygame.SRCALPHA)
                    pygame.draw.circle(_glow_s, (255, 215, 0, 80), (_bu_r * 2, _bu_r * 2), _bu_r * 2)
                    screen.blit(_glow_s, (_cx - _bu_r * 2, _cy - _bu_r * 2))
            elif ef_type == 'bazooka':
                _bx = float(ef.get('x', 0))
                _by = float(ef.get('y', 0))
                _dur = ef.get('dur', 2000)
                _dt = elapsed / 1000.0
                _speed = float(ef.get('spd', 12))
                _dy_dir = 1 if ef.get('dir') == 'down' else -1
                _cy = int(_by + _dy_dir * _speed * _dt * 60)
                _cx = int(_bx)
                if _cy < -30 or _cy > HEIGHT + 30:
                    ef['_alive'] = False
                    continue
                pygame.draw.rect(screen, (100, 100, 100), (_cx - 4, _cy - 10, 8, 20))
                pygame.draw.polygon(screen, (200, 50, 30), [
                    (_cx, _cy - 14 * _dy_dir), (_cx - 5, _cy - 6 * _dy_dir), (_cx + 5, _cy - 6 * _dy_dir)])
                for _si in range(3):
                    _sa = max(30, 80 - _si * 25)
                    _ss = pygame.Surface((8 + _si * 4, 8 + _si * 4), pygame.SRCALPHA)
                    pygame.draw.circle(_ss, (200, 200, 200, _sa), (4 + _si * 2, 4 + _si * 2), 4 + _si * 2)
                    screen.blit(_ss, (_cx - 4 - _si * 2, _cy + 10 * _dy_dir + _si * 8 * _dy_dir))
            elif ef_type == 'ak':
                _bx = float(ef.get('x', 0))
                _by = float(ef.get('y', 0))
                _dx = float(ef.get('dx', 0))
                _dy = float(ef.get('dy', 0))
                _dt = elapsed / 1000.0
                _cx = int(_bx + _dx * _dt * 60)
                _cy = int(_by + _dy * _dt * 60)
                if _cx < -20 or _cx > WIDTH + 20 or _cy < -20 or _cy > HEIGHT + 20:
                    ef['_alive'] = False
                    continue
                pygame.draw.circle(screen, (255, 220, 50), (_cx, _cy), 3)
                pygame.draw.circle(screen, (255, 255, 200), (_cx, _cy), 1)
            elif ef_type == 'net_proj':
                _bx = float(ef.get('x', 0))
                _by = float(ef.get('y', 0))
                _dur = ef.get('dur', 1000)
                _dt = elapsed / 1000.0
                _dy_dir = 1 if ef.get('dir') == 'down' else -1
                _cy = int(_by + _dy_dir * 10 * _dt * 60)
                _cx = int(_bx)
                if _cy < -20 or _cy > HEIGHT + 20:
                    ef['_alive'] = False
                    continue
                pygame.draw.circle(screen, (60, 180, 60), (_cx, _cy), 6)
                pygame.draw.circle(screen, (120, 255, 120), (_cx, _cy), 3)
            elif ef_type == 'net':
                _nx = int(ef.get('x', 0))
                _ny = int(ef.get('y', 0))
                _nw = int(ef.get('w', 60))
                _nh = int(ef.get('h', 20))
                _dur = ef.get('dur', 5000)
                _ns = pygame.Surface((_nw, _nh), pygame.SRCALPHA)
                _ns.fill((30, 160, 30, 80))
                for _gi in range(0, _nw, 8):
                    pygame.draw.line(_ns, (60, 200, 60, 120), (_gi, 0), (_gi, _nh))
                for _gi in range(0, _nh, 6):
                    pygame.draw.line(_ns, (60, 200, 60, 120), (0, _gi), (_nw, _gi))
                screen.blit(_ns, (_nx - _nw // 2, _ny - _nh // 2))
            elif ef_type == 'trap':
                _tx = int(ef.get('x', 0))
                _ty = int(ef.get('y', 0))
                _dur = ef.get('dur', 10000)
                pygame.draw.circle(screen, (80, 80, 80), (_tx, _ty), 8)
                pygame.draw.circle(screen, (200, 50, 30), (_tx, _ty), 5)
                pygame.draw.circle(screen, (255, 100, 50), (_tx, _ty), 2)
            elif ef_type == 'drone':
                _dx = float(ef.get('x', 0))
                _dy = float(ef.get('y', 0))
                _ttx = float(ef.get('tx', WIDTH // 2))
                _tty = float(ef.get('ty', HEIGHT // 2))
                _dur = ef.get('dur', 3000)
                _prog = min(1.0, elapsed / max(1, _dur))
                _cx = int(_dx + (_ttx - _dx) * _prog)
                _cy = int(_dy + (_tty - _dy) * _prog)
                _dr_t = now
                pygame.draw.rect(screen, (60, 60, 70), (_cx - 12, _cy - 6, 24, 12), border_radius=3)
                for _di in range(4):
                    _da = math.radians(_dr_t * 0.8 + _di * 90)
                    _aex = _cx + int(math.cos(_da) * 14)
                    _aey = _cy + int(math.sin(_da) * 14)
                    pygame.draw.line(screen, (80, 80, 90), (_cx, _cy), (_aex, _aey), 2)
                    _pa = math.radians(_dr_t * 3 + _di * 90)
                    pygame.draw.line(screen, (180, 180, 190),
                                     (_aex + int(math.cos(_pa) * 6), _aey + int(math.sin(_pa) * 6)),
                                     (_aex - int(math.cos(_pa) * 6), _aey - int(math.sin(_pa) * 6)), 2)
                if (now // 200) % 2 == 0:
                    pygame.draw.circle(screen, (255, 50, 30), (_cx, _cy), 3)
            elif ef_type == 'turret':
                _tx = float(ef.get('x', 0))
                _ty = float(ef.get('y', 0))
                _dur = ef.get('dur', 1500)
                _dt = elapsed / 1000.0
                _dy_dir = 1 if ef.get('dir') == 'down' else -1
                _cy = int(_ty + _dy_dir * 8 * _dt * 60)
                _cx = int(_tx)
                if _cy < -20 or _cy > HEIGHT + 20:
                    ef['_alive'] = False
                    continue
                pygame.draw.circle(screen, (255, 200, 50), (_cx, _cy), 5)
                pygame.draw.circle(screen, (255, 255, 200), (_cx, _cy), 3)
            elif ef_type == 'hshock':
                _hx = float(ef.get('x', 0))
                _hy = float(ef.get('y', 0))
                _stage = ef.get('s', 0)
                _dur = ef.get('dur', 1500)
                _dt = elapsed / 1000.0
                _dy_dir = 1 if ef.get('dir') == 'down' else -1
                _cy = int(_hy + _dy_dir * 10 * _dt * 60)
                _cx = int(_hx)
                if _cy < -30 or _cy > HEIGHT + 30:
                    ef['_alive'] = False
                    continue
                _hs_r = max(6, 8 + _stage * 3)
                _hs_colors = [(200, 160, 60), (255, 120, 30), (255, 60, 30), (255, 30, 200)]
                _hs_c = _hs_colors[min(_stage, 3)]
                _hs_gs = pygame.Surface((_hs_r * 4, _hs_r * 4), pygame.SRCALPHA)
                pygame.draw.circle(_hs_gs, (*_hs_c, 60), (_hs_r * 2, _hs_r * 2), _hs_r * 2)
                screen.blit(_hs_gs, (_cx - _hs_r * 2, _cy - _hs_r * 2))
                pygame.draw.circle(screen, _hs_c, (_cx, _cy), _hs_r)
                pygame.draw.circle(screen, (255, 255, 220), (_cx, _cy), max(2, _hs_r - 3))
            elif ef_type == 'divine':
                _dv_x = int(ef.get('x', 0))
                _dv_y = int(ef.get('y', 0))
                _dur = ef.get('dur', 30000)
                _dv_r = 18
                _dv_pts = []
                for _hi in range(6):
                    _ha = math.radians(60 * _hi - 30)
                    _dv_pts.append((_dv_x + int(math.cos(_ha) * _dv_r), _dv_y + int(math.sin(_ha) * _dv_r)))
                pygame.draw.polygon(screen, (140, 120, 80), _dv_pts)
                pygame.draw.polygon(screen, (200, 180, 100), _dv_pts, 2)
            elif ef_type == 'divine_destroy':
                _online_remote_effects[:] = [e for e in _online_remote_effects if e.get('e') != 'divine']
                ef['_alive'] = False
        except Exception:
            ef['_alive'] = False


# ────────────────────────────────────────────────────────────────────────
# [6-E] _online_get_my_anim_state() 함수 (line ~171365)
# ────���───────────────────────────────────────────────────────────────────

def _online_get_my_anim_state():
    """내 PLAYER의 현재 애니메이션 상태를 간략하게 수집"""
    st = selected_character_type
    anim = {'state': 'idle', 'char': st}
    try:
        if st == "smasher":
            if globals().get('smasher_walking_active', False):
                anim['state'] = 'walking'
            elif globals().get('smasher_hit_pose_timer', 0) > 0:
                anim['state'] = 'hit'
        elif st == "soldier":
            if globals().get('slingshot_pose_active', False) or globals().get('slingshot_charging', False):
                anim['state'] = 'slingshot'
            elif globals().get('soldier_swing_active', False):
                anim['state'] = 'swing'
            elif globals().get('soldier_walking_active', False):
                anim['state'] = 'walking'
        elif st == "blacksmith":
            if globals().get('blacksmith_umbrella_open', False):
                anim['state'] = 'umbrella'
                anim['progress'] = globals().get('blacksmith_umbrella_anim_timer', 0) / max(1, globals().get('blacksmith_umbrella_anim_duration', 30))
            elif globals().get('blacksmith_shield_swing_active', False):
                anim['state'] = 'shield_swing'
            elif globals().get('blacksmith_hammer_swing_active', False):
                anim['state'] = 'hammer_swing'
            elif globals().get('blacksmith_walking_active', False):
                anim['state'] = 'walking'
        elif st == "viper":
            _jp_active = globals().get('_viper_jetpack_active', False)
            _jp_offset = globals().get('_viper_jetpack_offset_y', 0)
            if _jp_active or _jp_offset < -5:
                anim['state'] = 'flying'
                anim['jetpack_offset'] = _jp_offset
            elif globals().get('_viper_wall_dive_active', False):
                anim['state'] = 'wall_dive'
                anim['phase'] = globals().get('_viper_wall_dive_phase', 0)
            elif globals().get('viper_hit_pose_timer', 0) > 0:
                anim['state'] = 'hit'
            elif globals().get('viper_walking_active', False):
                anim['state'] = 'walking'
                anim['walk_phase'] = globals().get('viper_walking_timer', 0)
        elif st == "optimus":
            if abs(globals().get('current_speed', 0)) > 1.0:
                anim['state'] = 'walking'

        # 회전 모션만 anim state로 유지 (패들 회전에 필요)
        if globals().get('_viper_br_spin_active', False):
            anim['br_spin_angle'] = globals().get('_viper_br_spin_angle', 0)

    except Exception:
        pass
    return anim


# ────────────────────────────────────────────────────────────────────────
# [6-F] _online_send_game_state() 함수 (line ~171420)
# ────────────────────────────────────────────────────────────────────────

def _online_send_game_state():
    """호스트: 매 프레임 게임 상태를 클라이언트에 전송"""
    if not online_multiplayer_enabled or not online_is_host:
        return
    if _online_net_manager is None or not _online_net_manager.connections:
        return

    global _online_sound_queue

    # 아이템 목록 직렬화 (클라이언트에 전송용)
    _serialized_items = []
    try:
        for _fi in items.item_list:
            _fi_type = _fi.get('type', {})
            _fi_name = _fi_type.get('name', '') if isinstance(_fi_type, dict) else ''
            _serialized_items.append({
                'x': _fi.get('x', 0),
                'y': _fi.get('y', 0),
                'name': _fi_name,
                'angle': _fi.get('angle', 0),
                'revealed': _fi_type.get('revealed', False) if isinstance(_fi_type, dict) else False,
            })
    except Exception:
        _serialized_items = []

    frame_data = {
        'frame_num': pygame.time.get_ticks(),
        'ball': [BALL.x, BALL.y, ball_vel[0], ball_vel[1]],
        'p1': [PLAYER.x, 0, round_wins],
        'p2': [BOSS.x, 0, round_losses],
        'items': _serialized_items,
        'sounds': _online_sound_queue[:],
        'effects': [],
        'game_over': None,
        'waiting_serve': is_waiting_for_serve,
        'player_serve': is_player_serve,
        'round_wins': round_wins,
        'round_losses': round_losses,
        'p1_stunned': False,
        'p1_dashing': False,
        'p2_stunned': False,
        'p2_dashing': False,
        'ball_spin': 0,
        'ball_intensity': 0,
        'p1_anim': _online_get_my_anim_state(),
        'client_pickups': _online_client_pickups[:],
    }
    _online_client_pickups.clear()

    try:
        if round_wins >= win_goal:
            frame_data['game_over'] = 'p1'
        elif round_losses >= win_goal:
            frame_data['game_over'] = 'p2'
    except NameError:
        pass

    _dbg_key = '_online_dbg_last_serve_state'
    _dbg_cur = (is_waiting_for_serve, is_player_serve)
    if globals().get(_dbg_key) != _dbg_cur:
        globals()[_dbg_key] = _dbg_cur
        print(f"[Online Serve DEBUG] HOST frame_data: waiting_serve={is_waiting_for_serve} player_serve={is_player_serve} BALL=({BALL.x},{BALL.y}) vel={ball_vel}")

    serialized = serialize_game_frame(frame_data)
    _online_net_manager.send_online_packet(OnlinePacketType.GAME_FRAME, serialized)
    _online_sound_queue.clear()


# ────────────────────────────────────────────────────────────────────────
# [6-G] _online_send_player_position() 함수 (line ~171489)
# ────────────────────────────────────────────────────────────────────────

def _online_send_player_position():
    """클라이언트: 매 프레임 내 PLAYER 위치를 호스트에 전송"""
    if not online_multiplayer_enabled or online_is_host:
        return
    if _online_net_manager is None or not _online_net_manager.connections:
        return

    global _online_client_serve_pressed
    _serve_input = _online_client_serve_pressed
    if _serve_input:
        print(f"[Online Serve DEBUG] CLIENT: 서브 입력 호스트로 전송!")
        _online_client_serve_pressed = False

    _online_net_manager.send_online_packet(
        OnlinePacketType.GAME_INPUT,
        {'x': PLAYER.x, 'anim': _online_get_my_anim_state(), 'serve': _serve_input}
    )


# ────────────────────────────────────────────────────────────────────────
# [6-H] _online_client_apply_state() 함수 (line ~171509)
# ────────────────────────────────────────────────────────────────────────

def _online_client_apply_state():
    """클라이언트: 호스트에서 수신한 게임 상태를 적용
    - 공 위치/속도 -> 호스트 권위
    - 점수 -> 호스트 권위 (시점 반전: 호스트 round_wins = 내 round_losses)
    - BOSS 위치 -> _handle_boss_online_sync()에서 이미 처리
    """
    global round_wins, round_losses, _online_opponent_anim
    global is_waiting_for_serve, is_player_serve

    if not online_multiplayer_enabled or online_is_host:
        return
    if _online_net_manager is None:
        return

    frame = _online_net_manager.get_online_game_frame()
    if frame is None:
        return

    # 상대방(호스트) 애니메이션 상태 저장
    p1_anim = frame.get('p1_anim', None)
    if p1_anim:
        _online_opponent_anim = p1_anim

    # 공 위치 동기화 (호스트 권위) - Y축 반전!
    host_waiting = frame.get('waiting_serve', False)
    ball = frame.get('ball', None)
    if ball and len(ball) >= 4:
        BALL.x = int(ball[0])
        BALL.y = HEIGHT - int(ball[1]) - BALL.height  # Y축 반전
        if host_waiting:
            ball_vel[0] = 0
            ball_vel[1] = 0
        else:
            ball_vel[0] = ball[2]
            ball_vel[1] = -ball[3]  # Y 속도도 반전

    # 서브 상태 동기화 (시점 반전!)
    host_waiting = frame.get('waiting_serve', False)
    host_player_serve = frame.get('player_serve', False)
    _prev_waiting = is_waiting_for_serve
    _prev_player_serve = is_player_serve
    if host_waiting:
        is_waiting_for_serve = True
        is_player_serve = not host_player_serve  # 시점 반전!
    elif is_waiting_for_serve and not host_waiting:
        is_waiting_for_serve = False
    if _prev_waiting != is_waiting_for_serve or _prev_player_serve != is_player_serve:
        print(f"[Online Serve DEBUG] CLIENT sync: host_waiting={host_waiting} host_player_serve={host_player_serve} -> is_waiting={is_waiting_for_serve} is_player_serve={is_player_serve}")

    # 클라이언트 아이템 획득 처리 (호스트가 감지한 BOSS 충돌)
    client_pickups = frame.get('client_pickups', [])
    for _cp in client_pickups:
        _cp_name = _cp.get('name', '')
        _cp_color = tuple(_cp.get('color', [200, 200, 200]))
        _cp_x = _cp.get('x', 0)
        _cp_y = HEIGHT - _cp.get('y', 0)  # Y반전
        if _cp_name:
            try:
                if SOUND_ITEM_GET:
                    SOUND_ITEM_GET.play()
            except Exception:
                pass
            _cp_data = {
                "name": _cp_name,
                "color": _cp_color,
                "effect": _cp_name,
                "icon": None,
                "x": _cp_x,
                "y": _cp_y,
            }
            _passive_names = {"speedboots", "speedgear", "battery", "slot_add", "revival", "master", "cooltime", "chargebag", "spikeboots", "dashgear", "sensor", "bulkup", "dashholder", "gravitybelt", "dowsing_pendulum", "commando_arm", "technical_vest", "fuel_pouch", "bluetooth_ring", "star_detector", "foul_whistle", "smartphone", "knee_pads", "ragnarok_hammer", "hermes_shoes", "poseidon_trident", "angel_blessing", "sacred_laurel", "transcendent_crown", "odins_eye", "pandora_legacy", "bulletproof_hat", "spiked_helmet", "gold_bar", "gold_digger", "hero_seal", "lucky_coin", "adversity_armor", "shrapnel_armor", "soul_burst", "sage_ring", "venom_mist_gauntlet"}
            if _cp_name in _passive_names:
                store_passive_item(_cp_data)
            else:
                store_active_item(_cp_data)
            print(f"[Online Item] CLIENT: 아이템 획득! {_cp_name}")

    # 아이템 동기화 (호스트가 보낸 아이템 목록을 Y반전하여 표시)
    remote_items = frame.get('items', [])
    if remote_items:
        _synced_items = []
        for _ri in remote_items:
            _synced_items.append({
                'x': _ri.get('x', 0),
                'y': HEIGHT - _ri.get('y', 0),  # Y축 반전
                'vel': [0, 0],
                'type': {'name': _ri.get('name', ''), 'revealed': _ri.get('revealed', False)},
                'angle': _ri.get('angle', 0),
                'bounce_count': 0,
                'max_bounces': 999,
            })
        items.item_list = _synced_items
    else:
        items.item_list = []

    # 점수 동기화 (시점 반전!)
    round_wins = frame.get('round_losses', 0)
    round_losses = frame.get('round_wins', 0)


# ────────────────────────────────────────────────────────────────────────
# [6-I] _draw_viper_blade_rush() - 바이퍼 에어 블레이드 공유 렌더링 함수
#       (line ~107162) - 온라인 이펙트 렌더링에서도 호출됨
# ────────────────────────────────────────────────────────────────────────

def _draw_viper_blade_rush(screen, cx, cy, half_w, alive, trail=None, flip_y=False):
    """에어 블레이드 검기 공통 렌더링. flip_y=True면 아래->위 대신 위->아래 방향.

    다층 부채꼴 본체 + 에지 라인 + 에너지 스파크 + 꼭짓점 글로우 + 앰비언트 헤일로.
    약 110줄의 pygame.draw 기반 프리미엄 이펙트 렌더링.
    상세 코드는 pingfighter.py line 107162~107270 참조.
    """
    pass  # 전체 렌더링 코드는 pingfighter.py 참조 (약 110줄)


# ────────────────────────────────────────────────────────────────────────
# [6-J] 온라인 상대 캐릭터 렌더링 (보스 그리기 섹션, line ~108904)
#       current_stage == 40 일 때 보스 스프라이트 생성
# ────────────────────────────────────────────────────────────────────────
#
# 위치: pingfighter.py line 108904~108989
# 로직:
#   - online_p2_character로 상대 캐릭터 타입 결정
#   - _online_opponent_anim에서 애니메이션 상태 읽기
#   - 캐릭터별 스프라이트 함수 호출 (walking, hit, slingshot, umbrella 등)
#   - flip 없이 원본 스프라이트 그대로 사용 (뒷모습)
#   - 바이퍼 에어 블레이드 회전 모션: br_spin_angle로 패들 회전


# ────────────────────────────────────────────────────────────────────────
# [6-K] 온라인 제트팩/이펙트 렌더링 (보스 그리기 하단, line ~109636)
# ────────────────────────────────────────────────────────────────────────
#
# 위치: pingfighter.py line 109636~109663
# 로직:
#   - 바이퍼 제트팩: _online_opponent_anim.state=='flying' 시 불꽃 이펙트
#   - 이펙트 수신/업데이트/렌더링: _online_receive_effects() -> _online_update_remote_effects() -> _online_draw_remote_effects(SCREEN)


# ────────────────────────────────────────────────────────────────────────
# [6-L] 게임 루프 통합 포인트들 (pingfighter.py 내 인라인 코드)
# ────────────────────────────────────────────────────────────────────────

# --- [6-L-1] 아이템 스폰 제한 (line ~161312) ---
# 온라인 클라이언트는 아이템 스폰 안 함 (호스트가 관리)
# if not (online_multiplayer_enabled and not online_is_host):
#     items.spawn_random_item()

# --- [6-L-2] 아이템 업데이트 + 호스트 BOSS 충돌 체크 (line ~161798) ---
# 온라인 클라이언트는 아이템 물리/획득 처리 안 함 (호스트가 관리)
# 호스트: BOSS(클라이언트) 위치의 아이템 충돌 -> _online_client_pickups에 추가

# --- [6-L-3] 클라이언트 점수 보호 (line ~162462) ---
# handle_ball() 전에 점수 저장, 후에 되돌리기 (호스트만 점수 권위)

# --- [6-L-4] 매 프레임 상태 동기화 (line ~163875) ---
# if online_multiplayer_enabled:
#     if online_is_host: _online_send_game_state()
#     else: _online_send_player_position(); _online_client_apply_state()

# --- [6-L-5] 클라이언트 서브 입력 (이벤트 루프, line ~160365) ---
# 온라인 클라이언트: 로컬 서브 실행 안 하고 _online_client_serve_pressed 플래그만 세움

# --- [6-L-6] go_to_next_round 서브 결정 (line ~141283) ---
# current_stage == 40: 호스트만 랜덤 서브 결정, 클라이언트는 프레임 데이터로 동기화

# --- [6-L-7] _handle_boss_with_soap_debuff 내 온라인 분기 (line ~152376) ---
# online_multiplayer_enabled이면 _handle_boss_online_sync() 호출 후 즉시 return
