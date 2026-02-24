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
