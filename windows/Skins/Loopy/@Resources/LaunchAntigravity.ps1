$ErrorActionPreference = 'Stop'

function Resolve-AntigravityLaunchTarget {
    $shortcutFolders = @(
        [Environment]::GetFolderPath('DesktopDirectory'),
        [Environment]::GetFolderPath('CommonDesktopDirectory'),
        [Environment]::GetFolderPath('Programs'),
        [Environment]::GetFolderPath('CommonPrograms')
    )
    $shell = $null
    try {
        $shell = New-Object -ComObject WScript.Shell
        foreach ($folder in $shortcutFolders) {
            if (!$folder) { continue }
            $lnk = Join-Path $folder 'Antigravity.lnk'
            if (!(Test-Path -LiteralPath $lnk -PathType Leaf)) { continue }
            try {
                $sc = $shell.CreateShortcut($lnk)
                $targetPath = $sc.TargetPath
                $argsText = [string]$sc.Arguments
                if ($targetPath -and (Test-Path -LiteralPath $targetPath -PathType Leaf) -and $argsText -notmatch 'antigravity://') {
                    return @{ Kind = 'Shortcut'; Path = $lnk }
                }
            } catch {}
        }
    } catch {} finally {
        if ($shell) {
            try { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell) } catch {}
        }
    }

    $regPaths = @(
        'HKCU:\Software\Classes\antigravity\shell\open\command',
        'HKLM:\Software\Classes\antigravity\shell\open\command',
        'Registry::HKEY_CLASSES_ROOT\antigravity\shell\open\command'
    )
    foreach ($regPath in $regPaths) {
        if (Test-Path -LiteralPath $regPath) {
            try {
                $cmd = (Get-ItemProperty -LiteralPath $regPath -ErrorAction Stop).'(default)'
                if ($cmd -match '^\s*"([^"]+\.exe)"' -or $cmd -match '^\s*(\S+\.exe)') {
                    $candidate = $Matches[1]
                    if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                        return @{ Kind = 'Executable'; Path = $candidate }
                    }
                }
            } catch {}
        }
    }

    $fallbacks = @()
    if ($env:LOCALAPPDATA) {
        $fallbacks += (Join-Path $env:LOCALAPPDATA 'Programs\antigravity\Antigravity.exe')
    }
    if ($env:ProgramFiles) {
        $fallbacks += (Join-Path $env:ProgramFiles 'Antigravity\Antigravity.exe')
    }
    if (${env:ProgramFiles(x86)}) {
        $fallbacks += (Join-Path ${env:ProgramFiles(x86)} 'Antigravity\Antigravity.exe')
    }
    foreach ($candidate in $fallbacks) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return @{ Kind = 'Executable'; Path = $candidate }
        }
    }

    return @{ Kind = 'Protocol'; Path = 'antigravity://' }
}

$target = Resolve-AntigravityLaunchTarget
switch ($target.Kind) {
    'Shortcut' {
        Start-Process -FilePath $target.Path
    }
    'Executable' {
        Start-Process -FilePath $target.Path
    }
    default {
        Start-Process 'antigravity://'
    }
}
