# open-studio.bat 이 -EncodedCommand 로 실행하는 스크립트 원본 (바꾸면 배치파일의 인코딩 문자열도 다시 만들어야 함)
# FF_REPO 환경 변수 = 레포 폴더
$ErrorActionPreference = 'Stop'
try {
    $desktop = [Environment]::GetFolderPath('Desktop')
    $name = -join [char[]](0xC54C, 0xAE4C, 0xAE30)
    $path = Join-Path $desktop ($name + '.lnk')
    $target = Join-Path $env:FF_REPO 'open-studio.bat'
    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut($path)
    $link.TargetPath = $target
    $link.WorkingDirectory = $env:FF_REPO
    $link.Description = 'Flick Flock'
    $studio = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Roblox\Versions') -Recurse -Filter RobloxStudioBeta.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($studio) { $link.IconLocation = $studio.FullName + ',0' }
    $link.Save()
    foreach ($old in @(($name + '.bat'), 'Flick Flock.lnk')) {
        $oldPath = Join-Path $desktop $old
        if (Test-Path $oldPath) { Remove-Item $oldPath -ErrorAction SilentlyContinue }
    }
    if (Test-Path $path) {
        Write-Host ('[OK] Desktop shortcut: ' + $path + '  ->  ' + $target)
    } else {
        Write-Host ('[FAIL] Shortcut was not created at ' + $path)
        exit 1
    }
} catch {
    Write-Host ('[FAIL] ' + $_.Exception.Message)
    exit 1
}
