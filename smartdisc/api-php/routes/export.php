<?php
// Export routes: GET CSV export

// GET /api/exports/throws?format=csv&discId=...&minHeight=...&maxHeight=...&minAcc=...&maxAcc=...&minRot=...&maxRot=...
if ($path === "$prefix/exports/throws" && $method === 'GET') {
  $token = require_auth();
  $user = get_user_by_token($token);
  if (!$user) {
    json_response(['error' => ['code' => 'UNAUTHORIZED', 'message' => 'Token ungültig']], 401);
    exit;
  }

  $format = strtolower($_GET['format'] ?? 'csv');
  if ($format !== 'csv') {
    json_response(['error' => ['code' => 'BAD_REQUEST', 'message' => 'Unsupported export format']], 400);
    exit;
  }

  $where = ['w.geloescht = 0'];
  $params = [];

  if (($user['role'] ?? null) === 'trainer') {
    // Trainers see all throws; optional filter by player or disc
    if (!empty($_GET['playerId'])) {
      $where[] = 'w.player_id = :player_id';
      $params[':player_id'] = $_GET['playerId'];
    }
  } else {
    // Players see throws from discs assigned to them (same logic as GET /api/wurfe)
    $where[] = "EXISTS (
      SELECT 1
      FROM disc_assignments da
      JOIN scheiben s ON s.id = da.disc_id
      WHERE da.player_id = :current_player_id
        AND (da.disc_id = w.scheibe_id OR s.name = w.scheibe_id)
    )";
    $params[':current_player_id'] = $user['id'];
  }

  // Disc filter: accept discId or scheibe_id. Match throws where scheibe_id equals the param,
  // or the disc's name when param is id, or the disc's id when param is name (same as Analysis filter).
  $discParam = trim((string) ($_GET['discId'] ?? $_GET['scheibe_id'] ?? ''));
  if ($discParam !== '') {
    $where[] = "(w.scheibe_id = :scheibe_id
      OR w.scheibe_id = (SELECT s.name FROM scheiben s WHERE s.id = :scheibe_id LIMIT 1)
      OR w.scheibe_id = (SELECT s.id FROM scheiben s WHERE s.name = :scheibe_id LIMIT 1))";
    $params[':scheibe_id'] = $discParam;
  }

  if (isset($_GET['minHeight']) && is_numeric($_GET['minHeight'])) {
    $where[] = 'w.hoehe >= :min_hoehe';
    $params[':min_hoehe'] = floatval($_GET['minHeight']);
  }
  if (isset($_GET['maxHeight']) && is_numeric($_GET['maxHeight'])) {
    $where[] = 'w.hoehe <= :max_hoehe';
    $params[':max_hoehe'] = floatval($_GET['maxHeight']);
  }

  if (isset($_GET['minAcc']) && is_numeric($_GET['minAcc'])) {
    $where[] = 'w.acceleration_max >= :min_acc';
    $params[':min_acc'] = floatval($_GET['minAcc']);
  }
  if (isset($_GET['maxAcc']) && is_numeric($_GET['maxAcc'])) {
    $where[] = 'w.acceleration_max <= :max_acc';
    $params[':max_acc'] = floatval($_GET['maxAcc']);
  }

  if (isset($_GET['minRot']) && is_numeric($_GET['minRot'])) {
    $where[] = 'w.rotation >= :min_rot';
    $params[':min_rot'] = floatval($_GET['minRot']);
  }
  if (isset($_GET['maxRot']) && is_numeric($_GET['maxRot'])) {
    $where[] = 'w.rotation <= :max_rot';
    $params[':max_rot'] = floatval($_GET['maxRot']);
  }

  header('Content-Type: text/csv; charset=utf-8');
  header('Content-Disposition: attachment; filename="smartdisc_throws.csv"');
  echo "\xEF\xBB\xBF"; // UTF-8 BOM so Excel opens the file correctly
  $out = fopen('php://output', 'w');
  fputcsv($out, ['id', 'scheibe_id', 'disc_name', 'player_id', 'player_name', 'rotation', 'hoehe', 'acceleration_max', 'erstellt_am'], ';');

  $sql = "SELECT w.id, w.scheibe_id,
    COALESCE(sd.name, w.scheibe_id) AS disc_name,
    w.player_id,
    TRIM(COALESCE(u.first_name, '') || ' ' || COALESCE(u.last_name, '')) AS player_name,
    w.rotation, w.hoehe, w.acceleration_max, w.erstellt_am
    FROM wurfe w
    LEFT JOIN scheiben sd ON sd.id = w.scheibe_id
    LEFT JOIN users u ON u.id = w.player_id
    WHERE " . implode(' AND ', $where) . " ORDER BY w.erstellt_am DESC";
  $stmt = $pdo->prepare($sql);
  $stmt->execute($params);
  while ($row = $stmt->fetch()) {
    // Format erstellt_am for Excel (avoid ######## and wrong date parsing)
    if (!empty($row['erstellt_am'])) {
      $ts = strtotime($row['erstellt_am']);
      $row['erstellt_am'] = $ts !== false ? date('Y-m-d H:i:s', $ts) : $row['erstellt_am'];
    }
    // Ensure numeric columns are plain numbers (no locale/date confusion)
    foreach (['rotation', 'hoehe', 'acceleration_max'] as $key) {
      if (isset($row[$key]) && $row[$key] !== null && $row[$key] !== '') {
        $row[$key] = is_numeric($row[$key]) ? (float) $row[$key] : $row[$key];
      }
    }
    fputcsv($out, $row, ';');
  }
  fclose($out);
  exit;
}

