# roblox-flick-flock
아들과 만드는 로블록스 게임

## 로컬에서 Studio로 실행하기 (Windows)

1. [Git](https://git-scm.com/download/win)과 [Roblox Studio](https://create.roblox.com/)를 설치합니다.
2. `start_studio.bat`을 아무 곳에 내려받아 더블클릭합니다.
   - 처음엔 `%USERPROFILE%\roblox-flick-flock`에 레포를 clone하고, 이후엔 실행할 때마다 `git pull` 합니다.
   - Rojo를 `tools\`에 받아 Studio 플러그인을 설치하고, `FlickFlock.rbxlx`를 만들어 Studio로 엽니다.
3. Studio에서 **플러그인 탭 → Rojo → Connect** (주소 `localhost`, 포트 **34872**).
4. 배치파일 창은 작업하는 동안 열어 둡니다. 코드는 `src/` 안에서 고치면 Studio에 바로 반영됩니다.

## 폴더 구조

| 폴더 | Studio 위치 |
| --- | --- |
| `src/server` | ServerScriptService.Server |
| `src/client` | StarterPlayer.StarterPlayerScripts.Client |
| `src/shared` | ReplicatedStorage.Shared |
