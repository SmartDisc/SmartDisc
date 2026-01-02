<?php
// Wurfe routes: GET list, GET by id, POST create, POST komplett

// GET /api/wurfe - Liste aller Würfe abrufen
if ($path === "$prefix/wurfe" && $method === 'GET') {
  $limit = isset($_GET['limit']) ? max(1, min(500, intval($_GET['limit']))) : 100;
  $where = ['geloescht = 0'];
  $params = [];

  if (!empty($_GET['scheibe_id'])) { $where[] = "scheibe_id = :scheibe_id"; $params[':scheibe_id'] = $_GET['scheibe_id']; }
  if (!empty($_GET['player_id'])) { $where[] = "player_id = :player_id"; $params[':player_id'] = $_GET['player_id']; }
  if (isset($_GET['min_geschwindigkeit'])) { $where[] = "geschwindigkeit >= :minv"; $params[':minv'] = $_GET['min_geschwindigkeit']; }
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

// GET /api/wurfe/:id - Einzelnen Wurf abrufen
if (preg_match("#^$prefix/wurfe/([^/]+)$#", $path, $matches) && $method === 'GET') {
  $wurfId = $matches[1];
  $stmt = $pdo->prepare("SELECT * FROM wurfe WHERE id = :id AND geloescht = 0");
  $stmt->execute([':id' => $wurfId]);
  $wurf = $stmt->fetch();
  if (!$wurf) {
    json_response(['error'=>['code'=>'NOT_FOUND','message'=>'Wurf nicht gefunden']], 404);
  }
  
  // Messungen hinzufügen falls gewünscht
  if (isset($_GET['include_messungen']) && $_GET['include_messungen'] === 'true') {
    $messStmt = $pdo->prepare("SELECT * FROM messungen WHERE wurf_id = :wurf_id ORDER BY sequenz_nr ASC");
    $messStmt->execute([':wurf_id' => $wurfId]);
    $wurf['messungen'] = $messStmt->fetchAll();
  }
  
  json_response($wurf);
}

// POST /api/wurfe - Einzelner Wurf erstellen
if ($path === "$prefix/wurfe" && $method === 'POST') {
  $input = get_json_input();
  if (empty($input['scheibe_id'])) {
    json_response(['error'=>['code'=>'VALIDATION_ERROR','message'=>'scheibe_id ist erforderlich']], 400);
  }
  $id = $input['id'] ?? ('wurf_' . bin2hex(random_bytes(8)) . '_' . time());
  $stmt = $pdo->prepare("
    INSERT INTO wurfe (
      id, scheibe_id, player_id, entfernung, geschwindigkeit, rotation, hoehe,
      start_zeitpunkt, end_zeitpunkt, dauer_sekunden, zusaetzliche_daten
    ) VALUES (
      :id, :scheibe_id, :player_id, :entfernung, :geschwindigkeit, :rotation, :hoehe,
      :start_zeitpunkt, :end_zeitpunkt, :dauer_sekunden, :zusaetzliche_daten
    )
  ");
  try {
    $stmt->execute([
      ':id'=>$id,
      ':scheibe_id'=>$input['scheibe_id'],
      ':player_id'=>$input['player_id'] ?? null,
      ':entfernung'=>$input['entfernung'] ?? null,
      ':geschwindigkeit'=>$input['geschwindigkeit'] ?? null,
      ':rotation'=>$input['rotation'] ?? null,
      ':hoehe'=>$input['hoehe'] ?? null,
      ':start_zeitpunkt'=>$input['start_zeitpunkt'] ?? date('c'),
      ':end_zeitpunkt'=>$input['end_zeitpunkt'] ?? null,
      ':dauer_sekunden'=>$input['dauer_sekunden'] ?? null,
      ':zusaetzliche_daten'=>$input['zusaetzliche_daten'] ? json_encode($input['zusaetzliche_daten']) : null
    ]);
    log_audit('wurfe', $id, 'INSERT', null, $input);
    json_response(['id'=>$id, 'message'=>'Wurf erfolgreich erstellt'], 201);
  } catch (Exception $e) {
    json_response(['error'=>['code'=>'INSERT_FAILED','message'=>$e->getMessage()]], 500);
  }
}

// POST /api/wurfe/komplett - Kompletter Wurf mit allen Sensordaten in einem Request
if ($path === "$prefix/wurfe/komplett" && $method === 'POST') {
  $input = get_json_input();
  
  // Validierung
  if (empty($input['scheibe_id'])) {
    json_response(['error'=>['code'=>'VALIDATION_ERROR','message'=>'scheibe_id ist erforderlich']], 400);
  }
  if (empty($input['messungen']) || !is_array($input['messungen']) || count($input['messungen']) === 0) {
    json_response(['error'=>['code'=>'VALIDATION_ERROR','message'=>'mindestens eine Messung ist erforderlich']], 400);
  }
  
  $pdo->beginTransaction();
  try {
    // Wurf erstellen
    $wurfId = $input['id'] ?? ('wurf_' . bin2hex(random_bytes(8)) . '_' . time());
    $stmt = $pdo->prepare("
      INSERT INTO wurfe (
        id, scheibe_id, player_id, entfernung, geschwindigkeit, rotation, hoehe,
        start_zeitpunkt, end_zeitpunkt, dauer_sekunden, zusaetzliche_daten
      ) VALUES (
        :id, :scheibe_id, :player_id, :entfernung, :geschwindigkeit, :rotation, :hoehe,
        :start_zeitpunkt, :end_zeitpunkt, :dauer_sekunden, :zusaetzliche_daten
      )
    ");
    $wurfData = [
      ':id' => $wurfId,
      ':scheibe_id' => $input['scheibe_id'],
      ':player_id' => $input['player_id'] ?? null,
      ':entfernung' => $input['entfernung'] ?? null,
      ':geschwindigkeit' => $input['geschwindigkeit'] ?? null,
      ':rotation' => $input['rotation'] ?? null,
      ':hoehe' => $input['hoehe'] ?? null,
      ':start_zeitpunkt' => $input['start_zeitpunkt'] ?? ($input['messungen'][0]['zeitpunkt'] ?? date('c')),
      ':end_zeitpunkt' => $input['end_zeitpunkt'] ?? ($input['messungen'][count($input['messungen'])-1]['zeitpunkt'] ?? null),
      ':dauer_sekunden' => $input['dauer_sekunden'] ?? null,
      ':zusaetzliche_daten' => isset($input['zusaetzliche_daten']) ? json_encode($input['zusaetzliche_daten']) : null
    ];
    $stmt->execute($wurfData);
    
    // Messungen in Bulk einfügen
    $messungStmt = $pdo->prepare("
      INSERT INTO messungen (
        id, wurf_id, zeitpunkt, sequenz_nr,
        beschleunigung_x, beschleunigung_y, beschleunigung_z,
        gyroskop_x, gyroskop_y, gyroskop_z,
        magnetometer_x, magnetometer_y, magnetometer_z,
        temperatur, luftdruck,
        gps_breitengrad, gps_laengengrad, gps_hoehe
      ) VALUES (
        :id, :wurf_id, :zeitpunkt, :sequenz_nr,
        :ax, :ay, :az,
        :gx, :gy, :gz,
        :mx, :my, :mz,
        :temp, :druck,
        :gps_lat, :gps_lng, :gps_h
      )
    ");
    
    $eingefuegt = 0;
    foreach ($input['messungen'] as $idx => $messung) {
      if (empty($messung['zeitpunkt'])) {
        throw new Exception("Messung bei Index $idx: zeitpunkt ist erforderlich");
      }
      $messungId = $messung['id'] ?? ('m_' . bin2hex(random_bytes(6)) . '_' . $idx);
      $messungStmt->execute([
        ':id' => $messungId,
        ':wurf_id' => $wurfId,
        ':zeitpunkt' => $messung['zeitpunkt'],
        ':sequenz_nr' => $messung['sequenz_nr'] ?? $idx,
        ':ax' => $messung['beschleunigung_x'] ?? $messung['ax'] ?? null,
        ':ay' => $messung['beschleunigung_y'] ?? $messung['ay'] ?? null,
        ':az' => $messung['beschleunigung_z'] ?? $messung['az'] ?? null,
        ':gx' => $messung['gyroskop_x'] ?? $messung['gx'] ?? null,
        ':gy' => $messung['gyroskop_y'] ?? $messung['gy'] ?? null,
        ':gz' => $messung['gyroskop_z'] ?? $messung['gz'] ?? null,
        ':mx' => $messung['magnetometer_x'] ?? $messung['mx'] ?? null,
        ':my' => $messung['magnetometer_y'] ?? $messung['my'] ?? null,
        ':mz' => $messung['magnetometer_z'] ?? $messung['mz'] ?? null,
        ':temp' => $messung['temperatur'] ?? null,
        ':druck' => $messung['luftdruck'] ?? null,
        ':gps_lat' => $messung['gps_breitengrad'] ?? $messung['gps_lat'] ?? null,
        ':gps_lng' => $messung['gps_laengengrad'] ?? $messung['gps_lng'] ?? null,
        ':gps_h' => $messung['gps_hoehe'] ?? $messung['gps_h'] ?? null
      ]);
      $eingefuegt++;
    }
    
    $pdo->commit();
    log_audit('wurfe', $wurfId, 'INSERT_COMPLETE', null, ['wurf_id' => $wurfId, 'messungen_anzahl' => $eingefuegt]);
    json_response([
      'id' => $wurfId,
      'messungen_eingefuegt' => $eingefuegt,
      'message' => 'Wurf mit allen Sensordaten erfolgreich gespeichert'
    ], 201);
  } catch (Exception $e) {
    $pdo->rollBack();
    json_response(['error'=>['code'=>'INSERT_FAILED','message'=>$e->getMessage()]], 500);
  }
}

