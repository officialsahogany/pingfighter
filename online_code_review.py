"""
========================================================================
PingFighter 온라인 대전 코드 전체 모음 (코드 리뷰용)
========================================================================
이 파일은 실행용이 아닌 코드 리뷰용으로, 온라인 대전 관련 코드를
모든 파일에서 추출하여 하나로 정리한 것입니다.

파일 구성:
  1. network/protocol.py       - 프로토콜 정의, 직렬화/역직렬화
  2. network/network_manager.py - 소켓 기반 네트워크 매니저 (싱글톤)
  3. network/online_game.py     - 온라인 로비/캐릭터/스테이지 선택 UI
  4. network/client_renderer.py - 클라이언트 전용 렌더러 (Y축 반전)
  5. ui/network_ui.py           - 네트워크 UI (호스트/조인 메뉴)
  6. pingfighter.py (발췌)      - 메인 게임 루프 내 온라인 통합 코드

아키텍처 요약:
  - TCP 소켓 기반 P2P 연결 (호스트-클라이언트 모델)
  - 호스트가 물리/게임 로직 권위를 가짐 (공 위치, 점수, 아이템 등)
  - 클라이언트는 입력(패들 위치)을 호스트에 전송하고, 게임 상태를 수신
  - Y축 반전으로 양쪽 모두 자기 패들이 아래에 보이도록 처리
  - AI 대전 모드: 네트워크 없이 AI가 BOSS를 조작 (테스트용)
========================================================================
"""


# ========================================================================
# [1/6] network/protocol.py - 프로토콜 정의
# ========================================================================

