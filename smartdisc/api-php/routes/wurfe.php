<?php
// Throw routes

// List throws
if ($path === "$prefix/wurfe" && $method === 'GET') {
  $limit = isset($_GET['limit']) ? max(1, min(500, intval($_GET['limit']))) : 100;
  $where = ['geloescht = 0'];
  $params = [];

  if (!empty($_GET['scheibe_id'])) { $where[] = "scheibe_id = :scheibe_id"; $params[':scheibe_id'] = $_GET['scheibe_id']; }
  if (!empty($_GET['player_id'])) { $where[] = "player_id = :player_id"; $params[':player_id'] = $_GET['player_id']; }
  if (isset($_GET['from'])) { $where[] = "erstellt_am >= :from"; $params[':from'] = $_GET['from']; }
  if (isset($_GET['to'])) { $where[] = "erstellt_am <= :to"; $params[':to'] = $_GET['to']; }

  $sql = "SELECT id, scheibe_id, player_id, rotation, hoehe, acceleration_max, erstellt_am FROM wurfe WHERE " . implode(" AND ", $where) . " ORDER BY erstellt_am DESC LIMIT :limit";
  $stmt = $pdo->prepare($sql);
  foreach ($params as $k=>$v) { if($k!==':limit'){ $stmt->bindValue($k, $v); } }
  $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
  $stmt->execute();
  $items = $stmt->fetchAll();
  json_response(['items'=>$items, 'count'=>count($items)]);
}

// Get single throw
if (preg_match("#^$prefix/wurfe/([^/]+)$#", $path, $matches) && $method === 'GET') {
  $wurfId = $matches[1];
  $stmt = $pdo->prepare("SELECT id, scheibe_id, player_id, rotation, hoehe, acceleration_max, erstellt_am FROM wurfe WHERE id = :id AND geloescht = 0");
  $stmt->execute([':id' => $wurfId]);
  $wurf = $stmt->fetch();
  if (!$wurf) {
    json_response(['error'=>['code'=>'NOT_FOUND','message'=>'Wurf nicht gefunden']], 404);
    exit;
  }
  json_response($wurf);
}

// Create throw
if ($path === "$prefix/wurfe" && $method === 'POST') {
  $input = get_json_input();
  
  // Check required fields
  if (empty($input['scheibe_id'])) {
    json_response(['error'=>['code'=>'VALIDATION_ERROR','message'=>'scheibe_id ist erforderlich']], 400);
    exit;
  }
  
  // Need at least one measurement value
  $hasRotation = isset($input['rotation']) && is_numeric($input['rotation']);
  $hasHeight = isset($input['hoehe']) && is_numeric($input['hoehe']);
  $hasAccel = isset($input['acceleration_max']) && is_numeric($input['acceleration_max']);
  
  if (!$hasRotation && !$hasHeight && !$hasAccel) {
    json_response(['error'=>['code'=>'VALIDATION_ERROR','message'=>'Mindestens einer der Werte (rotation, hoehe, acceleration_max) muss angegeben werden']], 400);
    exit;
  }
  
  // Convert to numbers
  if ($hasRotation) {
    $input['rotation'] = floatval($input['rotation']);
  }
  if ($hasHeight) {
    $input['hoehe'] = floatval($input['hoehe']);
  }
  if ($hasAccel) {
    $input['acceleration_max'] = floatval($input['acceleration_max']);
  }
  
  $id = $input['id'] ?? ('wurf_' . bin2hex(random_bytes(8)) . '_' . time());
  $stmt = $pdo->prepare("
    INSERT INTO wurfe (
      id, scheibe_id, player_id, rotation, hoehe, acceleration_max
    ) VALUES (
      :id, :scheibe_id, :player_id, :rotation, :hoehe, :acceleration_max
    )
  ");
  try {
    $stmt->execute([
      ':id'=>$id,
      ':scheibe_id'=>$input['scheibe_id'],
      ':player_id'=>$input['player_id'] ?? null,
      ':rotation'=>$hasRotation ? $input['rotation'] : null,
      ':hoehe'=>$hasHeight ? $input['hoehe'] : null,
      ':acceleration_max'=>$hasAccel ? $input['acceleration_max'] : null
    ]);
    log_audit('wurfe', $id, 'INSERT', null, $input);
    
    // Check for new highscore records
    $isNewRecord = false;
    $recordType = null;
    $playerId = $input['player_id'] ?? null;
    
    if ($playerId) {
      // Get current highscores
      $hsStmt = $pdo->prepare("SELECT * FROM highscores WHERE user_id = :user_id");
      $hsStmt->execute([':user_id' => $playerId]);
      $current = $hsStmt->fetch();
      
      $newRotation = $hasRotation && ($current === false || $current['best_rotation'] === null || $input['rotation'] > $current['best_rotation']);
      $newHoehe = $hasHeight && ($current === false || $current['best_hoehe'] === null || $input['hoehe'] > $current['best_hoehe']);
      $newAccel = $hasAccel && ($current === false || $current['best_acceleration_max'] === null || $input['acceleration_max'] > $current['best_acceleration_max']);
      
      if ($newRotation || $newHoehe || $newAccel) {
        $isNewRecord = true;
        if ($newRotation) $recordType = 'rotation';
        elseif ($newHoehe) $recordType = 'hoehe';
        elseif ($newAccel) $recordType = 'acceleration';
        
        // Update highscores
        if ($current === false) {
          $insertStmt = $pdo->prepare("
            INSERT INTO highscores (user_id, best_rotation, best_hoehe, best_acceleration_max, updated_at)
            VALUES (:user_id, :rotation, :hoehe, :accel, strftime('%Y-%m-%dT%H:%M:%fZ','now'))
          ");
          $insertStmt->execute([
            ':user_id' => $playerId,
            ':rotation' => $hasRotation ? $input['rotation'] : null,
            ':hoehe' => $hasHeight ? $input['hoehe'] : null,
            ':accel' => $hasAccel ? $input['acceleration_max'] : null
          ]);
        } else {
          $newRotation = $newRotation ? ($hasRotation ? $input['rotation'] : $current['best_rotation']) : $current['best_rotation'];
          $newHoehe = $newHoehe ? ($hasHeight ? $input['hoehe'] : $current['best_hoehe']) : $current['best_hoehe'];
          $newAccel = $newAccel ? ($hasAccel ? $input['acceleration_max'] : $current['best_acceleration_max']) : $current['best_acceleration_max'];
          
          $updateStmt = $pdo->prepare("
            UPDATE highscores SET
              best_rotation = :rotation,
              best_hoehe = :hoehe,
              best_acceleration_max = :accel,
              updated_at = strftime('%Y-%m-%dT%H:%M:%fZ','now')
            WHERE user_id = :user_id
          ");
          $updateStmt->execute([
            ':user_id' => $playerId,
            ':rotation' => $newRotation,
            ':hoehe' => $newHoehe,
            ':accel' => $newAccel
          ]);
        }
      }
    }
    
    $response = ['id'=>$id, 'message'=>'Wurf erfolgreich erstellt'];
    if ($isNewRecord) {
      $response['is_new_record'] = true;
      $response['record_type'] = $recordType;
    }
    json_response($response, 201);
  } catch (Exception $e) {
    json_response(['error'=>['code'=>'INSERT_FAILED','message'=>$e->getMessage()]], 500);
  }
}

