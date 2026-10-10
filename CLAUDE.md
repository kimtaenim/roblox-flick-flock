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
- `sh tests/simulate.sh` : 진짜 Config 숫자로 NPC 대전 (튕기기만, 능력 제외). 2팀 추천 팀 조합 160판 + 3팀·4팀 각 100판. 시작 배치 겹침, 승패가 나는지, 팀·자리별 승리 수 출력.
- 타입 검사: `rojo sourcemap -o sourcemap.json` 후 `luau-lsp analyze --definitions=@roblox=globalTypes.d.luau --sourcemap=sourcemap.json src`

## 코드 위치
| 파일 | 역할 |
| --- | --- |
| `src/server/GameManager.server.lua` | 팀 고르기·턴 진행, 요청 검증, 능력 효과 턴 관리, 승패 |
| `src/server/Board.lua` | 판 생성 |
| `src/server/PieceFactory.lua` | 알 생성 (Config.Pieces 다섯 값), 눈·왕관, HP 막대, 거대화 |
| `src/server/Placement.lua` | 팀 배치, 빈 자리 찾기 |
| `src/server/Damage.lua` | 왕알 HP (충돌 데미지) |
| `src/server/Elimination.lua` | 판 밖 탈락 |
| `src/server/Effects.lua` | 소리, 반짝이, 폭발, 발자국, 배너 |
| `src/server/Speech.lua` | 알 대사 말풍선·목소리 (대사는 `Config.Lines`) |
| `src/server/Npc.lua` | NPC 조준 계산 (숫자만 써서 Studio 없이 테스트 가능) |
| `src/server/Abilities/*.lua` | 능력 8개 (`Execute(piece, context)` + `OnTurnEnd(piece)`) |
| `src/client/FlickInput.client.lua` | 자유 카메라(Studio 식)·흔들림, 드래그 조준, 발사 요청 |
| `src/client/AbilityUI.client.lua` | 능력 버튼 |
| `src/client/TeamSelectUI.client.lua` | 모드(2·3·4팀) 고르기, 추천 팀 / 고급 예산 조합 |
| `src/client/TurnUI.client.lua` | 차례·알 개수·왕알 HP, 배너 |
| `src/client/TutorialUI.client.lua` | 튜토리얼 (? 버튼) |
| `src/shared/Config.lua` | 모든 숫자 |
| `src/shared/AbilityList.lua` | 능력 이름·아이콘 (이름은 아들과 결정) |
| `src/shared/Remotes.lua` | RemoteEvent + GameState(Attribute) |
| `src/shared/TeamLayout.lua` | 2~4팀 자리·방향·다음 차례 계산 (숫자만, 테스트 가능) |

## 진행 상황
- [x] 1단계: 판 + 납작 알 + 드래그 튕기기 + 턴 교대 + 판 밖 탈락
- [x] 플레이어 대 NPC (혼자 접속하면 파랑 = NPC, 능력도 씀)
- [x] 2단계: 왕알 HP + 데미지 + 승리 판정
- [x] 3단계: 둥근 알, 0.5 알, 폭발·거대화·텔레포트
- [x] 4단계: 소환·분신·자석·똥알·유령 + 연출
- [x] 5단계: 팀 선택 UI (추천 팀 4개 + 고급)
- [x] 6단계: 알 디자인(눈·왕관, 임시), 소리, 튜토리얼
- [x] 3·4팀 대결 (방장이 모드 선택, 모자란 자리는 NPC, 탈락제)
- [ ] Studio 실제 플레이 테스트 후 고칠 것 정리 (물리 느낌, 소리 파일 존재 여부, UI 크기)

## 설계서에서 정한 해석
- 왕알도 튕길 수 있음. 무거워서 조금만 감 (`Config.CanFlickKing`).
- 똥알·유령은 반복 사용 가능 (`Config.ReusableAbilities`), 나머지 능력은 1회.
- 유령·똥알은 상대 턴 한 번 동안 (똥알은 그동안 똥 모양), 자석은 상대 턴 + 내 다음 턴 동안 유지 (`Config.EffectTurns`). 자석 알은 그동안 나도 상대도 못 움직임.
- 소리는 로블록스 기본 내장 소리 8개를 음 높이만 바꿔 씀 (`Config.Sounds`, `Config.Melodies`).
- 둥근 알은 구슬이 아니라 바둑알처럼 볼록한 타원체. 물리 몸통은 원기둥이고 겉모양만 볼록 (`Config.RoundHeight`). 납작 알보다 미끄러워서 멀리 가고(friction), 세게 튄다(bounce).
- 능력 대상은 능력 알 자기 자신 (분신은 그 알 옆, 텔레포트는 그 알을 가운데로).
- 폭발 턴에는 왕알 HP 가 1 아래로 안 내려감 (충돌 데미지 포함).
