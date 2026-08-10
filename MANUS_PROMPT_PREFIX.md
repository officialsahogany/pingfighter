# Manus Prompt Prefix

마누스(Manus)에게 **환격전** Godot 작업을 지시할 때, 프롬프트 맨 앞에
아래 텍스트를 복사해서 붙여넣어 주세요. 영문 제품명은 아직 정하지 않았습니다.

```text
[필독 지시사항]
1. 작업을 시작하기 전에 반드시 `docs/godot_port_checklist.md`와 `AGENTS.md`를 읽으세요.
2. 현재 제품명은 환격전이며 영문명은 미정입니다. pingfighter, DiskHearts, Ringpia/Lingpia, package ID, save key, res:// 경로는 호환 식별자이므로 임의로 바꾸지 마세요.
3. 외부 모듈(registry.get_module 등)의 메서드를 호출할 때는, 추측하지 말고 반드시 해당 파일에서 메서드명과 시그니처(인자 개수/타입)를 확인한 후 작성하세요.
4. 시네마틱이나 모달 상태가 필요한 경우, 단순히 상태 변수만 바꾸지 말고 modal_gate, overlay_frame_controller, input_controller에 모두 연결(Wiring)하세요.
5. 스모크 테스트는 단순 Stub 생성이 아니라, 실제 통합 경로(registry 연동 등)를 검증하도록 작성하세요.
```
