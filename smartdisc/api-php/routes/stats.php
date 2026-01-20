<?php
// Stats endpoint
if ($path === "$prefix/stats/summary" && $method === 'GET') {
  // Optional: filter by disc (scheibe_id)
  $scheibeId = $_GET['scheibe_id'] ?? null;
  
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
  if ($scheibeId !== null && $scheibeId !== '') {
    $query .= " AND scheibe_id = :scheibe_id";
    $params[':scheibe_id'] = $scheibeId;
  }
  
  $stmt = $pdo->prepare($query);
  $stmt->execute($params);
  $stats = $stmt->fetch();
  
  json_response([
    'count'=> intval($stats['count'] ?? 0),
    'rotationMax'=> floatval($stats['rotation_max'] ?? 0),
    'rotationAvg'=> floatval($stats['rotation_avg'] ?? 0),
    'heightMax'=> floatval($stats['hoehe_max'] ?? 0),
    'heightAvg'=> floatval($stats['hoehe_avg'] ?? 0),
    'accelerationMax'=> floatval($stats['acceleration_max'] ?? 0),
    'accelerationAvg'=> floatval($stats['acceleration_avg'] ?? 0),
  ]);
}

