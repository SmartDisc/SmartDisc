<?php
// Export routes: GET CSV export

// GET /api/export.csv
if ($path === "$prefix/export.csv" && $method === 'GET') {
  header('Content-Type: text/csv; charset=utf-8');
  header('Content-Disposition: attachment; filename="smartdisc_throws.csv"');
  $out = fopen('php://output', 'w');
  fputcsv($out, ['id', 'scheibe_id', 'player_id', 'rotation', 'hoehe', 'acceleration_max', 'erstellt_am'], ';');
  $stmt = $pdo->query("SELECT id, scheibe_id, player_id, rotation, hoehe, acceleration_max, erstellt_am FROM wurfe WHERE geloescht = 0 ORDER BY erstellt_am DESC");
  while ($row = $stmt->fetch()) {
    fputcsv($out, $row, ';');
  }
  fclose($out);
  exit;
}
