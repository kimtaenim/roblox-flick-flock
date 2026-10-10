# CLAUDE.md

이 레포의 기준 문서는 `FLICK_FLOCK_DESIGN.md` 다. 작업 전에 반드시 읽는다.

## 핵심 규칙 (설계서 10장 요약)
- 서버 권위: 물리·판정·HP는 서버. 클라이언트는 입력과 UI만.
- 밸런스 숫자는 전부 `src/shared/Config.lua` 한 곳에. 하드코딩 금지.
- 변수명은 쉬운 영어, 주석은 한국어 (아들이 읽을 수 있게).
- 능력은 `src/server/Abilities/` 에 파일 하나씩, `Ability.Execute(piece, context)` + `Ability.OnTurnEnd(piece)`.
- 새 능력 추가 시 설계서 5장 표에 먼저 한 줄 추가.
- 단계(설계서 9장)마다, 그리고 작은 기능마다 커밋·푸시.

## 실행
- Windows: `open-studio.bat` 더블클릭 (바탕화면에 복사해 써도 됨). git pull → Rojo 다운로드 → 플레이스 빌드 → Studio 열기 → `rojo serve` (포트 34872).
- Studio: 플러그인 탭 → Rojo → Connect (localhost:34872).
- 2인 테스트: Test → Clients and Servers → 2 Players. 혼자 Play 하면 파랑은 NPC (`Config.SoloMode`).

## 테스트 (Studio 없이)
- `luau tests/simulate.luau` : 단순화한 물리로 NPC 대 NPC 150판을 돌려 승패가 나는지, NPC 명중률을 출력.
- 타입 검사: `rojo sourcemap -o sourcemap.json` 후 `luau-lsp analyze --definitions=@roblox=globalTypes.d.luau --sourcemap=sourcemap.json src`

## 코드 위치
| 파일 | 역할 |
| --- | --- |
| `src/server/GameManager.server.lua` | 라운드·턴 진행, 튕기기 요청 검증 |
| `src/server/Board.lua` | 판 생성 |
| `src/server/PieceFactory.lua` | 알 생성 (Config.Pieces 다섯 값) |
| `src/server/Elimination.lua` | 판 밖 탈락 |
| `src/server/Npc.lua` | NPC 조준 계산 (숫자만 써서 Studio 없이 테스트 가능) |
| `src/client/FlickInput.client.lua` | 카메라, 드래그 조준, 발사 요청 |
| `src/client/TurnUI.client.lua` | 차례·알 개수 표시 |
| `src/shared/Config.lua` | 모든 숫자 |
| `src/shared/Remotes.lua` | RemoteEvent + GameState(Attribute) |

## 진행 상황
- [x] 1단계: 판 + 납작 알 + 드래그 튕기기 + 턴 교대 + 판 밖 탈락 (왕알이 없으므로 승리 = 상대 알 전멸)
- [x] 플레이어 대 NPC (혼자 접속하면 파랑 = NPC, 난이도는 `Config.NpcAimErrorDegrees`)
- [ ] 2단계: 왕알 HP + 데미지 + 승리 판정
