# ESP32 Simulator - PowerShell Version
# Simulates ESP32 hardware sending throws to backend
# No Python required!

param(
    [int]$NumThrows = 0,  # 0 = infinite mode
    [string]$DiscId = "1",
    [double]$MinDelay = 2.0,
    [double]$MaxDelay = 5.0,
    [switch]$GameMode  # Simulate realistic game patterns
)

$ApiUrl = "http://localhost:8000/api/wurfe"

function Generate-RealisticThrow {
    param([string]$DiscId)
    
    # Physics-based throw simulation
    $baseAcceleration = Get-Random -Minimum 8.0 -Maximum 25.0
    
    # Rotation correlates with power (300-500 RPM = 5-8.3 rps for pro)
    $rotationFactor = ($baseAcceleration - 8.0) / 17.0
    $baseRotation = 2.0 + ($rotationFactor * 6.5)
    
    # Height correlates with rotation (more spin = more lift)
    $heightFactor = $rotationFactor * 0.7 + (Get-Random -Minimum 0.0 -Maximum 0.3)
    $baseHeight = 0.5 + ($heightFactor * 3.0)
    
    # Generate 3-axis acceleration (Z-axis dominant 70-85%)
    $zFactor = Get-Random -Minimum 0.70 -Maximum 0.85
    $accelZ = $baseAcceleration * $zFactor
    
    # Remaining acceleration distributed between X and Y
    $remaining = $baseAcceleration * (1.0 - $zFactor)
    $xFactor = Get-Random -Minimum 0.3 -Maximum 0.7
    $accelX = $remaining * $xFactor
    $accelY = $remaining * (1.0 - $xFactor)
    
    # Add IMU sensor noise
    $rotation = [Math]::Round($baseRotation + (Get-Random -Minimum -0.05 -Maximum 0.05), 2)
    $height = [Math]::Round($baseHeight + (Get-Random -Minimum -0.02 -Maximum 0.02), 2)
    $accelX = [Math]::Round($accelX + (Get-Random -Minimum -0.3 -Maximum 0.3), 1)
    $accelY = [Math]::Round($accelY + (Get-Random -Minimum -0.3 -Maximum 0.3), 1)
    $accelZ = [Math]::Round($accelZ + (Get-Random -Minimum -0.3 -Maximum 0.3), 1)
    
    # Clamp to physical limits
    $rotation = [Math]::Max(0.5, [Math]::Min(10.0, $rotation))
    $height = [Math]::Max(0.1, [Math]::Min(4.0, $height))
    $accelX = [Math]::Max(-10.0, [Math]::Min(10.0, $accelX))
    $accelY = [Math]::Max(-10.0, [Math]::Min(10.0, $accelY))
    $accelZ = [Math]::Max(5.0, [Math]::Min(30.0, $accelZ))
    
    return @{
        scheibe_id = $DiscId
        rotation = $rotation
        hoehe = $height
        acceleration_x = $accelX
        acceleration_y = $accelY
        acceleration_z = $accelZ
    }
}

