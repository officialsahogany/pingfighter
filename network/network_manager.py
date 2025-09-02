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
        except Exception as e:
            print(f"패킷 전송 실패: {e}")
            self.connected = False
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
            
            # 오래된 시퀀스 제거
            if len(self.received_sequences) > 1000:
                min_seq = min(self.received_sequences)
                self.received_sequences = {s for s in self.received_sequences if s > min_seq - 100}
                
            return packet
            
        except socket.timeout:
            return None
        except Exception as e:
            print(f"패킷 수신 실패: {e}")
            self.connected = False
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
        
        # 설정 핸들러
        self.setup_handlers()
        
    def setup_handlers(self):
        """패킷 핸들러 설정"""
        self.packet_handlers[PacketType.HANDSHAKE] = self.handle_handshake
        self.packet_handlers[PacketType.GAME_STATE] = self.handle_game_state
        self.packet_handlers[PacketType.INPUT] = self.handle_input
        self.packet_handlers[PacketType.SYNC] = self.handle_sync
        self.packet_handlers[PacketType.PING] = self.handle_ping
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
                        continue
                        
                    # 패킷 수신
                    packet = connection.receive_packet()
                    if packet:
                        self.process_packet(packet, connection)
                        
                    # 핑 체크
                    if time.time() - connection.last_ping > 1.0:
                        self.send_ping(connection)
                        
                # 게임 상태 동기화 (호스트만)
                if self.mode == NetworkMode.HOST:
                    self.sync_game_state()
                    
                time.sleep(0.001)  # 1ms 대기
                
            except Exception as e:
                print(f"네트워크 루프 에러: {e}")
                
    def process_packet(self, packet: NetworkPacket, connection: NetworkConnection):
        """패킷 처리
        
        Args:
            packet: 수신된 패킷
            connection: 연결
        """
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
        """핑 전송"""
        data = {'timestamp': time.time()}
        self.send_packet(PacketType.PING, data, connection)
        connection.last_ping = time.time()
        
    def handle_ping(self, packet: NetworkPacket, connection: NetworkConnection):
        """핑 처리"""
        # 레이턴시 계산
        latency = time.time() - packet.data['timestamp']
        connection.latency = latency * 1000  # ms로 변환
        
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