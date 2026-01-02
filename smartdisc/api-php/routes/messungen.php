<?php
// Messungen routes: POST bulk, GET list, POST create

// POST /api/messungen/bulk - Bulk-Upload für Sensordaten
if ($path === "$prefix/messungen/bulk" && $method === 'POST') {
  $input = get_json_input();
  
  if (empty($input['wurf_id'])) {
    json_response(['error'=>['code'=>'VALIDATION_ERROR','message'=>'wurf_id ist erforderlich']], 400);
  }
  if (empty($input['messungen']) || !is_array($input['messungen']) || count($input['messungen']) === 0) {
    json_response(['error'=>['code'=>'VALIDATION_ERROR','message'=>'mindestens eine Messung ist erforderlich']], 400);
  }
  
  // Prüfen ob Wurf existiert
  $checkStmt = $pdo->prepare("SELECT id FROM wurfe WHERE id = :id AND geloescht = 0");
  $checkStmt->execute([':id' => $input['wurf_id']]);
  if (!$checkStmt->fetch()) {
    json_response(['error'=>['code'=>'VALIDATION_ERROR','message'=>'Wurf nicht gefunden']], 404);
  }
  
  $pdo->beginTransaction();
  try {
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
      $messungId = $messung['id'] ?? ('m_' . bin2hex(random_bytes(6)) . '_' . time() . '_' . $idx);
      $messungStmt->execute([
        ':id' => $messungId,
        ':wurf_id' => $input['wurf_id'],
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
    json_response([
      'wurf_id' => $input['wurf_id'],
      'messungen_eingefuegt' => $eingefuegt,
      'message' => 'Sensordaten erfolgreich gespeichert'
    ], 201);
  } catch (Exception $e) {
    $pdo->rollBack();
    json_response(['error'=>['code'=>'INSERT_FAILED','message'=>$e->getMessage()]], 500);
  }
}

// GET /api/messungen
if ($path === "$prefix/messungen" && $method === 'GET') {
  $limit = isset($_GET['limit']) ? max(1, min(2000, intval($_GET['limit']))) : 500;
  $where = []; $params = [];
  if (!empty($_GET['wurf_id'])) { $where[] = "wurf_id = :wurf_id"; $params[':wurf_id'] = $_GET['wurf_id']; }
  if (isset($_GET['from'])) { $where[] = "zeitpunkt >= :from"; $params[':from'] = $_GET['from']; }
  if (isset($_GET['to'])) { $where[] = "zeitpunkt <= :to"; $params[':to'] = $_GET['to']; }
  $sql = "SELECT * FROM messungen " . (count($where) ? "WHERE ".implode(" AND ", $where) : "") . " ORDER BY zeitpunkt DESC LIMIT :limit";
  $stmt = $pdo->prepare($sql);
  foreach ($params as $k=>$v) { $stmt->bindValue($k, $v); }
  $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
  $stmt->execute();
  json_response(['items'=>$stmt->fetchAll()]);
}

// POST /api/messungen - Einzelne Messung erstellen
if ($path === "$prefix/messungen" && $method === 'POST') {
  $input = get_json_input();
  if (empty($input['wurf_id']) || empty($input['zeitpunkt'])) {
    json_response(['error'=>['code'=>'VALIDATION_ERROR','message'=>'wurf_id und zeitpunkt sind erforderlich']], 400);
  }
  
  // Prüfen ob Wurf existiert
  $checkStmt = $pdo->prepare("SELECT id FROM wurfe WHERE id = :id AND geloescht = 0");
  $checkStmt->execute([':id' => $input['wurf_id']]);
  if (!$checkStmt->fetch()) {
    json_response(['error'=>['code'=>'VALIDATION_ERROR','message'=>'Wurf nicht gefunden']], 404);
  }
  
  // Sequenznummer ermitteln falls nicht vorhanden
  if (!isset($input['sequenz_nr'])) {
    $seqStmt = $pdo->prepare("SELECT COALESCE(MAX(sequenz_nr), -1) + 1 AS next_seq FROM messungen WHERE wurf_id = :wurf_id");
    $seqStmt->execute([':wurf_id' => $input['wurf_id']]);
    $input['sequenz_nr'] = $seqStmt->fetchColumn();
  }
  
  $id = $input['id'] ?? ('m_' . bin2hex(random_bytes(6)) . '_' . time());
  $stmt = $pdo->prepare("
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
  try {
    $stmt->execute([
      ':id'=>$id,
      ':wurf_id'=>$input['wurf_id'],
      ':zeitpunkt'=>$input['zeitpunkt'],
      ':sequenz_nr'=>$input['sequenz_nr'],
      ':ax'=>$input['beschleunigung_x'] ?? $input['ax'] ?? null,
      ':ay'=>$input['beschleunigung_y'] ?? $input['ay'] ?? null,
      ':az'=>$input['beschleunigung_z'] ?? $input['az'] ?? null,
      ':gx'=>$input['gyroskop_x'] ?? $input['gx'] ?? null,
      ':gy'=>$input['gyroskop_y'] ?? $input['gy'] ?? null,
      ':gz'=>$input['gyroskop_z'] ?? $input['gz'] ?? null,
      ':mx'=>$input['magnetometer_x'] ?? $input['mx'] ?? null,
      ':my'=>$input['magnetometer_y'] ?? $input['my'] ?? null,
      ':mz'=>$input['magnetometer_z'] ?? $input['mz'] ?? null,
      ':temp'=>$input['temperatur'] ?? null,
      ':druck'=>$input['luftdruck'] ?? null,
      ':gps_lat'=>$input['gps_breitengrad'] ?? $input['gps_lat'] ?? null,
      ':gps_lng'=>$input['gps_laengengrad'] ?? $input['gps_lng'] ?? null,
      ':gps_h'=>$input['gps_hoehe'] ?? $input['gps_h'] ?? null
    ]);
    json_response(['id'=>$id, 'sequenz_nr'=>$input['sequenz_nr']], 201);
  } catch (Exception $e) {
    json_response(['error'=>['code'=>'INSERT_FAILED','message'=>$e->getMessage()]], 500);
  }
}

