# Report interaction with the portrait only. No desktop-wide gaze target is recorded.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
$skin = Split-Path -Parent $PSScriptRoot
$engine = Join-Path (Split-Path -Parent (Split-Path -Parent $skin)) 'Rainmeter.exe'
$windowName = Join-Path $skin 'Loopy.ini'
$owner = Get-Process -Name Rainmeter -ErrorAction SilentlyContinue | Where-Object Path -eq $engine | Select-Object -First 1
if (!$owner) { return }
$mutex = [Threading.Mutex]::new($false, ('Local\LoopyPointer-' + $owner.Id))
if (!$mutex.WaitOne(0)) { $mutex.Dispose(); return }
$stream = $null
try {
    $condition = [Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::ProcessIdProperty, [int]$owner.Id)
    $window = $null
    for ($attempt = 0; !$window -and $attempt -lt 35 -and !$owner.HasExited; $attempt++) {
        $windows = [Windows.Automation.AutomationElement]::RootElement.FindAll([Windows.Automation.TreeScope]::Children, $condition)
        $window = $windows | Where-Object { $_.Current.Name -eq $windowName -and $_.Current.ClassName -eq 'RainmeterMeterWindow' } | Select-Object -First 1
        if (!$window) { Start-Sleep -Milliseconds 100 }
    }
    if (!$window) { return }
    $packet = Join-Path $PSScriptRoot 'Pointer.state'
    $share = [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete
    $stream = [IO.File]::Open($packet, [IO.FileMode]::Create, [IO.FileAccess]::Write, $share)
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $previous = [Windows.Forms.Cursor]::Position
    $pressed = $false
    $grabbed = $false
    $running = $false
    $facing = 1
    $zone = 0
    $nextHit = 0
    $lastLine = ''
    $nextBounds = 0
    while (!$owner.HasExited) {
        $point = [Windows.Forms.Cursor]::Position
        $left = ([Windows.Forms.Control]::MouseButtons -band [Windows.Forms.MouseButtons]::Left) -ne 0
        $ms = $watch.ElapsedMilliseconds
        if ($ms -ge $nextBounds -or $left -ne $pressed -or $point -ne $previous) {
            $bounds = $window.Current.BoundingRectangle
            if ($bounds.IsEmpty) { break }
            $nextBounds = $ms + 1000
        }
        $x = $point.X - $bounds.X
        $y = $point.Y - $bounds.Y
        $inside = $x -ge 21 -and $x -lt 133 -and $y -ge 0 -and $y -lt 116
        if (!$inside) {
            $zone = 0
        } elseif (!$zone -or $ms -ge $nextHit -or $left -ne $pressed) {
            # A floating window can cover the rectangle. Confirm the pet owns the hit.
            $zone = 2
            try {
                $hit = [Windows.Automation.AutomationElement]::FromPoint([Windows.Point]::new($point.X,$point.Y))
                if ($hit.Current.NativeWindowHandle -eq $window.Current.NativeWindowHandle) { $zone = 1 }
            } catch [Windows.Automation.ElementNotAvailableException] {}
            $nextHit = $ms + 120
        }
        if ($left -and !$pressed) {
            $grabbed = $inside
            $start = $point
            $pivot = $point.X
        }
        if ($left -and $grabbed) {
            $dx = $point.X - $start.X
            $dy = $point.Y - $start.Y
            if ($dx*$dx + $dy*$dy -ge 16) { $running = $true }
            if ([Math]::Abs($point.X - $pivot) -ge 4) {
                $facing = if ($point.X -gt $pivot) { 1 } else { 2 }
                $pivot = $point.X
            }
        } else { $grabbed = $false; $running = $false }
        $run = if ($running) { $facing } else { 0 }
        $line = '{0} {1} {2} {3} H' -f [DateTimeOffset]::UtcNow.ToUnixTimeSeconds(), [int]$left, $run, $zone
        if ($line -ne $lastLine) {
            $bytes = [Text.Encoding]::ASCII.GetBytes($line.PadRight(40) + [char]10)
            $stream.Position = 0
            $stream.Write($bytes, 0, $bytes.Length)
            $stream.Flush()
            $lastLine = $line
        }
        $previous = $point
        $pressed = $left
        Start-Sleep -Milliseconds 32
    }
} finally {
    if ($stream) { $stream.Dispose() }
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