// GET /api/export.csv (legacy) - requires auth; trainers get all throws, players get own only
if ($path === "$prefix/export.csv" && $method === 'GET') {
  $token = require_auth();
  $user = get_user_by_token($token);
  if (!$user) {
    json_response(['error' => ['code' => 'UNAUTHORIZED', 'message' => 'Token ungültig']], 401);
    exit;
  }
  header('Content-Type: text/csv; charset=utf-8');
  header('Content-Disposition: attachment; filename="smartdisc_throws.csv"');
  echo "\xEF\xBB\xBF"; // UTF-8 BOM so Excel opens the file correctly
  $out = fopen('php://output', 'w');
  fputcsv($out, ['id', 'scheibe_id', 'disc_name', 'player_id', 'player_name', 'rotation', 'hoehe', 'acceleration_max', 'erstellt_am'], ';');
  if (($user['role'] ?? null) === 'trainer') {
    $stmt = $pdo->query("
      SELECT w.id, w.scheibe_id,
        COALESCE(sd.name, w.scheibe_id) AS disc_name,
        w.player_id,
        TRIM(COALESCE(u.first_name, '') || ' ' || COALESCE(u.last_name, '')) AS player_name,
        w.rotation, w.hoehe, w.acceleration_max, w.erstellt_am
      FROM wurfe w
      LEFT JOIN scheiben sd ON sd.id = w.scheibe_id
      LEFT JOIN users u ON u.id = w.player_id
      WHERE w.geloescht = 0
      ORDER BY w.erstellt_am DESC
    ");
  } else {
    $stmt = $pdo->prepare("
      SELECT w.id, w.scheibe_id,
        COALESCE(sd.name, w.scheibe_id) AS disc_name,
        w.player_id,
        TRIM(COALESCE(u.first_name, '') || ' ' || COALESCE(u.last_name, '')) AS player_name,
        w.rotation, w.hoehe, w.acceleration_max, w.erstellt_am
      FROM wurfe w
      LEFT JOIN scheiben sd ON sd.id = w.scheibe_id
      LEFT JOIN users u ON u.id = w.player_id
      WHERE w.geloescht = 0
        AND EXISTS (
          SELECT 1
          FROM disc_assignments da
          JOIN scheiben s ON s.id = da.disc_id
          WHERE da.player_id = :player_id
            AND (da.disc_id = w.scheibe_id OR s.name = w.scheibe_id)
        )
      ORDER BY w.erstellt_am DESC
    ");
    $stmt->execute([':player_id' => $user['id']]);
  }
  while ($row = $stmt->fetch()) {
    if (!empty($row['erstellt_am'])) {
      $ts = strtotime($row['erstellt_am']);
      $row['erstellt_am'] = $ts !== false ? date('Y-m-d H:i:s', $ts) : $row['erstellt_am'];
    }
    foreach (['rotation', 'hoehe', 'acceleration_max'] as $key) {
      if (isset($row[$key]) && $row[$key] !== null && $row[$key] !== '') {
        $row[$key] = is_numeric($row[$key]) ? (float) $row[$key] : $row[$key];
      }
    }
    fputcsv($out, $row, ';');
  }
  fclose($out);
  exit;
}
