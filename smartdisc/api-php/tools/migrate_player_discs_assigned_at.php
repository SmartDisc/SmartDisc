<?php
// Migration: Ensure assigned_at has proper default and existing rows have values
// Run: php tools/migrate_player_discs_assigned_at.php

require_once __DIR__ . '/../db.php';

echo "Migrating player_discs table...\n";

try {
    // Check if table exists
    $tableExists = $pdo->query("SELECT name FROM sqlite_master WHERE type='table' AND name='player_discs'")->fetch();
    
    if (!$tableExists) {
        echo "Table player_discs does not exist. Creating...\n";
        $pdo->exec("
            CREATE TABLE player_discs (
                player_id TEXT NOT NULL,
                disc_id TEXT NOT NULL,
                assigned_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')) NOT NULL,
                PRIMARY KEY (player_id, disc_id),
                FOREIGN KEY (player_id) REFERENCES users(id) ON DELETE CASCADE,
                FOREIGN KEY (disc_id) REFERENCES scheiben(id) ON DELETE CASCADE
            );
            CREATE INDEX IF NOT EXISTS idx_player_discs_player_id ON player_discs(player_id);
            CREATE INDEX IF NOT EXISTS idx_player_discs_disc_id ON player_discs(disc_id);
        ");
        echo "✓ Table created\n";
    } else {
        // Update existing rows that have NULL assigned_at
        $updateStmt = $pdo->prepare("
            UPDATE player_discs 
            SET assigned_at = strftime('%Y-%m-%dT%H:%M:%fZ','now')
            WHERE assigned_at IS NULL
        ");
        $updated = $updateStmt->execute();
        $rowCount = $updateStmt->rowCount();
        if ($rowCount > 0) {
            echo "✓ Updated $rowCount rows with NULL assigned_at\n";
        } else {
            echo "✓ No rows needed updating\n";
        }
        
        // Ensure default constraint exists (SQLite doesn't support ALTER COLUMN DEFAULT easily)
        // The default is handled in INSERT statements, but we verify the schema
        $columns = $pdo->query("PRAGMA table_info(player_discs)")->fetchAll(PDO::FETCH_ASSOC);
        $hasAssignedAt = false;
        foreach ($columns as $col) {
            if ($col['name'] === 'assigned_at') {
                $hasAssignedAt = true;
                if ($col['notnull'] == 0) {
                    echo "⚠ Warning: assigned_at allows NULL. Consider recreating table.\n";
                }
                break;
            }
        }
        if (!$hasAssignedAt) {
            echo "⚠ Warning: assigned_at column not found. Table may need recreation.\n";
        }
    }
    
    echo "\nMigration completed successfully!\n";
} catch (Exception $e) {
    echo "✗ Error: " . $e->getMessage() . "\n";
    exit(1);
}
