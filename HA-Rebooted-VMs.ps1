# Connect-VIServer -Server 

$csvOut = ".\VC_AllClusters_HA_Events_Fri_to_Sun.csv"

# ---------- CALCULAR RANGO: Viernes 00:00 -> Domingo 23:59:59 (fin de "ayer" si hoy es lunes) ----------
$yesterdayDate = (Get-Date).Date.AddDays(-1)
$finish = $yesterdayDate.AddDays(1).AddSeconds(-1)
$daysSinceFriday = ([int]$yesterdayDate.DayOfWeek - [int][System.DayOfWeek]::Friday)
if ($daysSinceFriday -lt 0) { $daysSinceFriday += 7 }
$start = $yesterdayDate.AddDays(-$daysSinceFriday) 

Write-Host "Rango de búsqueda: $start  ->  $finish" -ForegroundColor Cyan

$allClusters = Get-Cluster | Sort-Object Name
$results = New-Object System.Collections.Generic.List[object]

foreach ($cluster in $allClusters) {

    Write-Host "Procesando cluster: $($cluster.Name)" -ForegroundColor Yellow
    $events = Get-VIEvent -Entity $cluster -Start $start -Finish $finish -MaxSamples 200000 -ErrorAction SilentlyContinue

    if (-not $events) { continue }

    $haTyped = $events | Where-Object {
        $_ -is [VMware.Vim.VmRestartedOnAlternateHostEvent]
    }

    $haText = $events | Where-Object {
        $_.FullFormattedMessage -match "vSphere HA|restarted by vSphere HA|HA restarted|HA initiated|Failover|failover"
    }

    # Unir y deduplicar por (CreatedTime + EventType + VM + Message)
    $haEvents = @($haTyped + $haText) | Where-Object { $_ } |
        Sort-Object CreatedTime |
        Select-Object -Unique CreatedTime, @{N="EventType";E={$_.GetType().Name}}, @{N="VMId";E={ if ($_.Vm) {$_.Vm.Vm} else {""} }}, FullFormattedMessage

    foreach ($e in $haEvents) {
        $vmName = $null
        if ($e.Vm) { $vmName = $e.Vm.Name }

        $hostName = $null
        if ($e.Host) { $hostName = $e.Host.Name }

        $results.Add([pscustomobject]@{
            Cluster   = $cluster.Name
            Time      = $e.CreatedTime
            VM        = $vmName
            Host      = $hostName
            User      = $e.UserName
            EventType = $e.GetType().Name
            Message   = $e.FullFormattedMessage
        })
    }
}

# ---------- SALIDA ----------
$resultsSorted = $results | Sort-Object Time, Cluster, VM
$resultsSorted | Format-Table -AutoSize

# Export CSV
$resultsSorted | Export-Csv -Path $csvOut -NoTypeInformation -Encoding UTF8
Write-Host "CSV generado: $csvOut" -ForegroundColor Green
