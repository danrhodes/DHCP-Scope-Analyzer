# Import the DHCP Server module
Import-Module DHCPServer

# Get the local computer name if no server name is provided
$ServerName = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } else { [System.Net.Dns]::GetHostName() }

function Compare-IPAddress {
    param (
        [string]$IP1,
        [string]$IP2
    )
    $ip1Parts = $IP1.Split('.') | ForEach-Object { [int]$_ }
    $ip2Parts = $IP2.Split('.') | ForEach-Object { [int]$_ }
    
    for ($i = 0; $i -lt 4; $i++) {
        if ($ip1Parts[$i] -lt $ip2Parts[$i]) { return -1 }
        if ($ip1Parts[$i] -gt $ip2Parts[$i]) { return 1 }
    }
    return 0
}

function Get-NextIP {
    param ([string]$IP)
    $octets = $IP.Split('.') | ForEach-Object { [int]$_ }
    $octets[3]++
    for ($i = 3; $i -gt 0; $i--) {
        if ($octets[$i] -eq 256) {
            $octets[$i] = 0
            $octets[$i-1]++
        }
    }
    return $octets -join '.'
}

function Get-PreviousIP {
    param ([string]$IP)
    $octets = $IP.Split('.') | ForEach-Object { [int]$_ }
    $octets[3]--
    for ($i = 3; $i -gt 0; $i--) {
        if ($octets[$i] -eq -1) {
            $octets[$i] = 255
            $octets[$i-1]--
        }
    }
    return $octets -join '.'
}

function Get-IPRange {
    param (
        [string]$StartIP,
        [string]$EndIP
    )
    $current = $StartIP
    $range = @($current)
    while ((Compare-IPAddress $current $EndIP) -lt 0) {
        $current = Get-NextIP $current
        $range += $current
    }
    return $range
}

function Get-BestDHCPRange {
    param (
        [string]$ServerName,
        [Microsoft.Management.Infrastructure.CimInstance]$Scope
    )

    $allIPs = Get-IPRange $Scope.StartRange $Scope.EndRange

    # Get exclusion ranges
    $exclusions = Get-DhcpServerv4ExclusionRange -ComputerName $ServerName -ScopeId $Scope.ScopeId

    Write-Host "Debug: Initial range: $($Scope.StartRange) - $($Scope.EndRange)"
    Write-Host "Debug: Total IPs: $($allIPs.Count)"

    foreach ($exclusion in $exclusions) {
        Write-Host "Debug: Processing exclusion: $($exclusion.StartRange) - $($exclusion.EndRange)"
        $exclusionRange = Get-IPRange $exclusion.StartRange $exclusion.EndRange
        $allIPs = $allIPs | Where-Object { $_ -notin $exclusionRange }
    }

    Write-Host "Debug: IPs after exclusions: $($allIPs.Count)"

    if ($allIPs.Count -eq 0) {
        Write-Host "Debug: No available IPs after exclusions"
        return $null
    }

    $ranges = @()
    $startIP = $allIPs[0]
    $prevIP = $allIPs[0]

    for ($i = 1; $i -lt $allIPs.Count; $i++) {
        if ((Compare-IPAddress (Get-NextIP $prevIP) $allIPs[$i]) -ne 0) {
            $ranges += ,@($startIP, $prevIP)
            $startIP = $allIPs[$i]
        }
        $prevIP = $allIPs[$i]
    }
    $ranges += ,@($startIP, $prevIP)

    $bestRange = $ranges | Sort-Object { (Get-IPRange $_[0] $_[1]).Count } | Select-Object -Last 1

    $availableHosts = (Get-IPRange $bestRange[0] $bestRange[1]).Count

    Write-Host "Debug: Scope $($Scope.ScopeId)"
    Write-Host "Debug: Subnet Mask: $($Scope.SubnetMask)"
    Write-Host "Debug: Start Range: $($Scope.StartRange)"
    Write-Host "Debug: End Range: $($Scope.EndRange)"
    Write-Host "Debug: Exclusions:"
    foreach ($exclusion in $exclusions) {
        Write-Host "  $($exclusion.StartRange) - $($exclusion.EndRange)"
    }
    Write-Host "Debug: Best Start IP: $($bestRange[0])"
    Write-Host "Debug: Best End IP: $($bestRange[1])"
    Write-Host "Debug: Available Hosts: $availableHosts"

    return @{
        ScopeId = $Scope.ScopeId
        ScopeName = $Scope.Name
        StartIP = $bestRange[0]
        EndIP = $bestRange[1]
        AvailableHosts = $availableHosts
    }
}

# Get all DHCP scopes on the server
$scopes = Get-DhcpServerv4Scope -ComputerName $ServerName

# Analyze each scope and collect reservations
$results = @()
$output = @()

foreach ($scope in $scopes) {
    # Analyze best DHCP range
    $result = Get-BestDHCPRange -ServerName $ServerName -Scope $scope
    if ($result -ne $null) {
        $results += $result
    }

    # Get all the reservations for the current scope
    $reservations = Get-DhcpServerv4Reservation -ComputerName $ServerName -ScopeId $scope.ScopeId

    # Loop through the reservations, converting the MAC addresses and building the output object
    foreach ($reservation in $reservations) {
        $ipAddress = $reservation.IPAddress
        $macAddress = $reservation.ClientId
        if ($macAddress -notmatch '-') {
            $macAddress = ($macAddress -split '(..)' | Where-Object { $_ } | ForEach-Object { "$_-" }) -join ''
            $macAddress = $macAddress.TrimEnd('-')
        }

        $output += "$ipAddress $macAddress"
    }
}

# Output results
Write-Host "Best DHCP Ranges for server $ServerName"
foreach ($result in $results) {
    Write-Host ""
    Write-Host "Scope: $($result.ScopeId) ($($result.ScopeName))"
    Write-Host "  Start IP: $($result.StartIP)"
    Write-Host "  End IP: $($result.EndIP)"
    Write-Host "  Available Hosts: $($result.AvailableHosts)"
}

# Export the collection to a .cfg file in the same directory as the script
$output | Out-File -FilePath "$PSScriptRoot\ipbindmac.cfg"

Write-Host "`nReservations exported to $PSScriptRoot\ipbindmac.cfg"