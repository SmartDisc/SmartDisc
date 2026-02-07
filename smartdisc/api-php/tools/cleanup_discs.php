<?php
/**
 * Cleanup script to identify and deactivate unused discs
 * Run: php cleanup_discs.php [--dry-run] [--delete-test-data]
 */

require_once __DIR__ . '/../db.php';

$dryRun = in_array('--dry-run', $argv);
$deleteTestData = in_array('--delete-test-data', $argv);

echo "=== SmartDisc Disc Cleanup Tool ===\n\n";

if ($dryRun) {
    echo "[DRY RUN MODE] No changes will be made.\n\n";
}

// Get all active discs
$stmt = $pdo->query("SELECT id, name, erstellt_am FROM scheiben WHERE aktiv = 1 ORDER BY erstellt_am DESC");
$allDiscs = $stmt->fetchAll();

if (empty($allDiscs)) {
    echo "No active discs found.\n";
    exit(0);
}

echo "Found " . count($allDiscs) . " active disc(s):\n";
foreach ($allDiscs as $disc) {
    echo "  - {$disc['id']}: {$disc['name']} (created: {$disc['erstellt_am']})\n";
}
echo "\n";

// Find discs with no throws
$stmt = $pdo->query("
    SELECT DISTINCT scheibe_id FROM wurfe WHERE geloescht = 0
");
$discsWithData = array_map(fn($row) => $row['scheibe_id'], $stmt->fetchAll());

echo "Discs with throw data: " . count($discsWithData) . "\n";
foreach ($discsWithData as $discId) {
    // Count throws for this disc
    $stmt = $pdo->prepare("SELECT COUNT(*) as cnt FROM wurfe WHERE scheibe_id = :id AND geloescht = 0");
    $stmt->execute([':id' => $discId]);
    $count = $stmt->fetchColumn();
    echo "  - $discId: $count throw(s)\n";
}
echo "\n";

// Find unused discs
$unusedDiscs = [];
foreach ($allDiscs as $disc) {
    if (!in_array($disc['id'], $discsWithData)) {
        $unusedDiscs[] = $disc;
    }
}

if (empty($unusedDiscs)) {
    echo "All discs have throw data. Nothing to clean up.\n";
    exit(0);
}

echo "Unused discs (no throw data):\n";
foreach ($unusedDiscs as $disc) {
    echo "  - {$disc['id']}: {$disc['name']}\n";
}
echo "\n";

if ($deleteTestData) {
    echo "Deleting unused discs...\n";
    foreach ($unusedDiscs as $disc) {
        if ($dryRun) {
            echo "  [DRY RUN] Would deactivate: {$disc['id']}\n";
        } else {
            $stmt = $pdo->prepare("UPDATE scheiben SET aktiv = 0 WHERE id = :id");
            $stmt->execute([':id' => $disc['id']]);
            echo "  ✓ Deactivated: {$disc['id']}\n";
        }
    }
    echo "\nCleanup complete.\n";
} else {
    echo "To delete these unused discs, run:\n";
    echo "  php cleanup_discs.php --delete-test-data\n\n";
    echo "To do a dry run first:\n";
    echo "  php cleanup_discs.php --dry-run --delete-test-data\n";
}
