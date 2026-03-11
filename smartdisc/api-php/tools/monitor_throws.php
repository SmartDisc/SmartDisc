<?php
/**
 * Real-time throw monitor - shows incoming throws as they arrive
 * Usage: php tools/monitor_throws.php
 */

require_once __DIR__ . '/../db.php';

echo "\n";
echo "╔══════════════════════════════════════════════════════════════════╗\n";
echo "║         SmartDisc Throw Monitor - Real-time Backend View        ║\n";
echo "╚══════════════════════════════════════════════════════════════════╝\n";
echo "\n";
echo "Monitoring throws... (Press Ctrl+C to stop)\n";
echo str_repeat("─", 70) . "\n";

$lastId = null;
$totalCount = 0;

// Get last throw ID to start monitoring from
$stmt = $pdo->query("SELECT id FROM wurfe ORDER BY erstellt_am DESC LIMIT 1");
$lastRow = $stmt->fetch(PDO::FETCH_ASSOC);
if ($lastRow) {
    $lastId = $lastRow['id'];
}

echo "Starting from last throw: " . ($lastId ?? 'none') . "\n";
echo str_repeat("─", 70) . "\n\n";

while (true) {
    // Check for new throws
    if ($lastId === null) {
        $stmt = $pdo->query("
            SELECT id, scheibe_id, rotation, hoehe, 
                   acceleration_x, acceleration_y, acceleration_z, acceleration_max,
                   datetime(erstellt_am) as time 
            FROM wurfe 
            WHERE geloescht = 0
            ORDER BY erstellt_am DESC 
            LIMIT 1
        ");
    } else {
        $stmt = $pdo->prepare("
            SELECT id, scheibe_id, rotation, hoehe, 
                   acceleration_x, acceleration_y, acceleration_z, acceleration_max,
                   datetime(erstellt_am) as time 
            FROM wurfe 
            WHERE geloescht = 0 
              AND erstellt_am > (SELECT erstellt_am FROM wurfe WHERE id = :last_id)
            ORDER BY erstellt_am ASC
        ");
        $stmt->execute([':last_id' => $lastId]);
    }
    
    $newThrows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    foreach ($newThrows as $throw) {
        $totalCount++;
        $lastId = $throw['id'];
        
        // Format acceleration display
        if ($throw['acceleration_x'] !== null && $throw['acceleration_y'] !== null && $throw['acceleration_z'] !== null) {
            $accelDisplay = sprintf(
                "X=%.1f Y=%.1f Z=%.1f → Max=%.1f m/s²",
                $throw['acceleration_x'],
                $throw['acceleration_y'],
                $throw['acceleration_z'],
                $throw['acceleration_max']
            );
        } elseif ($throw['acceleration_max'] !== null) {
            $accelDisplay = sprintf("Max=%.1f m/s²", $throw['acceleration_max']);
        } else {
            $accelDisplay = "-";
        }
        
        // Color-coded output
        $color = "\033[32m"; // Green
        $reset = "\033[0m";
        $bold = "\033[1m";
        
        echo $color . "[$totalCount] " . $bold . "NEW THROW!" . $reset . " " . $throw['time'] . "\n";
        echo "  Disc:         " . ($throw['scheibe_id'] ?? '-') . "\n";
        echo "  Rotation:     " . ($throw['rotation'] !== null ? sprintf("%.2f rps (%.0f rpm)", $throw['rotation'], $throw['rotation'] * 60) : '-') . "\n";
        echo "  Height:       " . ($throw['hoehe'] !== null ? sprintf("%.2f m", $throw['hoehe']) : '-') . "\n";
        echo "  Acceleration: " . $accelDisplay . "\n";
        echo str_repeat("─", 70) . "\n";
    }
    
    // Sleep for a bit before checking again
    usleep(500000); // 0.5 seconds
}
