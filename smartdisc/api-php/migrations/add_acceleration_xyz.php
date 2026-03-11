<?php
// Migration: Add acceleration X, Y, Z columns to wurfe table
require_once __DIR__ . '/../db.php';

echo "Adding acceleration X, Y, Z columns to wurfe table...\n";

try {
    // Check if columns already exist
    $columns = $pdo->query("PRAGMA table_info(wurfe)")->fetchAll(PDO::FETCH_ASSOC);
    $columnNames = array_column($columns, 'name');
    
    $needsAccelX = !in_array('acceleration_x', $columnNames);
    $needsAccelY = !in_array('acceleration_y', $columnNames);
    $needsAccelZ = !in_array('acceleration_z', $columnNames);
    
    if ($needsAccelX) {
        $pdo->exec("ALTER TABLE wurfe ADD COLUMN acceleration_x REAL");
        echo "✓ Added acceleration_x column\n";
    } else {
        echo "  acceleration_x already exists\n";
    }
    
    if ($needsAccelY) {
        $pdo->exec("ALTER TABLE wurfe ADD COLUMN acceleration_y REAL");
        echo "✓ Added acceleration_y column\n";
    } else {
        echo "  acceleration_y already exists\n";
    }
    
    if ($needsAccelZ) {
        $pdo->exec("ALTER TABLE wurfe ADD COLUMN acceleration_z REAL");
        echo "✓ Added acceleration_z column\n";
    } else {
        echo "  acceleration_z already exists\n";
    }
    
    echo "\nMigration complete!\n";
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
    exit(1);
}
