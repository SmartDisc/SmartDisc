<?php
// Stats endpoint
if ($path === "$prefix/stats/summary" && $method === 'GET') {
  // Versuche, den aktuellen Benutzer über den Bearer-Token zu ermitteln
  $user = null;
  $token = get_bearer_token();
  if ($token) {
    $user = get_user_by_token($token);
  }

  // Spieler sehen nur Statistiken von Würfen ihrer zugeordneten Discs
  $whereClause = "geloescht = 0";
  $params = [];
  if ($user && ($user['role'] ?? null) === 'player') {
    $whereClause .= " AND EXISTS (SELECT 1 FROM disc_assignments da WHERE da.disc_id = wurfe.scheibe_id AND da.player_id = :current_player_id)";
    $params[':current_player_id'] = $user['id'];
  }

  $sql = "
    SELECT 
      COUNT(*) AS count,
      MAX(rotation) AS rotation_max,
      AVG(rotation) AS rotation_avg,
      MAX(hoehe) AS hoehe_max,
      AVG(hoehe) AS hoehe_avg,
      MAX(acceleration_max) AS acceleration_max,
      AVG(acceleration_max) AS acceleration_avg
    FROM wurfe 
    WHERE $whereClause
  ";
  
  $stmt = $pdo->prepare($sql);
  foreach ($params as $k => $v) {
    $stmt->bindValue($k, $v);
  }
  $stmt->execute();
  $stats = $stmt->fetch();
  
  json_response([
    'count' => intval($stats['count'] ?? 0),
    'rotationMax' => floatval($stats['rotation_max'] ?? 0),
    'rotationAvg' => floatval($stats['rotation_avg'] ?? 0),
    'heightMax' => floatval($stats['hoehe_max'] ?? 0),
    'heightAvg' => floatval($stats['hoehe_avg'] ?? 0),
    'accelerationMax' => floatval($stats['acceleration_max'] ?? 0),
    'accelerationAvg' => floatval($stats['acceleration_avg'] ?? 0),
  ]);
}

// GET /api/highscores - Ranking / leaderboard (best rotation, height, acceleration per user)
if ($path === "$prefix/highscores" && $method === 'GET') {
  $user = null;
  $token = get_bearer_token();
  if ($token) {
    $user = get_user_by_token($token);
  }

  $orderBy = $_GET['orderBy'] ?? 'rotation'; // rotation | height | acceleration
  $allowedOrder = ['rotation', 'height', 'acceleration'];
  if (!in_array($orderBy, $allowedOrder, true)) {
    $orderBy = 'rotation';
  }
  $column = $orderBy === 'rotation' ? 'best_rotation' : ($orderBy === 'height' ? 'best_hoehe' : 'best_acceleration_max');
  $limit = isset($_GET['limit']) ? max(1, min(100, intval($_GET['limit']))) : 20;

  $sql = "
    SELECT
      h.user_id,
      h.best_rotation,
      h.best_hoehe,
      h.best_acceleration_max,
      h.updated_at,
      u.first_name,
      u.last_name,
      u.email
    FROM highscores h
    JOIN users u ON u.id = h.user_id
    WHERE u.role = 'player'
  ORDER BY $column DESC
  LIMIT :limit
  ";
  $stmt = $pdo->prepare($sql);
  $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
  $stmt->execute();
  $items = $stmt->fetchAll();

  // Normalize keys for API (camelCase)
  $list = array_map(function ($row) {
    return [
      'userId' => $row['user_id'],
      'firstName' => $row['first_name'],
      'lastName' => $row['last_name'],
      'email' => $row['email'],
      'bestRotation' => $row['best_rotation'] !== null ? floatval($row['best_rotation']) : null,
      'bestHeight' => $row['best_hoehe'] !== null ? floatval($row['best_hoehe']) : null,
      'bestAccelerationMax' => $row['best_acceleration_max'] !== null ? floatval($row['best_acceleration_max']) : null,
      'updatedAt' => $row['updated_at'],
    ];
  }, $items);

  json_response(['items' => $list, 'count' => count($list), 'orderBy' => $orderBy]);
}

// GET /api/highscores/me - Current user's highscore (requires auth)
if ($path === "$prefix/highscores/me" && $method === 'GET') {
  $token = require_auth();
  $user = get_user_by_token($token);
  if (!$user) {
    json_response(['error' => ['code' => 'UNAUTHORIZED', 'message' => 'Token ungültig']], 401);
    exit;
  }

  $stmt = $pdo->prepare("SELECT * FROM highscores WHERE user_id = :user_id");
  $stmt->execute([':user_id' => $user['id']]);
  $row = $stmt->fetch();
  if (!$row) {
    json_response([
      'userId' => $user['id'],
      'bestRotation' => null,
      'bestHeight' => null,
      'bestAccelerationMax' => null,
      'updatedAt' => null,
    ]);
    exit;
  }

  json_response([
    'userId' => $row['user_id'],
    'bestRotation' => $row['best_rotation'] !== null ? floatval($row['best_rotation']) : null,
    'bestHeight' => $row['best_hoehe'] !== null ? floatval($row['best_hoehe']) : null,
    'bestAccelerationMax' => $row['best_acceleration_max'] !== null ? floatval($row['best_acceleration_max']) : null,
    'updatedAt' => $row['updated_at'],
  ]);
}
