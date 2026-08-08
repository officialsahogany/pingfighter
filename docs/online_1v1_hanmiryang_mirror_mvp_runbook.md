# 온라인 1v1 한미량 미러전 MVP 실행서

정본 스펙은 `online_1v1_hanmiryang_mirror_mvp_codex_handoff.md`다. 현재 구현은
2026-08-08 2차 재리뷰 필수 수정과 로컬 재검증을 마쳤으며, LAN 및 원거리
Tailscale 실기 검증은 남아 있다. 로컬 자동 검증 결과는 최신 재리뷰
해결 문서의 실행 증거를 기준으로 판정한다.

## UI 실행

1. 두 PC에서 같은 빌드/리비전을 실행한다.
2. 메인 메뉴의 `온라인 1대1`을 누른다.
3. 한쪽은 포트를 확인하고 `방 만들기`, 다른 쪽은 호스트 주소와 같은 포트를
   입력한 뒤 `IP로 참가`를 누른다.
4. 양쪽이 준비되면 3초 카운트다운 후 서브권을 가진 쪽이 마우스 왼쪽 버튼 또는
   Enter로 수동 서브한다.

조작은 좌우 이동, 아래 방향키 대시, 마우스 왼쪽 버튼/Enter 서브, ESC 나가기다.
1차 범위에서 스킬·아이템·수호령·퍽은 동작하지 않는다.

## CLI 실행

`godot/`을 프로젝트 경로로 지정하고 생산 전투 씬을 실행한다. Godot 실행 파일은
각 PC의 설치 경로로 바꾼다.

```powershell
# 호스트
Godot_v4.6.2-stable_win64.exe --path D:\main\bosspong\godot `
  res://scenes/main.tscn -- --online-host --online-port=24777

# 참가자: localhost는 127.0.0.1, LAN은 호스트 사설 IP, 원격은 Tailscale IP
Godot_v4.6.2-stable_win64.exe --path D:\main\bosspong\godot `
  res://scenes/main.tscn -- --online-join=127.0.0.1 --online-port=24777
```

스냅샷 전송률은 필요할 때 `--online-snapshot-hz=30`으로 독립 조절한다. 시뮬레이션
틱은 온라인전 동안 항상 60Hz다.

## 실기 검증 체크리스트

- 동일 LAN: 서로 다른 PC, 호스트 사설 IP, UDP 24777 방화벽 허용 여부 기록.
- 원거리: 서로 다른 회선의 두 PC, Tailscale IP 사용, 세션의 direct/DERP 연결
  유형과 측정 RTT 기록. LAN 성공으로 이 항목을 대체하지 않는다.
- 20/50/100ms 각각에서 무손실과 손실·지터 조건을 측정한다. 입력 응답, 자기 패들
  보정, 공/상대 패들 보간, 서브·득점·듀스 일치를 기록한다.
- 양쪽 그래픽 모드를 SMOOTH/BALANCED/STABLE_MONITOR로 바꿔도 온라인 시뮬레이션
  60Hz가 유지되는지 확인한다.
- 종료 후 싱글플레이에 들어가 기존 그래픽 설정 기반 물리 틱과 일반 기능이
  복원되는지 확인한다.

실패 시 양쪽 리비전, 역할, 주소/포트, 연결 유형, RTT, 패킷 손실·지터 조건,
득점/서브 상태와 재현 순서를 함께 남긴다.