from enum import IntEnum
import json
import struct
import socket
import threading
import time
import os
import math
import pygame
from typing import Dict, Any, Optional, Callable, List
from enum import Enum
from dataclasses import dataclass, asdict


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

    def __init__(self, socket_obj: socket.socket, address: tuple):
        self.socket = socket_obj
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

            # 오래된 시퀀스 제거 (60Hz × 2방향 = 초당 ~120패킷)
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
    """네트워크 매니저 (싱글톤)"""

    def __init__(self):
        # NOTE: 실제 코드에서는 GlobalManager 싱글톤을 사용
        # self.global_manager = GlobalManager.get_instance()

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

        # 온라인 멀티플레이 상태
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
            OnlinePacketType.ONLINE_PING: self._handle_online_ping,
            OnlinePacketType.ONLINE_PONG: self._handle_online_pong,
            OnlinePacketType.ONLINE_DISCONNECT: self._handle_online_disconnect,
        }

    def _handle_online_lobby_state(self, packet, connection):
        self.online_lobby_state = deserialize_lobby_state(packet.data)

    def _handle_online_char_select(self, packet, connection):
        if self.online_lobby_state:
            if self.mode == NetworkMode.HOST:
                self.online_lobby_state['client_character'] = packet.data.get('character')
            else:
                self.online_lobby_state['host_character'] = packet.data.get('character')

    def _handle_online_stage_select(self, packet, connection):
        if self.online_lobby_state:
            self.online_lobby_state['stage'] = packet.data.get('stage', 1)
            self.online_lobby_state['items_enabled'] = packet.data.get('items', True)

    def _handle_online_lobby_ready(self, packet, connection):
        if self.online_lobby_state:
            ready = packet.data.get('ready', False)
            if self.mode == NetworkMode.HOST:
                self.online_lobby_state['client_ready'] = ready
            else:
                self.online_lobby_state['host_ready'] = ready

    def _handle_online_lobby_start(self, packet, connection):
        self.online_game_started = True

    def _handle_online_game_input(self, packet, connection):
        # 위치 기반 입력 (x 필드) 또는 버튼 기반 입력 모두 지원
        data = packet.data
        if 'x' in data:
            # 위치 직접 전송 방식
            self.online_remote_input = data
        else:
            self.online_remote_input = deserialize_input(data)

    def _handle_online_game_frame(self, packet, connection):
        self.online_game_frame = deserialize_game_frame(packet.data)

    def _handle_online_game_event(self, packet, connection):
        # 이벤트 처리 (점수 변경, 게임 오버 등)
        pass

    def _handle_online_ping(self, packet, connection):
        # 핑 응답 전송
        self.send_online_packet(OnlinePacketType.ONLINE_PONG,
                                {'t': packet.data.get('t', 0)}, connection)

    def _handle_online_pong(self, packet, connection):
        sent_time = packet.data.get('t', 0)
        if sent_time > 0:
            connection.latency = (time.time() - sent_time) * 1000

    def _handle_online_disconnect(self, packet, connection):
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

    def reset_online_state(self):
        """온라인 대전 상태 초기화"""
        self.online_mode = False
        self.online_lobby_state = None
        self.online_remote_input = None
        self.online_game_frame = None
        self.online_connected = False
        self.online_game_started = False
        self.online_opponent_name = ""

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
            'player_name': 'Player',  # 실제로는 GlobalManager에서 가져옴
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
            # PONG 응답 → 레이턴시 계산
            sent_time = packet.data.get('timestamp', 0)
            if sent_time > 0:
                connection.latency = (time.time() - sent_time) * 1000
        else:
            # PING 요청 → PONG 응답 전송
            self.handle_ping(packet, connection)

    def sync_game_state(self):
        """게임 상태 동기화 (호스트) - 비 온라인 모드용"""
        if not self.connections:
            return
        # 실제 코드에서는 GlobalManager에서 게임 상태를 가져와 전송
        pass

    def handle_game_state(self, packet: NetworkPacket, connection: NetworkConnection):
        """게임 상태 처리 (클라이언트)"""
        if self.mode == NetworkMode.CLIENT:
            self.sync_state = packet.data
            self.apply_sync_state()

    def apply_sync_state(self):
        """동기화 상태 적용"""
        # 실제 코드에서는 GlobalManager를 통해 게임 오브젝트에 적용
        pass

    def send_input(self, input_data: Dict[str, Any]):
        """입력 전송"""
        if self.mode in [NetworkMode.HOST, NetworkMode.CLIENT]:
            data = {
                'input': input_data,
                'frame': 0  # 실제로는 GlobalManager에서 frame_count 가져옴
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
        self.input_buffer = [i for i in self.input_buffer
                            if i['frame'] > frame - 60]

    def handle_sync(self, packet: NetworkPacket, connection: NetworkConnection):
        """동기화 패킷 처리"""
        sync_data = packet.data
        self.sync_state.update(sync_data)
        self.apply_sync_state()

    def handle_score_update(self, packet: NetworkPacket, connection: NetworkConnection):
        """점수 업데이트 처리"""
        # 실제 코드에서는 GlobalManager를 통해 점수 설정
        pass

    def get_remote_input(self) -> Optional[Dict[str, Any]]:
        """원격 입력 가져오기"""
        if not self.input_buffer:
            return None
        # 현재 프레임에 해당하는 입력 찾기
        for input_data in self.input_buffer:
            if abs(input_data['frame']) <= self.input_delay:
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
# [3/6] network/online_game.py - 온라인 로비/매칭 UI
# ========================================================================

# ── IP 히스토리 저장/로드 ──
_IP_HISTORY_FILE = "ip_history.json"
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


# 캐릭터 목록
CHARACTERS = [
    {"id": "ufo_player", "name": "스매셔", "color": (0, 200, 255),
     "stats": {"속도": 4, "파워": 7, "방어": 4}},
    {"id": "soldier", "name": "코만도", "color": (100, 200, 100),
     "stats": {"속도": 6, "파워": 6, "방어": 6}},
    {"id": "blacksmith", "name": "발토르", "color": (255, 180, 50),
     "stats": {"속도": 5, "파워": 7, "방어": 5}},
    {"id": "viper", "name": "바이퍼", "color": (180, 50, 255),
     "stats": {"속도": 4, "파워": 5, "방어": 3}},
]

# 스테이지 목록
STAGES = [
    {"num": 1, "name": "풍악보이 스테이지", "color": (120, 80, 60)},
    {"num": 2, "name": "악어장군 스테이지", "color": (40, 120, 50)},
    {"num": 3, "name": "멘헤라걸 스테이지", "color": (180, 80, 150)},
    {"num": 4, "name": "퐁크 스테이지", "color": (200, 160, 60)},
    {"num": 5, "name": "네메시스 스테이지", "color": (40, 80, 160)},
    {"num": 6, "name": "홍련 스테이지", "color": (200, 50, 30)},
]

# UI 색상
BG_COLOR = (18, 22, 32)
PANEL_COLOR = (30, 36, 50)
ACCENT_COLOR = (0, 180, 255)
READY_COLOR = (50, 220, 100)
TEXT_COLOR = (220, 225, 235)
DIM_COLOR = (100, 110, 130)
HIGHLIGHT_COLOR = (255, 220, 50)


class OnlineMultiplayer:
    """온라인 멀티플레이 관리 클래스"""

    def __init__(self, screen, width, height, get_font_func=None):
        self.screen = screen
        self.width = width
        self.height = height
        self.get_font = get_font_func or (lambda s, **kw: pygame.font.Font(None, s))
        self.clock = pygame.time.Clock()
        self.net = get_network_manager()
        self.running = True

        # 로비 상태
        self.is_host = False
        self.my_character_idx = 0
        self.my_ready = False
        self.opponent_ready = False
        self.selected_stage_idx = 0
        self.items_enabled = True
        self.opponent_character_idx = -1

        # 결과
        self.result_p1_char = None
        self.result_p2_char = None
        self.result_stage = 1
        self.result_items = True
        self.game_should_start = False

    def run(self):
        """메인 플로우: 모드 선택 → 접속 → 로비 → 게임 시작"""
        mode = self._show_mode_select()
        if mode is None:
            return None

        # AI 대전 모드: 네트워크 접속 없이 바로 결과 반환
        if mode == "ai_test":
            return self._run_ai_test_mode()

        self.is_host = (mode == "host")

        if self.is_host:
            success = self._host_wait_screen()
        else:
            success = self._client_connect_screen()

        if not success:
            self.net.disconnect()
            self.net.reset_online_state()
            return None

        # 로비
        result = self._lobby_screen()
        if result is None:
            self.net.disconnect()
            self.net.reset_online_state()
            return None

        return result

    # ──────────────────────────────────────────────
    # 모드 선택 화면 (호스트/참가)
    # ──────────────────────────────────────────────
    def _show_mode_select(self):
        """호스트/참가 선택. 'host', 'join', 또는 None(취소)"""
        selected = 0
        options = ["방 만들기 (호스트)", "참가하기", "AI 대전 (테스트)", "뒤로"]
        option_rects = []

        while self.running:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    return None
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE:
                        return None
                    if event.key in (pygame.K_UP, pygame.K_w):
                        selected = (selected - 1) % len(options)
                    if event.key in (pygame.K_DOWN, pygame.K_s):
                        selected = (selected + 1) % len(options)
                    if event.key in (pygame.K_RETURN, pygame.K_SPACE):
                        if selected == 0:
                            return "host"
                        elif selected == 1:
                            return "join"
                        elif selected == 2:
                            return "ai_test"
                        else:
                            return None
                if event.type == pygame.MOUSEMOTION:
                    mx, my = event.pos
                    for i, r in enumerate(option_rects):
                        if r.collidepoint(mx, my):
                            selected = i
                if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                    mx, my = event.pos
                    for i, r in enumerate(option_rects):
                        if r.collidepoint(mx, my):
                            if i == 0:
                                return "host"
                            elif i == 1:
                                return "join"
                            elif i == 2:
                                return "ai_test"
                            else:
                                return None

            self.screen.fill(BG_COLOR)
            title_font = self.get_font(36)
            option_font = self.get_font(24)

            title_surf = title_font.render("온라인 대전", True, ACCENT_COLOR)
            title_rect = title_surf.get_rect(center=(self.width // 2, 120))
            self.screen.blit(title_surf, title_rect)

            option_rects = []
            for i, opt in enumerate(options):
                is_sel = i == selected
                color = HIGHLIGHT_COLOR if is_sel else TEXT_COLOR
                btn_rect = pygame.Rect(self.width // 2 - 160, 258 + i * 60, 320, 44)
                option_rects.append(btn_rect)
                bg = (40, 50, 70) if is_sel else PANEL_COLOR
                pygame.draw.rect(self.screen, bg, btn_rect, border_radius=8)
                pygame.draw.rect(self.screen, color, btn_rect, 2 if is_sel else 1, border_radius=8)
                surf = option_font.render(opt, True, color)
                self.screen.blit(surf, surf.get_rect(center=btn_rect.center))

            hint_font = self.get_font(16)
            hint = hint_font.render("↑↓/마우스 선택  Enter/클릭 확인  ESC 뒤로", True, DIM_COLOR)
            self.screen.blit(hint, hint.get_rect(center=(self.width // 2, self.height - 40)))

            pygame.display.flip()
            self.clock.tick(60)
        return None

    # ──────────────────────────────────────────────
    # 호스트 대기 화면
    # ──────────────────────────────────────────────
    def _host_wait_screen(self):
        """호스트 시작, 상대방 접속 대기. True/False"""
        success = self.net.start_host(DEFAULT_PORT)
        if not success:
            self._show_message("서버 시작 실패", "포트가 사용 중일 수 있습니다.", 2.0)
            return False

        self.net.online_mode = True
        local_ip = self.net.get_local_ip()
        dots_timer = 0

        while self.running:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    return False
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE:
                        return False

            # 상대방 접속 확인
            if self.net.connections:
                self.net.online_connected = True
                # 핸드셰이크 대기
                time.sleep(0.3)
                # 로비 초기 상태 전송
                self._init_lobby_state()
                return True

            # UI
            self.screen.fill(BG_COLOR)
            title_font = self.get_font(28)
            info_font = self.get_font(22)
            ip_font = self.get_font(32)

            title = title_font.render("상대방 대기 중", True, ACCENT_COLOR)
            self.screen.blit(title, title.get_rect(center=(self.width // 2, 150)))

            # IP 표시
            ip_label = info_font.render("접속 IP:", True, DIM_COLOR)
            self.screen.blit(ip_label, ip_label.get_rect(center=(self.width // 2, 280)))

            ip_text = ip_font.render(f"{local_ip}:{DEFAULT_PORT}", True, HIGHLIGHT_COLOR)
            ip_rect = ip_text.get_rect(center=(self.width // 2, 320))
            # 배경 박스
            box_rect = ip_rect.inflate(40, 20)
            pygame.draw.rect(self.screen, PANEL_COLOR, box_rect, border_radius=8)
            pygame.draw.rect(self.screen, ACCENT_COLOR, box_rect, 2, border_radius=8)
            self.screen.blit(ip_text, ip_rect)

            dots_timer = (dots_timer + 1) % 180
            dots = "." * ((dots_timer // 30) % 4)
            wait_text = info_font.render(f"대기 중{dots}", True, DIM_COLOR)
            self.screen.blit(wait_text, wait_text.get_rect(center=(self.width // 2, 420)))

            hint = self.get_font(16).render("이 IP를 상대방에게 알려주세요. ESC 취소", True, DIM_COLOR)
            self.screen.blit(hint, hint.get_rect(center=(self.width // 2, self.height - 40)))

            pygame.display.flip()
            self.clock.tick(60)
        return False

    # ──────────────────────────────────────────────
    # 클라이언트 접속 화면 (IP 입력)
    # ──────────────────────────────────────────────
    def _try_connect(self, ip_str):
        """IP 문자열로 접속 시도. 성공 시 True + 히스토리 저장."""
        host = ip_str.strip()
        if not host:
            return False, "IP를 입력하세요"
        port = DEFAULT_PORT
        if ":" in host:
            parts = host.rsplit(":", 1)
            host = parts[0]
            try:
                port = int(parts[1])
            except ValueError:
                pass
        success = self.net.connect_to_host(host, port)
        if success:
            self.net.online_mode = True
            self.net.online_connected = True
            _add_ip_to_history(ip_str.strip())
            time.sleep(0.3)
            return True, ""
        return False, "접속 실패 - IP 주소를 확인하세요"

    def _client_connect_screen(self):
        """IP 입력 → 접속. True/False"""
        ip_history = _load_ip_history()
        ip_text = ip_history[0] if ip_history else ""
        connecting = False
        error_msg = ""
        cursor_timer = 0
        history_rects = []

        while self.running:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    return False
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE:
                        if connecting:
                            connecting = False
                        else:
                            return False
                    elif event.key == pygame.K_RETURN and not connecting:
                        connecting = True
                        error_msg = ""
                        ok, err = self._try_connect(ip_text)
                        if ok:
                            return True
                        connecting = False
                        error_msg = err
                    elif event.key == pygame.K_BACKSPACE:
                        ip_text = ip_text[:-1]
                    elif not connecting:
                        if event.unicode and event.unicode.isprintable():
                            if len(ip_text) < 21:
                                ip_text += event.unicode
                # 마우스: 히스토리 클릭
                if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1 and not connecting:
                    mx, my = event.pos
                    for i, rect in enumerate(history_rects):
                        if rect.collidepoint(mx, my) and i < len(ip_history):
                            if ip_text.strip() == ip_history[i]:
                                # 이미 선택된 IP 다시 클릭 → 바로 접속
                                connecting = True
                                error_msg = ""
                                ok, err = self._try_connect(ip_text)
                                if ok:
                                    return True
                                connecting = False
                                error_msg = err
                            else:
                                ip_text = ip_history[i]
                            break

            # UI 렌더링 (간략화)
            self.screen.fill(BG_COLOR)
            # ... IP 입력 필드, 히스토리 목록, 힌트 등 렌더링 ...
            pygame.display.flip()
            self.clock.tick(60)
        return False

    # ──────────────────────────────────────────────
    # 로비 화면
    # ──────────────────────────────────────────────
    def _lobby_screen(self):
        """로비: 캐릭터 선택 + 스테이지 선택 + 레디"""
        self._init_lobby_state()
        self.my_character_idx = 0
        self.my_ready = False
        self.selected_stage_idx = 0
        self.items_enabled = True
        focus = "character"  # "character", "stage", "items", "ready"

        # 마우스 클릭 히트 영역
        self._lobby_hit = {
            'char_left': None, 'char_right': None, 'char_box': None,
            'stage_left': None, 'stage_right': None, 'stage_box': None,
            'items_box': None, 'ready_btn': None,
        }

        while self.running:
            # 네트워크 상태 체크
            if not self.net.online_connected and not self.net.connections:
                self._show_message("연결 끊김", "상대방과의 연결이 끊어졌습니다.", 2.0)
                return None

            # 로비 상태 동기화 수신 처리
            if self.net.online_lobby_state:
                lobby = self.net.online_lobby_state
                if self.is_host:
                    opp_char = lobby.get('client_character')
                    self.opponent_ready = lobby.get('client_ready', False)
                else:
                    opp_char = lobby.get('host_character')
                    self.opponent_ready = lobby.get('host_ready', False)
                    self.selected_stage_idx = max(0, lobby.get('stage', 1) - 1)
                    self.items_enabled = lobby.get('items_enabled', True)

                if opp_char:
                    self.opponent_character_idx = next(
                        (i for i, c in enumerate(CHARACTERS) if c["id"] == opp_char), -1)

            # 게임 시작 확인
            if self.net.online_game_started:
                return self._build_result()

            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    return None
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE:
                        if self.my_ready:
                            self.my_ready = False
                            self._send_ready(False)
                        else:
                            return None
                    elif not self.my_ready:
                        self._handle_lobby_input(event, focus)
                        if event.key == pygame.K_TAB:
                            if focus == "character":
                                focus = "stage" if self.is_host else "ready"
                            elif focus == "stage":
                                focus = "items"
                            elif focus == "items":
                                focus = "ready"
                            else:
                                focus = "character"
                    if event.key in (pygame.K_RETURN, pygame.K_SPACE):
                        if focus == "ready" or self.my_ready:
                            self.my_ready = not self.my_ready
                            self._send_ready(self.my_ready)
                            if self.is_host and self.my_ready and self.opponent_ready:
                                self._send_game_start()
                                return self._build_result()

                # 마우스 클릭 처리
                if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                    mx, my = event.pos
                    h = self._lobby_hit
                    if not self.my_ready:
                        if h['char_left'] and h['char_left'].collidepoint(mx, my):
                            self.my_character_idx = (self.my_character_idx - 1) % len(CHARACTERS)
                            self._send_char_select()
                        elif h['char_right'] and h['char_right'].collidepoint(mx, my):
                            self.my_character_idx = (self.my_character_idx + 1) % len(CHARACTERS)
                            self._send_char_select()
                        if self.is_host:
                            if h['stage_left'] and h['stage_left'].collidepoint(mx, my):
                                self.selected_stage_idx = (self.selected_stage_idx - 1) % len(STAGES)
                                self._send_stage_select()
                            elif h['stage_right'] and h['stage_right'].collidepoint(mx, my):
                                self.selected_stage_idx = (self.selected_stage_idx + 1) % len(STAGES)
                                self._send_stage_select()
                        if self.is_host and h['items_box'] and h['items_box'].collidepoint(mx, my):
                            self.items_enabled = not self.items_enabled
                            self._send_stage_select()
                    if h['ready_btn'] and h['ready_btn'].collidepoint(mx, my):
                        self.my_ready = not self.my_ready
                        self._send_ready(self.my_ready)
                        if self.is_host and self.my_ready and self.opponent_ready:
                            self._send_game_start()
                            return self._build_result()

            self._draw_lobby(focus)
            pygame.display.flip()
            self.clock.tick(60)
        return None

    def _handle_lobby_input(self, event, focus):
        """로비 키보드 입력 처리"""
        if focus == "character":
            if event.key in (pygame.K_LEFT, pygame.K_a):
                self.my_character_idx = (self.my_character_idx - 1) % len(CHARACTERS)
                self._send_char_select()
            elif event.key in (pygame.K_RIGHT, pygame.K_d):
                self.my_character_idx = (self.my_character_idx + 1) % len(CHARACTERS)
                self._send_char_select()
        elif focus == "stage" and self.is_host:
            if event.key in (pygame.K_LEFT, pygame.K_a):
                self.selected_stage_idx = (self.selected_stage_idx - 1) % len(STAGES)
                self._send_stage_select()
            elif event.key in (pygame.K_RIGHT, pygame.K_d):
                self.selected_stage_idx = (self.selected_stage_idx + 1) % len(STAGES)
                self._send_stage_select()
        elif focus == "items" and self.is_host:
            if event.key in (pygame.K_LEFT, pygame.K_RIGHT, pygame.K_a, pygame.K_d):
                self.items_enabled = not self.items_enabled
                self._send_stage_select()

    def _draw_lobby(self, focus):
        """로비 화면 그리기 (캐릭터 선택, 스테이지 선택, 레디 버튼 등)"""
        self.screen.fill(BG_COLOR)
        cx = self.width // 2
        # ... 캐릭터 패널, 스테이지 패널, 아이템 토글, 레디 버튼 등 렌더링 ...
        # (렌더링 코드는 원본 참조 - _draw_character_panel, _draw_stage_panel 등)

    # ──────────────────────────────────────────────
    # 네트워크 통신
    # ──────────────────────────────────────────────
    def _init_lobby_state(self):
        """로비 초기 상태 설정"""
        lobby = {
            'host_character': CHARACTERS[0]["id"],
            'client_character': None,
            'stage': 1,
            'items_enabled': True,
            'host_ready': False,
            'client_ready': False,
            'host_name': 'Player 1',
            'client_name': 'Player 2',
        }
        self.net.online_lobby_state = lobby
        if self.is_host:
            self.net.send_online_packet(
                OnlinePacketType.LOBBY_STATE,
                serialize_lobby_state(lobby))

    def _send_char_select(self):
        """내 캐릭터 선택 전송"""
        char_id = CHARACTERS[self.my_character_idx]["id"]
        self.net.send_online_packet(
            OnlinePacketType.CHAR_SELECT,
            {'character': char_id})
        if self.net.online_lobby_state:
            if self.is_host:
                self.net.online_lobby_state['host_character'] = char_id
            else:
                self.net.online_lobby_state['client_character'] = char_id

    def _send_stage_select(self):
        """스테이지/아이템 설정 전송 (호스트만)"""
        if not self.is_host:
            return
        stage_num = STAGES[self.selected_stage_idx]["num"]
        self.net.send_online_packet(
            OnlinePacketType.STAGE_SELECT,
            {'stage': stage_num, 'items': self.items_enabled})
        if self.net.online_lobby_state:
            self.net.online_lobby_state['stage'] = stage_num
            self.net.online_lobby_state['items_enabled'] = self.items_enabled

    def _send_ready(self, ready):
        """레디 상태 전송"""
        self.net.send_online_packet(
            OnlinePacketType.LOBBY_READY,
            {'ready': ready})
        if self.net.online_lobby_state:
            if self.is_host:
                self.net.online_lobby_state['host_ready'] = ready
            else:
                self.net.online_lobby_state['client_ready'] = ready

    def _send_game_start(self):
        """게임 시작 신호 전송 (호스트)"""
        self.net.send_online_packet(OnlinePacketType.LOBBY_START, {})
        self.net.online_game_started = True

    # ──────────────────────────────────────────────
    # 결과 빌드
    # ──────────────────────────────────────────────
    def _build_result(self):
        """로비 결과 → 게임 시작 정보 반환"""
        my_char = CHARACTERS[self.my_character_idx]["id"]
        opp_char = (CHARACTERS[self.opponent_character_idx]["id"]
                     if self.opponent_character_idx >= 0 else "ufo_player")
        stage = STAGES[self.selected_stage_idx]["num"]

        if self.is_host:
            return {
                'is_host': True,
                'p1_character': my_char,
                'p2_character': opp_char,
                'stage': stage,
                'items_enabled': self.items_enabled,
            }
        else:
            return {
                'is_host': False,
                'p1_character': opp_char,  # 호스트가 P1
                'p2_character': my_char,   # 나(클라이언트)가 P2
                'stage': stage,
                'items_enabled': self.items_enabled,
            }

    # ──────────────────────────────────────────────
    # AI 대전 모드
    # ──────────────────────────────────────────────
    def _run_ai_test_mode(self):
        """AI 대전: 내 캐릭터 선택 → AI 스매셔와 대전"""
        selected = 0
        char_rects = []

        while self.running:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    return None
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE:
                        return None
                    if event.key in (pygame.K_LEFT, pygame.K_a):
                        selected = (selected - 1) % len(CHARACTERS)
                    if event.key in (pygame.K_RIGHT, pygame.K_d):
                        selected = (selected + 1) % len(CHARACTERS)
                    if event.key in (pygame.K_RETURN, pygame.K_SPACE):
                        my_char = CHARACTERS[selected]["id"]
                        return {
                            'is_host': True,
                            'p1_character': my_char,
                            'p2_character': 'ufo_player',  # AI는 항상 스매셔
                            'stage': 1,
                            'items_enabled': True,
                            'ai_test': True,
                        }
                # 마우스 클릭 처리
                if event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                    mx, my = event.pos
                    for i, r in enumerate(char_rects):
                        if r.collidepoint(mx, my):
                            my_char = CHARACTERS[selected]["id"]
                            return {
                                'is_host': True,
                                'p1_character': my_char,
                                'p2_character': 'ufo_player',
                                'stage': 1,
                                'items_enabled': True,
                                'ai_test': True,
                            }

            # UI 렌더링 (간략화)
            self.screen.fill(BG_COLOR)
            # ... 캐릭터 선택 UI 렌더링 ...
            pygame.display.flip()
            self.clock.tick(60)
        return None

    # ──────────────────────────────────────────────
    # 유틸리티
    # ──────────────────────────────────────────────
    def _show_message(self, title, subtitle, duration=2.0):
        """간단한 메시지 표시"""
        start = time.time()
        while time.time() - start < duration:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    return
            self.screen.fill(BG_COLOR)
            t_font = self.get_font(28)
            s_font = self.get_font(18)
            t_surf = t_font.render(title, True, (255, 80, 80))
            s_surf = s_font.render(subtitle, True, DIM_COLOR)
            self.screen.blit(t_surf, t_surf.get_rect(center=(self.width // 2, self.height // 2 - 20)))
            self.screen.blit(s_surf, s_surf.get_rect(center=(self.width // 2, self.height // 2 + 20)))
            pygame.display.flip()
            self.clock.tick(60)


def run_online_multiplayer(screen, width, height, get_font_func=None):
    """온라인 멀티플레이 진입점"""
    online = OnlineMultiplayer(screen, width, height, get_font_func)
    return online.run()


# ========================================================================
# [4/6] network/client_renderer.py - 클라이언트 렌더러
# ========================================================================

# 색상
CR_BG_COLOR = (18, 22, 32)
CR_P1_COLOR = (0, 150, 255)      # 호스트 (상대방) - 파란색
CR_P2_COLOR = (255, 100, 100)    # 나 (클라이언트) - 빨간색
CR_BALL_COLOR = (255, 255, 255)
CR_TEXT_COLOR = (220, 225, 235)
CR_DIM_COLOR = (100, 110, 130)
CR_ACCENT_COLOR = (0, 180, 255)
CR_SCORE_COLOR = (255, 220, 50)


class ClientRenderer:
    """클라이언트 렌더링 루프.
    호스트에서 GAME_FRAME 패킷을 수신하여 화면에 렌더링한다.
    (NOTE: 현재는 사용되지 않음 - 클라이언트도 main(40)을 통해 렌더링)
    """

    def __init__(self, screen, width, height, get_font_func, net_manager):
        self.screen = screen
        self.width = width
        self.height = height
        self.get_font = get_font_func
        self.net = net_manager
        self.clock = pygame.time.Clock()
        self.running = True

        # 게임 상태
        self.ball_x = width // 2
        self.ball_y = height // 2
        self.ball_vx = 0
        self.ball_vy = 0
        self.p1_x = width // 2 - 50  # 상대방 (호스트)
        self.p2_x = width // 2 - 50  # 나 (클라이언트)
        self.p1_score = 0
        self.p2_score = 0
        self.p1_gauge = 0
        self.p2_gauge = 0
        self.game_over = None
        self.waiting_serve = False
        self.round_wins = 0   # 호스트 기준 (P1 승리 수)
        self.round_losses = 0 # 호스트 기준 (P2 승리 수 = 내 승리 수)

        # P2 패들 예측 (로컬 입력 즉시 반영)
        self.local_p2_x = width // 2 - 50
        self.local_input = {}

        # 볼 트레일
        self.ball_trail = []
        self.max_trail = 8

        # 연결 상태
        self.disconnect_timer = 0
        self.last_frame_time = time.time()

        # 패들 크기
        self.paddle_width = 100
        self.paddle_height = 15
        self.ball_size = 12

    def run(self):
        """클라이언트 메인 루프"""
        while self.running:
            dt = self.clock.tick(60) / 1000.0

            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    self.running = False
                    return
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE:
                        self.running = False
                        return

            self._collect_and_send_input()
            self._receive_state()

            # 연결 체크
            time_since_last = time.time() - self.last_frame_time
            if not self.net.connections:
                self.disconnect_timer += dt
                if self.disconnect_timer > 10.0:
                    self._show_disconnect()
                    return
            elif time_since_last > 10.0:
                self._show_disconnect()
                return
            else:
                self.disconnect_timer = 0

            self._draw()
            pygame.display.flip()

            if self.game_over:
                self._show_result()
                return

    def _collect_and_send_input(self):
        """로컬 입력 수집 → 서버 전송 + 로컬 패들 예측"""
        keys = pygame.key.get_pressed()

        self.local_input = {
            'left': keys[pygame.K_LEFT] or keys[pygame.K_a],
            'right': keys[pygame.K_RIGHT] or keys[pygame.K_d],
            'up': keys[pygame.K_UP] or keys[pygame.K_w],
            'down': keys[pygame.K_DOWN] or keys[pygame.K_s],
            'dash': keys[pygame.K_LSHIFT] or keys[pygame.K_RSHIFT] or keys[pygame.K_SPACE],
            'skill_q': keys[pygame.K_q],
            'skill_w': keys[pygame.K_w],
            'skill_e': keys[pygame.K_e],
            'mouse_left': pygame.mouse.get_pressed()[0],
            'mouse_right': pygame.mouse.get_pressed()[2],
            'mouse_x': pygame.mouse.get_pos()[0],
            'mouse_y': pygame.mouse.get_pos()[1],
        }

        serialized = serialize_input(self.local_input)
        self.net.send_online_packet(OnlinePacketType.GAME_INPUT, serialized)

        # 로컬 패들 예측
        speed = 8
        if self.local_input['dash']:
            speed = 20
        if self.local_input['left']:
            self.local_p2_x -= speed
        if self.local_input['right']:
            self.local_p2_x += speed
        self.local_p2_x = max(0, min(self.width - self.paddle_width, self.local_p2_x))

    def _receive_state(self):
        """호스트에서 수신한 게임 프레임 적용"""
        frame = self.net.online_game_frame
        if frame is None:
            return

        self.last_frame_time = time.time()

        ball = frame.get('ball', [0, 0, 0, 0])
        self.ball_x = ball[0]
        self.ball_y = ball[1]
        self.ball_vx = ball[2]
        self.ball_vy = ball[3]

        p1 = frame.get('p1', [0, 0, 0])
        p2 = frame.get('p2', [0, 0, 0])
        self.p1_x = p1[0]
        self.p1_gauge = p1[1]
        self.round_wins = frame.get('round_wins', 0)
        self.round_losses = frame.get('round_losses', 0)

        # P2 서버 위치로 보정 (예측과 블렌딩)
        server_p2_x = p2[0]
        self.local_p2_x = self.local_p2_x + (server_p2_x - self.local_p2_x) * 0.5
        self.p2_x = self.local_p2_x

        self.p2_gauge = p2[1]
        self.game_over = frame.get('game_over', None)
        self.waiting_serve = frame.get('waiting_serve', False)

        # 트레일 업데이트
        self.ball_trail.append((self.ball_x + self.ball_size // 2,
                                self.ball_y + self.ball_size // 2))
        if len(self.ball_trail) > self.max_trail:
            self.ball_trail.pop(0)

    def _flip_y(self, y, obj_height=0):
        """Y축 반전 (P2 시점: 자기 패들이 아래에 보이도록)"""
        return self.height - y - obj_height

    def _draw(self):
        """게임 화면 그리기 (Y 반전)"""
        self.screen.fill(CR_BG_COLOR)
        center_y = self.height // 2
        for x in range(0, self.width, 20):
            pygame.draw.rect(self.screen, (40, 45, 55), (x, center_y - 1, 10, 2))

        # 볼 트레일 (Y 반전)
        for i, (tx, ty) in enumerate(self.ball_trail):
            alpha = int(60 * (i + 1) / len(self.ball_trail)) if self.ball_trail else 0
            size = max(2, int(self.ball_size * 0.5 * (i + 1) / max(1, len(self.ball_trail))))
            trail_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
            pygame.draw.circle(trail_surf, (255, 255, 255, alpha), (size, size), size)
            flipped_ty = self._flip_y(ty - size, 0)
            self.screen.blit(trail_surf, (tx - size, flipped_ty))

        # 볼 (Y 반전)
        ball_draw_y = self._flip_y(self.ball_y, self.ball_size)
        glow_surf = pygame.Surface((40, 40), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (255, 255, 255, 30), (20, 20), 18)
        self.screen.blit(glow_surf, (self.ball_x + self.ball_size // 2 - 20,
                                      ball_draw_y + self.ball_size // 2 - 20))
        pygame.draw.circle(self.screen, CR_BALL_COLOR,
                           (int(self.ball_x + self.ball_size // 2),
                            int(ball_draw_y + self.ball_size // 2)),
                           self.ball_size // 2)

        # 패들: 상대방(P1) → 상단
        p1_draw_y = self._flip_y(710, self.paddle_height)
        pygame.draw.rect(self.screen, CR_P1_COLOR,
                         (self.p1_x, p1_draw_y, self.paddle_width, self.paddle_height),
                         border_radius=4)

        # 패들: 나(P2) → 하단
        p2_draw_y = self._flip_y(25, self.paddle_height)
        pygame.draw.rect(self.screen, CR_P2_COLOR,
                         (self.p2_x, p2_draw_y, self.paddle_width, self.paddle_height),
                         border_radius=4)

        # 스코어 (Y 반전)
        score_font = self.get_font(36)
        my_score = self.round_losses  # 내 승리 = 호스트 기준 round_losses
        opp_score = self.round_wins

        my_score_surf = score_font.render(str(my_score), True, CR_SCORE_COLOR)
        opp_score_surf = score_font.render(str(opp_score), True, CR_SCORE_COLOR)
        self.screen.blit(my_score_surf,
                         my_score_surf.get_rect(center=(self.width // 2, self.height - 60)))
        self.screen.blit(opp_score_surf,
                         opp_score_surf.get_rect(center=(self.width // 2, 60)))

        # 핑 표시
        if self.net.connections:
            ping = self.net.connections[0].latency
            ping_font = self.get_font(12)
            ping_text = ping_font.render(f"Ping: {ping:.0f}ms", True, CR_DIM_COLOR)
            self.screen.blit(ping_text, (self.width - 90, 5))

    def _show_result(self):
        """게임 결과 표시"""
        result_time = time.time()
        i_won = (self.game_over == 'p2')

        while time.time() - result_time < 5.0:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    return
                if event.type == pygame.KEYDOWN:
                    return

            self.screen.fill(CR_BG_COLOR)
            result_font = self.get_font(48)
            if i_won:
                title = result_font.render("승리!", True, CR_SCORE_COLOR)
            else:
                title = result_font.render("패배", True, (255, 80, 80))
            self.screen.blit(title, title.get_rect(center=(self.width // 2, self.height // 2 - 40)))
            pygame.display.flip()
            self.clock.tick(60)

    def _show_disconnect(self):
        """연결 끊김 화면"""
        start = time.time()
        while time.time() - start < 3.0:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    return
            self.screen.fill(CR_BG_COLOR)
            font = self.get_font(28)
            text = font.render("연결이 끊어졌습니다", True, (255, 80, 80))
            self.screen.blit(text, text.get_rect(center=(self.width // 2, self.height // 2)))
            pygame.display.flip()
            self.clock.tick(60)


def run_client_renderer(screen, width, height, get_font_func, net_manager):
    """클라이언트 렌더러 진입점"""
    renderer = ClientRenderer(screen, width, height, get_font_func, net_manager)
    renderer.run()


# ========================================================================
# [5/6] ui/network_ui.py - 네트워크 UI (메뉴)
# ========================================================================

class NetworkUI:
    """네트워크 UI 시스템 (호스트/조인 메뉴)"""

    def __init__(self, screen: pygame.Surface):
        self.screen = screen
        self.network_manager = get_network_manager()

        # UI 상태
        self.active = False
        self.current_menu = 'main'  # main, host, join, lobby
        self.selected_option = 0

        # 입력 필드
        self.input_active = False
        self.input_field = ''
        self.input_type = None  # 'port' or 'address'

        # 연결 정보
        self.host_port = '12345'
        self.join_address = '127.0.0.1'
        self.join_port = '12345'

        # 로비 정보
        self.lobby_players = []
        self.ready_state = False

        # 폰트
        try:
            self.font_title = pygame.font.Font("NanumSquareEB.ttf", 48)
            self.font_large = pygame.font.Font("NanumSquareB.ttf", 36)
            self.font_medium = pygame.font.Font("NanumSquareR.ttf", 24)
            self.font_small = pygame.font.Font("NanumSquareR.ttf", 18)
        except:
            self.font_title = pygame.font.Font(None, 48)
            self.font_large = pygame.font.Font(None, 36)
            self.font_medium = pygame.font.Font(None, 24)
            self.font_small = pygame.font.Font(None, 18)

        # 애니메이션
        self.animation_timer = 0
        self.pulse_effect = 0

        # 메뉴 옵션
        self.menu_options = {
            'main': ['Host Game', 'Join Game', 'Back'],
            'host': ['Start Hosting', 'Change Port', 'Back'],
            'join': ['Connect', 'Change Address', 'Change Port', 'Back'],
            'lobby': ['Ready', 'Start Game', 'Leave']
        }

    def open(self):
        """네트워크 UI 열기"""
        self.active = True
        self.current_menu = 'main'
        self.selected_option = 0

    def close(self):
        """네트워크 UI 닫기"""
        self.active = False
        self.input_active = False

    def handle_event(self, event: pygame.event.Event):
        """이벤트 처리"""
        if not self.active:
            return
        if self.input_active:
            self._handle_input_event(event)
        else:
            self._handle_menu_event(event)

    def _handle_menu_event(self, event):
        """메뉴 이벤트 처리"""
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                if self.current_menu == 'main':
                    self.close()
                else:
                    self.current_menu = 'main'
                    self.selected_option = 0
            elif event.key == pygame.K_UP:
                options = self.menu_options[self.current_menu]
                self.selected_option = (self.selected_option - 1) % len(options)
            elif event.key == pygame.K_DOWN:
                options = self.menu_options[self.current_menu]
                self.selected_option = (self.selected_option + 1) % len(options)
            elif event.key == pygame.K_RETURN:
                self._execute_option()

    def _handle_input_event(self, event):
        """입력 필드 이벤트 처리"""
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                self.input_active = False
                self.input_field = ''
            elif event.key == pygame.K_RETURN:
                self._confirm_input()
            elif event.key == pygame.K_BACKSPACE:
                self.input_field = self.input_field[:-1]
            else:
                if event.unicode and len(self.input_field) < 15:
                    self.input_field += event.unicode

    def _execute_option(self):
        """선택한 옵션 실행"""
        option = self.menu_options[self.current_menu][self.selected_option]

        if self.current_menu == 'main':
            if option == 'Host Game':
                self.current_menu = 'host'
                self.selected_option = 0
            elif option == 'Join Game':
                self.current_menu = 'join'
                self.selected_option = 0
            elif option == 'Back':
                self.close()
        elif self.current_menu == 'host':
            if option == 'Start Hosting':
                self._start_hosting()
            elif option == 'Change Port':
                self.input_active = True
                self.input_type = 'host_port'
                self.input_field = self.host_port
            elif option == 'Back':
                self.current_menu = 'main'
                self.selected_option = 0
        elif self.current_menu == 'join':
            if option == 'Connect':
                self._join_game()
            elif option == 'Change Address':
                self.input_active = True
                self.input_type = 'join_address'
                self.input_field = self.join_address
            elif option == 'Change Port':
                self.input_active = True
                self.input_type = 'join_port'
                self.input_field = self.join_port
            elif option == 'Back':
                self.current_menu = 'main'
                self.selected_option = 0
        elif self.current_menu == 'lobby':
            if option == 'Ready':
                self._toggle_ready()
            elif option == 'Start Game':
                self._start_multiplayer_game()
            elif option == 'Leave':
                self._leave_lobby()

    def _confirm_input(self):
        """입력 확인"""
        if self.input_type == 'host_port':
            try:
                port = int(self.input_field)
                if 1024 <= port <= 65535:
                    self.host_port = self.input_field
            except:
                pass
        elif self.input_type == 'join_address':
            if '.' in self.input_field or self.input_field == 'localhost':
                self.join_address = self.input_field
        elif self.input_type == 'join_port':
            try:
                port = int(self.input_field)
                if 1024 <= port <= 65535:
                    self.join_port = self.input_field
            except:
                pass
        self.input_active = False
        self.input_field = ''

    def _start_hosting(self):
        """호스팅 시작"""
        port = int(self.host_port)
        if self.network_manager.start_host(port):
            self.current_menu = 'lobby'
            self.selected_option = 0
            self.lobby_players = ['Host (You)']

    def _join_game(self):
        """게임 참가"""
        port = int(self.join_port)
        if self.network_manager.connect_to_host(self.join_address, port):
            self.current_menu = 'lobby'
            self.selected_option = 0
            self.lobby_players = ['Host', 'You']

    def _toggle_ready(self):
        """준비 상태 토글"""
        self.ready_state = not self.ready_state
        self.network_manager.send_packet(
            PacketType.READY,
            {'ready': self.ready_state}
        )

    def _start_multiplayer_game(self):
        """멀티플레이어 게임 시작"""
        if self.network_manager.mode == NetworkMode.HOST:
            self.network_manager.send_packet(
                PacketType.START_GAME,
                {'stage': 1}
            )
            self.close()

    def _leave_lobby(self):
        """로비 나가기"""
        self.network_manager.disconnect()
        self.current_menu = 'main'
        self.selected_option = 0
        self.lobby_players = []

    def update(self, dt: float):
        """업데이트"""
        if not self.active:
            return
        self.animation_timer += dt
        self.pulse_effect = abs(math.sin(self.animation_timer * 2)) * 0.3 + 0.7

        if self.current_menu == 'lobby':
            if self.network_manager.mode == NetworkMode.OFFLINE:
                self.current_menu = 'main'
                self.selected_option = 0
                self.lobby_players = []

    def render(self, screen):
        """렌더링 (메뉴 화면에 따라 분기)"""
        if not self.active:
            return
        # ... 각 메뉴 화면별 렌더링 로직 ...


# 싱글톤 인스턴스
_network_ui = None

def get_network_ui(screen) -> NetworkUI:
    """네트워크 UI 싱글톤 반환"""
    global _network_ui
    if _network_ui is None:
        _network_ui = NetworkUI(screen)
    return _network_ui


# ========================================================================
# [6/6] pingfighter.py 내 온라인 관련 코드 (발췌)
# ========================================================================
#
# 아래는 메인 게임 파일(pingfighter.py, ~170,000줄)에서
# 온라인 멀티플레이와 관련된 코드만 발췌한 것입니다.
#
# 원본 위치(줄 번호)를 주석으로 표시합니다.
# ========================================================================


# ── [pingfighter.py:22606~22613] 전역 변수 ──
# online_multiplayer_enabled = False   # 온라인 대전 모드 활성화
# online_is_host = False               # True=호스트(P1), False=클라이언트(P2)
# online_p2_character = "ufo_player"   # P2 캐릭터 ID
# online_items_enabled = True          # 아이템 드랍 활성화
# online_p2_input = None               # P2 최신 입력 (network에서 수신)
# _online_net_manager = None           # NetworkManager 참조 (캐싱용)
# _online_sound_queue = []             # 이번 프레임 사운드 큐 (클라이언트 전송용)

# ── [pingfighter.py:170896~170900] 추가 전역 변수 ──
# _online_opponent_anim = {'state': 'idle'}  # 상대방 수신 애니메이션 상태
# _online_client_serve_pressed = False  # 클라이언트 서브 입력 플래그 (이벤트 기반)
# _online_client_pickups = []  # 호스트→클라이언트: 클라이언트가 획득한 아이템 목록
# _online_ai_boss_enabled = False  # AI 대전 모드: BOSS를 AI가 조작
# _online_ai_boss_controller = None  # AI 컨트롤러 인스턴스


# ── [pingfighter.py:170826~170892] 온라인 멀티플레이 진입점 ──
def start_online_multiplayer():
    """온라인 멀티플레이 진입점.
    로비 → 캐릭터/스테이지 선택 → 양쪽 모두 main(40) 실행.
    호스트(P1): 공 물리 권위, BOSS=P2 위치 수신
    클라이언트(P2): BOSS=P1 위치 수신, 공=호스트에서 수신
    """
    global online_multiplayer_enabled, online_is_host, online_p2_character
    global online_items_enabled, _online_net_manager, online_p2_input
    global selected_character_type

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

    # 필러 UI 활성화
    global _pillar_ui_enabled
    _pillar_ui_enabled = True

    # 양쪽 모두 main(40) 실행 → 본게임 엔진 그대로 렌더링
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


# ── [pingfighter.py:170903~171077] 애니메이션 상태 수집 ──
def _online_get_my_anim_state():
    """내 PLAYER의 현재 애니메이션 상태를 간략하게 수집.
    캐릭터별 상태(idle/walking/hit/flying 등)와
    스킬 이펙트(검기, 총알, 터렛 등) 데이터를 dict로 반환.
    이 데이터는 네트워크로 상대방에게 전송되어 상대 화면에서 렌더링됨.
    """
    st = selected_character_type
    anim = {'state': 'idle', 'char': st}
    try:
        # 캐릭터별 상태 수집
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
                anim['jetpack_offset'] = _jp_offset  # 제트팩 높이 오프셋 전송
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

        # ── 스킬 이펙트 데이터 (모든 캐릭터 공통) ──
        _fx = []

        # 바이퍼: 에어 블레이드 회전 모션
        if globals().get('_viper_br_spin_active', False):
            _fx.append({
                't': 'br_spin',
                'a': globals().get('_viper_br_spin_angle', 0),
                'p': globals().get('_viper_br_spin_phase', 0),
            })
        # 바이퍼: 에어 블레이드 (검기)
        if globals().get('_viper_blade_rush_active', False):
            _br_y = globals().get('_viper_blade_rush_y', 0)
            _br_sy = globals().get('_viper_blade_rush_start_y', 0)
            _br_ty = globals().get('_viper_blade_rush_target_y', 0)
            _br_prog = 1.0 - ((_br_y - _br_ty) / max(1, _br_sy - _br_ty)) if (_br_sy - _br_ty) > 0 else 1.0
            _br_prog = max(0.0, min(1.0, _br_prog))
            _br_fo = globals().get('_viper_blade_rush_fadeout', False)
            _br_fo_t = globals().get('_viper_blade_rush_fadeout_timer', 0)
            _br_trail = list(globals().get('_viper_blade_rush_trail', []))[-10:]
            _fx.append({
                't': 'blade',
                'x': globals().get('_viper_blade_rush_x', 0),
                'y': globals().get('_viper_blade_rush_y', 0),
                'hw': globals().get('_viper_blade_rush_width', 350) // 2,
                'pr': _br_prog,
                'fo': 1 if _br_fo else 0,
                'ft': _br_fo_t,
                'tr': _br_trail,
            })
        # 바이퍼: 베놈 엣지 (연계기)
        if globals().get('_viper_nerve_strike_active', False):
            _fx.append({
                't': 'nerve',
                'p': globals().get('_viper_nerve_strike_phase', 0),
            })
        # 솔저: 새총/권총 탄환
        _bullets = globals().get('soldier_bullets', [])
        for _sb in _bullets[:10]:
            if _sb.get('active', False):
                _fx.append({
                    't': 'bullet',
                    'x': _sb.get('x', 0),
                    'y': _sb.get('y', 0),
                    'c': _sb.get('charge_level', 1),
                })
        # 솔저: 바주카 투사체
        try:
            from item_effects.bazooka import get_bazooka_instance
            _baz = get_bazooka_instance()
            if _baz and getattr(_baz, 'projectiles', None):
                for _bp in _baz.projectiles[:4]:
                    if _bp.get('active', False):
                        _fx.append({'t': 'bazooka', 'x': _bp.get('x', 0), 'y': _bp.get('y', 0)})
        except Exception:
            pass
        # 솔저: AK-47 총알
        try:
            from item_effects.ak47 import get_ak47_instance
            _ak = get_ak47_instance()
            if _ak and getattr(_ak, 'bullets', None):
                for _ab in _ak.bullets[:15]:
                    _fx.append({'t': 'ak', 'x': _ab.get('x', 0), 'y': _ab.get('y', 0)})
        except Exception:
            pass
        # 솔저: 그물총 투사체 + 그물
        try:
            from item_effects.net_gun import get_net_gun_instance
            _ng = get_net_gun_instance()
            if _ng:
                for _np in getattr(_ng, 'projectiles', [])[:4]:
                    _fx.append({'t': 'net_proj', 'x': _np.get('x', 0), 'y': _np.get('y', 0)})
                for _nn in getattr(_ng, 'nets', [])[:4]:
                    _nr = _nn.get('rect')
                    if _nr:
                        _fx.append({'t': 'net', 'x': _nr.centerx, 'y': _nr.centery, 'w': _nr.width, 'h': _nr.height})
        except Exception:
            pass
        # 솔저: 볼링 트랩
        try:
            from item_effects.bowling_trap import get_bowling_trap_instance
            _bt = get_bowling_trap_instance()
            if _bt:
                for _tr in getattr(_bt, 'traps', [])[:6]:
                    _fx.append({'t': 'trap', 'x': _tr.get('x', 0), 'y': _tr.get('y', 0)})
        except Exception:
            pass
        # 솔저: 자폭드론
        if globals().get('suicide_drone_active', False):
            _sd_rect = globals().get('suicide_drone_rect')
            if _sd_rect:
                _fx.append({'t': 'drone', 'x': _sd_rect.centerx, 'y': _sd_rect.centery})

        # 발토르: 터렛 투사체
        _tp = globals().get('blacksmith_turret_projectiles', [])
        for _proj in _tp[:8]:
            _fx.append({
                't': 'turret',
                'x': _proj.get('x', 0),
                'y': _proj.get('y', 0),
            })
        # 발토르: 해머 쇼크 투사체
        _hsp = globals().get('blacksmith_hammer_shock_projectiles', [])
        for _hp in _hsp[:4]:
            _fx.append({
                't': 'hshock',
                'x': _hp.get('x', 0),
                'y': _hp.get('y', 0),
                's': _hp.get('stage', 0),
            })
        # 발토르: 디바인 스톤
        _ds = globals().get('blacksmith_divine_stone_state')
        if _ds and isinstance(_ds, dict):
            _ds_rect = _ds.get('rect')
            if _ds_rect:
                _fx.append({
                    't': 'divine',
                    'x': _ds_rect.centerx,
                    'y': _ds_rect.centery,
                    'hp': _ds.get('hp', 0),
                    'mhp': _ds.get('max_hp', 1),
                    'sh': 1 if _ds.get('shield_ready') else 0,
                })

        if _fx:
            anim['fx'] = _fx

    except Exception:
        pass
    return anim


# ── [pingfighter.py:171080~171146] 호스트: 게임 상태 전송 ──
def _online_send_game_state():
    """호스트: 매 프레임 게임 상태를 클라이언트에 전송.
    공 위치/속도, 양쪽 패들 위치, 아이템, 서브 상태, 점수 등.
    """
    if not online_multiplayer_enabled or not online_is_host:
        return
    if _online_net_manager is None or not _online_net_manager.connections:
        return

    global _online_sound_queue

    # 아이템 목록 직렬화
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

    serialized = serialize_game_frame(frame_data)
    _online_net_manager.send_online_packet(OnlinePacketType.GAME_FRAME, serialized)
    _online_sound_queue.clear()


# ── [pingfighter.py:171149~171166] 클라이언트: 위치 전송 ──
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


# ── [pingfighter.py:171169~171274] 클라이언트: 상태 적용 ──
def _online_client_apply_state():
    """클라이언트: 호스트에서 수신한 게임 상태를 적용.
    - 공 위치/속도 → Y축 반전하여 적용 (호스트 권위)
    - 점수 → 시점 반전 (호스트 round_wins = 내 round_losses)
    - 서브 상태 → 시점 반전
    - 아이템 → Y축 반전하여 표시
    """
    global round_wins, round_losses, _online_opponent_anim
    global is_waiting_for_serve, is_player_serve

    if not online_multiplayer_enabled or online_is_host:
        return
    if _online_net_manager is None:
        return

    frame = _online_net_manager.online_game_frame
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
    if host_waiting:
        is_waiting_for_serve = True
        is_player_serve = not host_player_serve  # 시점 반전!
    elif is_waiting_for_serve and not host_waiting:
        is_waiting_for_serve = False

    # 클라이언트 아이템 획득 처리 (호스트가 감지한 BOSS 충돌)
    client_pickups = frame.get('client_pickups', [])
    for _cp in client_pickups:
        _cp_name = _cp.get('name', '')
        _cp_color = tuple(_cp.get('color', [200, 200, 200]))
        _cp_x = _cp.get('x', 0)
        _cp_y = HEIGHT - _cp.get('y', 0)  # Y반전
        if _cp_name:
            _cp_data = {
                "name": _cp_name,
                "color": _cp_color,
                "effect": _cp_name,
                "icon": None,
                "x": _cp_x,
                "y": _cp_y,
            }
            # 패시브/액티브 구분하여 저장
            _passive_names = {"speedboots", "speedgear", "battery", "slot_add", "revival",
                             "master", "cooltime", "chargebag", "spikeboots", "dashgear",
                             "sensor", "bulkup", "dashholder", "gravitybelt",
                             "dowsing_pendulum", "commando_arm", "technical_vest",
                             "fuel_pouch", "bluetooth_ring", "star_detector",
                             "foul_whistle", "smartphone", "knee_pads",
                             "ragnarok_hammer", "hermes_shoes", "poseidon_trident",
                             "angel_blessing", "sacred_laurel", "transcendent_crown",
                             "odins_eye", "pandora_legacy", "bulletproof_hat",
                             "spiked_helmet", "gold_bar", "gold_digger", "hero_seal",
                             "lucky_coin", "adversity_armor", "shrapnel_armor",
                             "soul_burst", "sage_ring", "venom_mist_gauntlet"}
            if _cp_name in _passive_names:
                store_passive_item(_cp_data)
            else:
                store_active_item(_cp_data)

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


# ── [pingfighter.py:152198~152333] 보스 온라인 동기화 ──
def _handle_boss_online_sync():
    """온라인 멀티플레이: 상대방의 PLAYER 위치를 BOSS에 적용 + 서브 처리.
    호스트: P2(클라이언트)의 PLAYER.x → BOSS.x
    클라이언트: P1(호스트)의 PLAYER.x → BOSS.x
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
        remote = _online_net_manager.online_remote_input
        if remote is not None and 'x' in remote:
            BOSS.x = int(remote['x'])
            if 'anim' in remote:
                _online_opponent_anim = remote['anim']
    else:
        # 클라이언트: 호스트가 보낸 P1 위치를 BOSS에 적용
        frame = _online_net_manager.online_game_frame
        if frame is not None:
            p1 = frame.get('p1', None)
            if p1:
                BOSS.x = int(p1[0])

    # 경계 클램핑
    if BOSS.x < 0:
        BOSS.x = 0
    elif BOSS.x > WIDTH - BOSS.width:
        BOSS.x = WIDTH - BOSS.width

    # ── 바이퍼 제트팩 오프셋 적용 ──
    if _online_opponent_anim and _online_opponent_anim.get('state') == 'flying':
        _opp_jp_offset = _online_opponent_anim.get('jetpack_offset', 0)
        BOSS.y = BOSS_Y - int(_opp_jp_offset)  # 부호 반전
    else:
        BOSS.y = BOSS_Y  # 기본 위치

    # ── 온라인 서브 처리 ──
    if is_waiting_for_serve and not ball_spawn_animation_active:
        if is_player_serve and online_is_host:
            # 호스트 본인 서브
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
                except Exception as e:
                    print(f"[Online Serve] 플레이어 서브 에러: {e}")
            else:
                boss_fake_during_player_serve = True
        elif is_player_serve and not online_is_host:
            # 클라이언트 본인 서브
            boss_fake_during_player_serve = True
        elif online_is_host:
            # 상대(클라이언트/AI) 서브
            _client_serve = False
            if _online_ai_boss_enabled:
                pass  # AI는 타이머로 자동 서브
            elif _online_net_manager is not None:
                remote = _online_net_manager.online_remote_input
                if remote is not None and remote.get('serve', False):
                    _client_serve = True
            # 자동 서브 (AI: 1.5초, 온라인: 3초)
            time_now = pygame.time.get_ticks()
            _elapsed = time_now - waiting_start_time
            _serve_timeout = 1500 if _online_ai_boss_enabled else 3000
            if _client_serve or (_elapsed >= _serve_timeout):
                try:
                    serve_result = physics_manager.serve_ball(False, current_stage, ai_mode)
                    apply_serve_result(serve_result)
                    is_waiting_for_serve = serve_result.get('is_waiting_for_serve', False)
                    serve_completed_timer = 180
                    play_serve_sound()
                    create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=False)
                except Exception as e:
                    print(f"[Online Serve] 보스 서브 에러: {e}")
        else:
            # 클라이언트: 상대방(호스트) 서브 대기
            pass


# ── [pingfighter.py:163764~163770] 게임 루프 통합 지점 ──
# 메인 게임 루프 내에서 호출되는 부분:
#
# if online_multiplayer_enabled:
#     if online_is_host:
#         _online_send_game_state()       # 호스트: 매 프레임 상태 전송
#     else:
#         _online_send_player_position()  # 클라이언트: 매 프레임 위치 전송
#         _online_client_apply_state()    # 클라이언트: 호스트 상태 적용
#
# ── [pingfighter.py:152348~152350] 보스 처리 분기 ──
# if online_multiplayer_enabled:
#     _handle_boss_online_sync()  # 온라인: 상대방 위치 동기화 (AI 대전 포함)
# else:
#     handle_boss()               # 일반: AI 보스 처리
