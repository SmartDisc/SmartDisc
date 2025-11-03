<?php
require_once __DIR__ . '/db.php';

header('Content-Type: text/event-stream');
header('Cache-Control: no-cache');
header('Connection: keep-alive');
header('Access-Control-Allow-Origin: *');

$lastRowId = intval($pdo->query("SELECT COALESCE(MAX(rowid),0) FROM messungen")->fetchColumn());

while (true) {
  $stmt = $pdo->prepare("SELECT rowid, id, wurf_id, zeitpunkt, beschleunigung_x, beschleunigung_y, beschleunigung_z, temperatur
                         FROM messungen WHERE rowid > :rid ORDER BY rowid ASC LIMIT 200");
  $stmt->execute([':rid' => $lastRowId]);
  $rows = $stmt->fetchAll();
  if (!empty($rows)) {
    $lastRowId = end($rows)['rowid'];
    echo "event: update
";
    echo "data: " . json_encode($rows) . "\n\n";
    @ob_flush(); flush();
  }
  usleep(200000);
}
