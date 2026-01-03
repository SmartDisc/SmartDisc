<?php
// Wurfe routes: GET list, GET by id, POST create

// GET /api/wurfe - List all throws
if ($path === "$prefix/wurfe" && $method === 'GET') {
  $limit = isset($_GET['limit']) ? max(1, min(500, intval($_GET['limit']))) : 100;
  $where = ['geloescht = 0'];
  $params = [];

  if (!empty($_GET['scheibe_id'])) { $where[] = "scheibe_id = :scheibe_id"; $params[':scheibe_id'] = $_GET['scheibe_id']; }
  if (!empty($_GET['player_id'])) { $where[] = "player_id = :player_id"; $params[':player_id'] = $_GET['player_id']; }
  if (isset($_GET['from'])) { $where[] = "erstellt_am >= :from"; $params[':from'] = $_GET['from']; }
  if (isset($_GET['to'])) { $where[] = "erstellt_am <= :to"; $params[':to'] = $_GET['to']; }

  $sql = "SELECT * FROM wurfe WHERE " . implode(" AND ", $where) . " ORDER BY erstellt_am DESC LIMIT :limit";
  $stmt = $pdo->prepare($sql);
  foreach ($params as $k=>$v) { if($k!==':limit'){ $stmt->bindValue($k, $v); } }
  $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
  $stmt->execute();
  $items = $stmt->fetchAll();
  json_response(['items'=>$items, 'count'=>count($items)]);
}

// GET /api/wurfe/:id - Get single throw
if (preg_match("#^$prefix/wurfe/([^/]+)$#", $path, $matches) && $method === 'GET') {
  $wurfId = $matches[1];
  $stmt = $pdo->prepare("SELECT * FROM wurfe WHERE id = :id AND geloescht = 0");
  $stmt->execute([':id' => $wurfId]);
  $wurf = $stmt->fetch();
  if (!$wurf) {
    json_response(['error'=>['code'=>'NOT_FOUND','message'=>'Wurf nicht gefunden']], 404);
  }
  json_response($wurf);
}

// POST /api/wurfe - Create a throw
if ($path === "$prefix/wurfe" && $method === 'POST') {
  $input = get_json_input();
  if (empty($input['scheibe_id'])) {
    json_response(['error'=>['code'=>'VALIDATION_ERROR','message'=>'scheibe_id ist erforderlich']], 400);
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
      ':rotation'=>$input['rotation'] ?? null,
      ':hoehe'=>$input['hoehe'] ?? null,
      ':acceleration_max'=>$input['acceleration_max'] ?? null
    ]);
    log_audit('wurfe', $id, 'INSERT', null, $input);
    json_response(['id'=>$id, 'message'=>'Wurf erfolgreich erstellt'], 201);
  } catch (Exception $e) {
    json_response(['error'=>['code'=>'INSERT_FAILED','message'=>$e->getMessage()]], 500);
  }
}

