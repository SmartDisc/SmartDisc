<?php
// GET /live.php - Optional Server-Sent Events endpoint.
// Streams newly inserted measurements (processed BLE payload rows from wurfe table).
// Clients receive "event: update" with JSON array of new rows (id, scheibe_id, rotation, hoehe, acceleration_* , erstellt_am).

require_once __DIR__ . '/db.php';

header('Content-Type: text/event-stream');
header('Cache-Control: no-cache');
header('Connection: keep-alive');
header('Access-Control-Allow-Origin: *');

$lastTimestamp = $pdo->query("SELECT COALESCE(MAX(erstellt_am), '1970-01-01T00:00:00Z') FROM wurfe WHERE geloescht = 0")->fetchColumn();

while (true) {
  $stmt = $pdo->prepare("SELECT id, scheibe_id, player_id, rotation, hoehe, acceleration_x, acceleration_y, acceleration_z, acceleration_max, erstellt_am
                         FROM wurfe 
                         WHERE erstellt_am > :last_ts AND geloescht = 0 
                         ORDER BY erstellt_am ASC LIMIT 50");
  $stmt->execute([':last_ts' => $lastTimestamp]);
  $rows = $stmt->fetchAll();
  if (!empty($rows)) {
    $lastTimestamp = end($rows)['erstellt_am'];
    echo "event: update\n";
    echo "data: " . json_encode($rows) . "\n\n";
    @ob_flush();
    flush();
  }
  usleep(200000);
}
