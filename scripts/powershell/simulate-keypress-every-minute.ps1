# Simulates a harmless keypress on a fixed interval (default: every 60 seconds).
# Useful to keep a session active or nudge apps that watch for input.
# Press Ctrl+C to stop.

param(
    [int]$IntervalSeconds = 60,
    [ValidateSet('F15', 'Shift', 'ScrollLock')]
    [string]$Key = 'F15'
)

Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class NativeKeyboard
{
    private const uint KEYEVENTF_KEYUP = 0x0002;

    [DllImport("user32.dll")]
    private static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    public static void Tap(byte virtualKey)
    {
        keybd_event(virtualKey, 0, 0, UIntPtr.Zero);
        keybd_event(virtualKey, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
    }
}
'@

$virtualKeys = @{
    F15         = 0x7E
    Shift       = 0x10
    ScrollLock  = 0x91
}

$vk = $virtualKeys[$Key]
$interval = [TimeSpan]::FromSeconds($IntervalSeconds)

Write-Host "Simulating '$Key' every $IntervalSeconds second(s). Press Ctrl+C to stop."
Write-Host "Started at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

try {
    while ($true) {
        [NativeKeyboard]::Tap($vk)
        Write-Host "$(Get-Date -Format 'HH:mm:ss') - sent $Key"
        Start-Sleep -Seconds $IntervalSeconds
    }
}
finally {
    Write-Host "Stopped at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
}
