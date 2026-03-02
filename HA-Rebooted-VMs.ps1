$yesterdayDate = (Get-Date).Date.AddDays(-1)               # ayer (domingo si hoy es lunes)
$finish = $yesterdayDate.AddDays(1).AddSeconds(-1)         # ayer 23:59:59

$daysSinceFriday = ([int]$yesterdayDate.DayOfWeek - [int][System.DayOfWeek]::Friday)
if ($daysSinceFriday -lt 0) { $daysSinceFriday += 7 }
$start = $yesterdayDate.AddDays(-$daysSinceFriday)         # viernes 00:00:00

Write-Host "Rango de búsqueda: $start  ->  $finish" -ForegroundColor Cyan

# ---- PATRONES / TIPOS de HA ----
$haRegex = "vSphere HA|restarted by vSphere HA|HA restarted|Failover|failover|restart.*HA"

$rows = New-Object System.Collections.Generic.List[object]

foreach ($cluster in (Get-Cluster | Sort-Object Name)) {

    Write-Host "Cluster: $($cluster.Name) - obteniendo VMs..." -ForegroundColor Yellow
    $vms = Get-Cluster $cluster | Get-VM -ErrorAction SilentlyContinue
    if (-not $vms) { continue }

    # Eventos por VM (esto suele traer el nombre bien)
    Write-Host "Cluster: $($cluster.Name) - buscando eventos..." -ForegroundColor Yellow
    $events = Get-VIEvent -Entity $vms -Start $start -Finish $finish -MaxSamples 200000 -ErrorAction SilentlyContinue

    if (-not $events) { continue }

    $haEvents = $events | Where-Object {
        $_ -is [VMware.Vim.VmRestartedOnAlternateHostEvent] -or
        $_.FullFormattedMessage -match $haRegex
    }

    foreach ($e in $haEvents) {
        if ($e.Vm -and $e.Vm.Name) {
            $rows.Add([pscustomobject]@{
                Time = $e.CreatedTime
                VM   = $e.Vm.Name
            })
        }
    }
}

# ---- DEDUP: misma VM en el mismo minuto (evita spam de múltiples eventos) ----
# Puedes quitar el ToString("yyyy-MM-dd HH:mm") si quieres al segundo.
$result = $rows |
    Select-Object @{N="Time";E={$_.Time}}, @{N="VM";E={$_.VM}}, @{N="MinuteKey";E={$_.Time.ToString("yyyy-MM-dd HH:mm")}} |
    Sort-Object Time, VM |
    Group-Object VM, MinuteKey |
    ForEach-Object {
        $_.Group | Select-Object -First 1 | Select-Object Time, VM
    }

# Salida en consola
$result | Format-Table -AutoSize

# Export opcional
$result | Export-Csv ".\HA_VMs_Fri_to_Sun_VM_and_Time.csv" -NoTypeInformation -Encoding UTF8
