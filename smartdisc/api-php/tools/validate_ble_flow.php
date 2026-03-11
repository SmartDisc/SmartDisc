<?php
/**
 * BLE flow validation: one accepted packet → one row, GET with scheibe_id filter.
 *
 * Run from repo root: php api-php/tools/validate_ble_flow.php
 *
 * 1. Asserts one INSERT creates exactly one new row in wurfe.
 * 2. Asserts GET-style query with string scheibe_id returns that row.
 * 3. Asserts filtering by another scheibe_id does not return that row.
 * 4. Cleans up the test row.
 */

require_once __DIR__ . '/../db.php';

$testScheibeId = 'validation_disc_' . time();
$testId = 'wurf_validation_' . bin2hex(random_bytes(4)) . '_' . time();

// --- Count before ---
$stmt = $pdo->query("SELECT COUNT(*) FROM wurfe");
$countBefore = (int) $stmt->fetchColumn();

// --- Insert one row (same payload shape as POST /api/wurfe from Flutter) ---
$insertSql = "
  INSERT INTO wurfe (
    id, scheibe_id, player_id, rotation, hoehe,
    acceleration_x, acceleration_y, acceleration_z, acceleration_max
  ) VALUES (
    :id, :scheibe_id, :player_id, :rotation, :hoehe,
    :acceleration_x, :acceleration_y, :acceleration_z, :acceleration_max
  )
";
$insertStmt = $pdo->prepare($insertSql);
$insertStmt->execute([
  ':id' => $testId,
  ':scheibe_id' => $testScheibeId,
  ':player_id' => null,
  ':rotation' => 12.5,
  ':hoehe' => 1.8,
  ':acceleration_x' => 0.1,
  ':acceleration_y' => 0.2,
  ':acceleration_z' => 9.81,
  ':acceleration_max' => 9.82,
]);

// --- Count after: must be exactly +1 ---
$stmt = $pdo->query("SELECT COUNT(*) FROM wurfe");
$countAfter = (int) $stmt->fetchColumn();
$added = $countAfter - $countBefore;

if ($added !== 1) {
  fwrite(STDERR, "FAIL: Expected exactly 1 new row, got $added (before=$countBefore, after=$countAfter)\n");
  exit(1);
}

// --- GET-style list with scheibe_id filter (string) ---
$where = ['geloescht = 0', "scheibe_id = :scheibe_id"];
$params = [':scheibe_id' => (string) $testScheibeId];
$limit = 100;
$sql = "SELECT id, scheibe_id, player_id, rotation, hoehe, acceleration_x, acceleration_y, acceleration_z, acceleration_max, erstellt_am FROM wurfe WHERE " . implode(' AND ', $where) . " ORDER BY erstellt_am DESC LIMIT " . (int) $limit;
$stmt = $pdo->prepare($sql);
foreach ($params as $k => $v) {
  $stmt->bindValue($k, $v);
}
$stmt->execute();
$items = $stmt->fetchAll(PDO::FETCH_ASSOC);

$found = null;
foreach ($items as $row) {
  if ($row['id'] === $testId && $row['scheibe_id'] === $testScheibeId) {
    $found = $row;
    break;
  }
}

if (!$found) {
  fwrite(STDERR, "FAIL: GET with scheibe_id=" . $testScheibeId . " did not return the inserted row. Items: " . count($items) . "\n");
  _cleanup($pdo, $testId);
  exit(1);
}

// --- Filter by different scheibe_id: our row must not appear ---
$otherScheibeId = 'other_disc_999';
$stmt = $pdo->prepare("SELECT id FROM wurfe WHERE geloescht = 0 AND scheibe_id = :scheibe_id");
$stmt->execute([':scheibe_id' => (string) $otherScheibeId]);
$otherItems = $stmt->fetchAll(PDO::FETCH_COLUMN);
$ourIdInOther = in_array($testId, $otherItems, true);

if ($ourIdInOther) {
  fwrite(STDERR, "FAIL: Row with scheibe_id=" . $testScheibeId . " was returned when filtering by scheibe_id=" . $otherScheibeId . "\n");
  _cleanup($pdo, $testId);
  exit(1);
}

// --- Cleanup ---
_cleanup($pdo, $testId);

echo "OK: One accepted BLE packet → one DB row; GET with string scheibe_id returns it; other filter excludes it.\n";
exit(0);

function _cleanup(PDO $pdo, string $id): void {
  $pdo->prepare("DELETE FROM wurfe WHERE id = ?")->execute([$id]);
}