function Send-Throw {
    param(
        [hashtable]$ThrowData,
        $ThrowNumber,
        $TotalThrows
    )
    
    try {
        $body = $ThrowData | ConvertTo-Json -Compress
        $response = Invoke-WebRequest -Uri $ApiUrl `
            -Method POST `
            -Body $body `
            -ContentType "application/json" `
            -UseBasicParsing `
            -ErrorAction Stop
        
        $result = $response.Content | ConvertFrom-Json
        
        $discId = $ThrowData.scheibe_id
        $rot = $ThrowData.rotation
        $h = $ThrowData.hoehe
        $ax = $ThrowData.acceleration_x
        $ay = $ThrowData.acceleration_y
        $az = $ThrowData.acceleration_z
        
        $displayTotal = if ($TotalThrows -is [string]) { $TotalThrows } else { $TotalThrows }
        
        if ($result.is_duplicate) {
            Write-Host "[$ThrowNumber/$displayTotal] [DUPE] Disc #$discId | Rot: $rot rps | H: $h m | A: X=$ax Y=$ay Z=$az m/s²" -ForegroundColor Yellow
        } else {
            Write-Host "[$ThrowNumber/$displayTotal] [ OK ] Disc #$discId | Rot: $rot rps | H: $h m | A: X=$ax Y=$ay Z=$az m/s²" -ForegroundColor Green
        }
        
        if ($result.is_new_record) {
            $recordType = $result.record_type.ToUpper()
            Write-Host "  🏆 NEW RECORD: $recordType" -ForegroundColor Yellow
        }
        
        return $true
    }
    catch {
        Write-Host "[$ThrowNumber/$displayTotal] [FAIL] Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main execution
Write-Host ""
Write-Host ("="*70) -ForegroundColor Cyan
Write-Host "ESP32 HARDWARE SIMULATOR (PowerShell)" -ForegroundColor Cyan
Write-Host ("="*70) -ForegroundColor Cyan
Write-Host "Backend:     $ApiUrl"
Write-Host "Disc ID:     $DiscId"

if ($NumThrows -eq 0) {
    Write-Host "Mode:        INFINITE (Press Ctrl+C to stop)" -ForegroundColor Yellow
} else {
    Write-Host "Throws:      $NumThrows"
}

if ($GameMode) {
    Write-Host "Game Mode:   Active (realistic game patterns)" -ForegroundColor Green
    Write-Host "  • Practice rounds: 5-10 throws"
    Write-Host "  • Break between rounds: 10-20s"
    Write-Host "  • Throw delay: 2-6s (variable intensity)"
} else {
    Write-Host "Delay:       $MinDelay-${MaxDelay}s (random, like real practice)"
}

Write-Host "Physics:     Correlated rotation/height/acceleration"
Write-Host "Sensor:      IMU noise simulation enabled"
Write-Host ("="*70) -ForegroundColor Cyan
Write-Host ""

$successful = 0
$failed = 0
$throwCount = 0
$roundNumber = 1

# Infinite mode or fixed throws
if ($NumThrows -eq 0) {
    Write-Host "Starting infinite game simulation..." -ForegroundColor Cyan
    Write-Host "TIP: Use Ctrl+C to stop the simulation" -ForegroundColor Gray
    Write-Host ""
    
    while ($true) {
        if ($GameMode) {
            # Game mode: Simulate rounds with breaks
            $throwsInRound = Get-Random -Minimum 5 -Maximum 11
            Write-Host "`n--- Round $roundNumber (${throwsInRound} throws) ---" -ForegroundColor Magenta
            
            for ($i = 1; $i -le $throwsInRound; $i++) {
                $throwCount++
                $throwData = Generate-RealisticThrow -DiscId $DiscId
                
                $displayNum = if ($NumThrows -eq 0) { $throwCount } else { $throwCount }
                $displayTotal = if ($NumThrows -eq 0) { "∞" } else { $NumThrows }
                
                if (Send-Throw -ThrowData $throwData -ThrowNumber $displayNum -TotalThrows $displayTotal) {
                    $successful++
                } else {
                    $failed++
                }
                
                # Variable delay between throws (2-6 seconds)
                if ($i -lt $throwsInRound) {
                    $delay = Get-Random -Minimum 2.0 -Maximum 6.0
                    Start-Sleep -Seconds $delay
                }
            }
            
            # Break between rounds (10-20 seconds)
            $breakTime = Get-Random -Minimum 10 -Maximum 21
            Write-Host "`n⏸  Break time: ${breakTime}s (preparing for next round...)" -ForegroundColor DarkGray
            Start-Sleep -Seconds $breakTime
            $roundNumber++
            
        } else {
            # Standard continuous mode
            $throwCount++
            $throwData = Generate-RealisticThrow -DiscId $DiscId
            
            if (Send-Throw -ThrowData $throwData -ThrowNumber $throwCount -TotalThrows "∞") {
                $successful++
            } else {
                $failed++
            }
            
            $delay = Get-Random -Minimum $MinDelay -Maximum $MaxDelay
            Start-Sleep -Seconds $delay
        }
    }
    
} else {
    # Fixed number of throws
    for ($i = 1; $i -le $NumThrows; $i++) {
        $throwData = Generate-RealisticThrow -DiscId $DiscId
        
        if (Send-Throw -ThrowData $throwData -ThrowNumber $i -TotalThrows $NumThrows) {
            $successful++
        } else {
            $failed++
        }
        
        # Delay between throws (except last one)
        if ($i -lt $NumThrows) {
            $delay = Get-Random -Minimum $MinDelay -Maximum $MaxDelay
            Start-Sleep -Seconds $delay
        }
    }
    
    Write-Host ""
    Write-Host ("="*70) -ForegroundColor Cyan
    Write-Host "Session Complete"
    Write-Host "  Successful: $successful" -ForegroundColor Green
    if ($failed -gt 0) {
        Write-Host "  Failed:     $failed" -ForegroundColor Red
    }
    Write-Host ("="*70) -ForegroundColor Cyan
    Write-Host ""
}
