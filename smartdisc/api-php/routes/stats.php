<?php
// Stats endpoint
if ($path === "$prefix/stats/summary" && $method === 'GET') {
  $token = get_bearer_token();
  $user = $token ? get_user_by_token($token) : null;
  $userRole = $user['role'] ?? null;
  $userId = $user['id'] ?? null;
  
  $scheibeId = $_GET['scheibe_id'] ?? null;
  $playerIdParam = $_GET['player_id'] ?? null;

  // Für Player: STRICT FILTERING - Nur Statistiken von zugeordneten Discs
  if ($userRole === 'player') {
    if (!$token || !$user || !$userId) {
      // Player ohne Auth = keine Daten
      json_response([
        'count' => 0,
        'rotationMax' => 0,
        'rotationAvg' => 0,
        'heightMax' => 0,
        'heightAvg' => 0,
        'accelerationMax' => 0,
        'accelerationAvg' => 0,
      ]);
      exit;
    }
    
    // WICHTIG: Player sieht ALLE Statistiken der zugeordneten Discs (unabhängig vom Werfer)
    $query = "
      SELECT
        COUNT(*) AS count,
        MAX(rotation) AS rotation_max,
        AVG(rotation) AS rotation_avg,
        MAX(hoehe) AS hoehe_max,
        AVG(hoehe) AS hoehe_avg,
        MAX(acceleration_max) AS acceleration_max,
        AVG(acceleration_max) AS acceleration_avg
      FROM wurfe
      WHERE geloescht = 0
        AND scheibe_id IN (SELECT disc_id FROM player_discs WHERE player_id = :current_player_id)
    ";
    $params = [':current_player_id' => $userId];
    
    // Filter nach spezifischer Disc (nur wenn zugeordnet)
    if ($scheibeId !== null && $scheibeId !== '') {
      // Prüfe ob Disc zugeordnet ist
      $checkStmt = $pdo->prepare("SELECT 1 FROM player_discs WHERE player_id = :player_id AND disc_id = :disc_id");
      $checkStmt->execute([':player_id' => $userId, ':disc_id' => $scheibeId]);
      if (!$checkStmt->fetch()) {
        // Disc nicht zugeordnet = keine Daten
        json_response([
          'count' => 0,
          'rotationMax' => 0,
          'rotationAvg' => 0,
          'heightMax' => 0,
          'heightAvg' => 0,
          'accelerationMax' => 0,
          'accelerationAvg' => 0,
        ]);
        exit;
      }
      $query .= " AND scheibe_id = :scheibe_id";
      $params[':scheibe_id'] = $scheibeId;
    }
  } else {
    // Trainer oder andere Rollen
    $query = "
      SELECT
        COUNT(*) AS count,
        MAX(rotation) AS rotation_max,
        AVG(rotation) AS rotation_avg,
        MAX(hoehe) AS hoehe_max,
        AVG(hoehe) AS hoehe_avg,
        MAX(acceleration_max) AS acceleration_max,
        AVG(acceleration_max) AS acceleration_avg
      FROM wurfe
      WHERE geloescht = 0
    ";
    $params = [];

    // Filter nach spezifischer Disc
    if ($scheibeId !== null && $scheibeId !== '') {
      $query .= " AND scheibe_id = :scheibe_id";
      $params[':scheibe_id'] = $scheibeId;
    }

    // Trainer kann explizit einen player_id Parameter übergeben (optional)
    // Wenn player_id gesetzt ist, zeigt Trainer nur Daten dieses Players
    // Aber Trainer sieht ALLE Discs dieses Players, nicht nur zugeordnete
    if ($playerIdParam !== null && $playerIdParam !== "" && $userRole === 'trainer') {
      $query .= " AND player_id = :player_id";
      $params[':player_id'] = $playerIdParam;
      // Trainer sieht ALLE Discs des Players, nicht nur zugeordnete
      // (keine zusätzliche Filterung nach player_discs)
    }
  }

  // Debug logging
  if (isset($_GET['debug']) || (isset($_SERVER['HTTP_X_DEBUG']) && $_SERVER['HTTP_X_DEBUG'] === '1')) {
    error_log("getStats query: $query");
    error_log("getStats params: " . json_encode($params));
    error_log("getStats userRole: $userRole, userId: " . ($userId ?? 'null'));
  }
  
  $stmt = $pdo->prepare($query);
  $stmt->execute($params);
  $stats = $stmt->fetch();

  $result = [
    'count' => intval($stats['count'] ?? 0),
    'rotationMax' => floatval($stats['rotation_max'] ?? 0),
    'rotationAvg' => floatval($stats['rotation_avg'] ?? 0),
    'heightMax' => floatval($stats['hoehe_max'] ?? 0),
    'heightAvg' => floatval($stats['hoehe_avg'] ?? 0),
    'accelerationMax' => floatval($stats['acceleration_max'] ?? 0),
    'accelerationAvg' => floatval($stats['acceleration_avg'] ?? 0),
  ];
  
  // Debug: Log result
  if (isset($_GET['debug']) || (isset($_SERVER['HTTP_X_DEBUG']) && $_SERVER['HTTP_X_DEBUG'] === '1')) {
    error_log("getStats result: " . json_encode($result));
  }
  
  json_response($result);
}
