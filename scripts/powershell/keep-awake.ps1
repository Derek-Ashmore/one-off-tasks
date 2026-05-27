# Prevents the system (and optionally the display) from sleeping while this script runs.
# Uses SetThreadExecutionState; no simulated keypresses.
# Press Ctrl+C to stop; sleep settings are restored automatically.

param(
    [switch]$AllowDisplayOff
)

Add-Type @'
using System;
using System.Runtime.InteropServices;

[Flags]
public enum ExecutionState : uint
{
    SystemRequired = 0x00000001,
    DisplayRequired = 0x00000002,
    Continuous = 0x80000000
}

public static class KeepAwake
{
    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern ExecutionState SetThreadExecutionState(ExecutionState esFlags);

    public static void PreventSleep(bool keepDisplayOn)
    {
        var flags = ExecutionState.Continuous | ExecutionState.SystemRequired;
        if (keepDisplayOn)
        {
            flags |= ExecutionState.DisplayRequired;
        }

        var result = SetThreadExecutionState(flags);
        if (result == 0)
        {
            throw new InvalidOperationException(
                "SetThreadExecutionState failed. Error: " + Marshal.GetLastWin32Error());
        }
    }

    public static void AllowSleep()
    {
        SetThreadExecutionState(ExecutionState.Continuous);
    }
}
'@

$keepDisplayOn = -not $AllowDisplayOff

if ($keepDisplayOn) {
    Write-Host 'Keeping system and display awake. Press Ctrl+C to stop.'
}
else {
    Write-Host 'Keeping system awake (display may turn off). Press Ctrl+C to stop.'
}

Write-Host "Started at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

try {
    [KeepAwake]::PreventSleep($keepDisplayOn)

    while ($true) {
        Start-Sleep -Seconds 60
    }
}
finally {
    [KeepAwake]::AllowSleep()
    Write-Host "Stopped at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - normal sleep behavior restored."
}
