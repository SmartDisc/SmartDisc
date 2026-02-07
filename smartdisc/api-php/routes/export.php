<?php
// Export routes: GET CSV export

// GET /api/exports/throws?format=csv&discId=...&minHeight=...&maxHeight=...&minAcc=...&maxAcc=...&minRot=...&maxRot=...
if ($path === "$prefix/exports/throws" && $method === 'GET') {
  $token = require_auth();
  $user = get_user_by_token($token);
  if (!$user) {
    json_response(['error' => ['code' => 'UNAUTHORIZED', 'message' => 'Token ungültig']], 401);
  }

  $format = strtolower($_GET['format'] ?? 'csv');
  if ($format !== 'csv') {
    json_response(['error' => ['code' => 'BAD_REQUEST', 'message' => 'Unsupported export format']], 400);
  }

  $where = ['geloescht = 0', 'player_id = :player_id'];
  $params = [':player_id' => $user['id']];

  if (!empty($_GET['discId'])) {
    $where[] = 'scheibe_id = :scheibe_id';
    $params[':scheibe_id'] = $_GET['discId'];
  }

  if (isset($_GET['minHeight']) && is_numeric($_GET['minHeight'])) {
    $where[] = 'hoehe >= :min_hoehe';
    $params[':min_hoehe'] = floatval($_GET['minHeight']);
  }
  if (isset($_GET['maxHeight']) && is_numeric($_GET['maxHeight'])) {
    $where[] = 'hoehe <= :max_hoehe';
    $params[':max_hoehe'] = floatval($_GET['maxHeight']);
  }

  if (isset($_GET['minAcc']) && is_numeric($_GET['minAcc'])) {
    $where[] = 'acceleration_max >= :min_acc';
    $params[':min_acc'] = floatval($_GET['minAcc']);
  }
  if (isset($_GET['maxAcc']) && is_numeric($_GET['maxAcc'])) {
    $where[] = 'acceleration_max <= :max_acc';
    $params[':max_acc'] = floatval($_GET['maxAcc']);
  }

  if (isset($_GET['minRot']) && is_numeric($_GET['minRot'])) {
    $where[] = 'rotation >= :min_rot';
    $params[':min_rot'] = floatval($_GET['minRot']);
  }
  if (isset($_GET['maxRot']) && is_numeric($_GET['maxRot'])) {
    $where[] = 'rotation <= :max_rot';
    $params[':max_rot'] = floatval($_GET['maxRot']);
  }

  header('Content-Type: text/csv; charset=utf-8');
  header('Content-Disposition: attachment; filename="smartdisc_throws.csv"');
  $out = fopen('php://output', 'w');
  fputcsv($out, ['id', 'scheibe_id', 'player_id', 'rotation', 'hoehe', 'acceleration_max', 'erstellt_am'], ';');

  $sql = "SELECT id, scheibe_id, player_id, rotation, hoehe, acceleration_max, erstellt_am FROM wurfe WHERE " . implode(' AND ', $where) . " ORDER BY erstellt_am DESC";
  $stmt = $pdo->prepare($sql);
  $stmt->execute($params);
  while ($row = $stmt->fetch()) {
    fputcsv($out, $row, ';');
  }
  fclose($out);
  exit;
}

// GET /api/export.csv (legacy)
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
