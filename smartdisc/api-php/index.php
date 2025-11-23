<?php
require_once __DIR__ . '/db.php';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }

$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$method = $_SERVER['REQUEST_METHOD'];
$prefix = '/api';

function json_response($data, $code=200){
  http_response_code($code);
  header('Content-Type: application/json; charset=utf-8');
  echo json_encode($data, JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT);
  exit;
}

function get_client_ip() {
  return $_SERVER['HTTP_X_FORWARDED_FOR'] ?? $_SERVER['HTTP_X_REAL_IP'] ?? $_SERVER['REMOTE_ADDR'] ?? 'unknown';
}

function log_audit($tabelle, $datensatz_id, $operation, $alte_daten = null, $neue_daten = null) {
  global $pdo;
  $stmt = $pdo->prepare("
    INSERT INTO audit_log (tabelle, datensatz_id, operation, alte_daten, neue_daten, ip_adresse, user_agent, zeitpunkt)
    VALUES (:tabelle, :datensatz_id, :operation, :alte_daten, :neue_daten, :ip, :ua, strftime('%Y-%m-%dT%H:%M:%fZ','now'))
  ");
  $stmt->execute([
    ':tabelle' => $tabelle,
    ':datensatz_id' => $datensatz_id,
    ':operation' => $operation,
    ':alte_daten' => $alte_daten ? json_encode($alte_daten) : null,
    ':neue_daten' => $neue_daten ? json_encode($neue_daten) : null,
    ':ip' => get_client_ip(),
    ':ua' => $_SERVER['HTTP_USER_AGENT'] ?? null
  ]);
}

if ($path === "$prefix/health") {
  json_response(['status'=>'ok','db'=>'up','timestamp'=>date('c')]);
}

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
  $input = json_decode(file_get_contents('php://input'), true) ?? [];
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

// POST /api/wurfe/komplett - Kompletter Wurf mit allen Sensordaten in einem Request (Ziel-H 12)
if ($path === "$prefix/wurfe/komplett" && $method === 'POST') {
  $input = json_decode(file_get_contents('php://input'), true) ?? [];
  
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

// POST /api/messungen/bulk - Bulk-Upload für Sensordaten (Ziel-H 12)
if ($path === "$prefix/messungen/bulk" && $method === 'POST') {
  $input = json_decode(file_get_contents('php://input'), true) ?? [];
  
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
  $input = json_decode(file_get_contents('php://input'), true) ?? [];
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

// GET /api/stats/summary
if ($path === "$prefix/stats/summary" && $method === 'GET') {
  $count = $pdo->query("SELECT COUNT(*) AS c FROM messungen")->fetchColumn();
  $rps = $pdo->query("SELECT MAX(geschwindigkeit) AS vmax, AVG(geschwindigkeit) AS vavg FROM wurfe")->fetch();
  $height = $pdo->query("SELECT MAX(entfernung) AS dmax, AVG(entfernung) AS davg FROM wurfe")->fetch();
  json_response([
    'messungenCount'=> intval($count),
    'geschwindigkeitMax'=> floatval($rps['vmax'] ?? 0),
    'geschwindigkeitAvg'=> floatval($rps['vavg'] ?? 0),
    'entfernungMax'=> floatval($height['dmax'] ?? 0),
    'entfernungAvg'=> floatval($height['davg'] ?? 0),
  ]);
}

// GET /api/revisionen/:tabelle/:id - Revisionshistorie abrufen (Ziel-H 13)
if (preg_match("#^$prefix/revisionen/([^/]+)/([^/]+)$#", $path, $matches) && $method === 'GET') {
  $tabelle = $matches[1];
  $datensatzId = $matches[2];
  
  // Validierung der Tabelle
  if (!in_array($tabelle, ['wurfe', 'messungen', 'scheiben'])) {
    json_response(['error'=>['code'=>'VALIDATION_ERROR','message'=>'Ungültige Tabelle']], 400);
  }
  
  $stmt = $pdo->prepare("
    SELECT * FROM audit_log 
    WHERE tabelle = :tabelle AND datensatz_id = :id 
    ORDER BY zeitpunkt DESC
  ");
  $stmt->execute([':tabelle' => $tabelle, ':id' => $datensatzId]);
  $revisionen = $stmt->fetchAll();
  
  // JSON-Daten dekodieren
  foreach ($revisionen as &$rev) {
    if ($rev['alte_daten']) $rev['alte_daten'] = json_decode($rev['alte_daten'], true);
    if ($rev['neue_daten']) $rev['neue_daten'] = json_decode($rev['neue_daten'], true);
  }
  
  json_response(['items' => $revisionen, 'count' => count($revisionen)]);
}

// GET /api/revisionen - Alle Revisionen mit Filtern
if ($path === "$prefix/revisionen" && $method === 'GET') {
  $limit = isset($_GET['limit']) ? max(1, min(1000, intval($_GET['limit']))) : 100;
  $where = [];
  $params = [];
  
  if (!empty($_GET['tabelle'])) { $where[] = "tabelle = :tabelle"; $params[':tabelle'] = $_GET['tabelle']; }
  if (!empty($_GET['datensatz_id'])) { $where[] = "datensatz_id = :datensatz_id"; $params[':datensatz_id'] = $_GET['datensatz_id']; }
  if (!empty($_GET['operation'])) { $where[] = "operation = :operation"; $params[':operation'] = $_GET['operation']; }
  if (!empty($_GET['from'])) { $where[] = "zeitpunkt >= :from"; $params[':from'] = $_GET['from']; }
  if (!empty($_GET['to'])) { $where[] = "zeitpunkt <= :to"; $params[':to'] = $_GET['to']; }
  
  $sql = "SELECT * FROM audit_log";
  if (count($where)) {
    $sql .= " WHERE " . implode(" AND ", $where);
  }
  $sql .= " ORDER BY zeitpunkt DESC LIMIT :limit";
  
  $stmt = $pdo->prepare($sql);
  foreach ($params as $k=>$v) { $stmt->bindValue($k, $v); }
  $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
  $stmt->execute();
  $revisionen = $stmt->fetchAll();
  
  // JSON-Daten dekodieren
  foreach ($revisionen as &$rev) {
    if ($rev['alte_daten']) $rev['alte_daten'] = json_decode($rev['alte_daten'], true);
    if ($rev['neue_daten']) $rev['neue_daten'] = json_decode($rev['neue_daten'], true);
  }
  
  json_response(['items' => $revisionen, 'count' => count($revisionen)]);
}

// GET /api/export.csv
if ($path === "$prefix/export.csv" && $method === 'GET') {
  header('Content-Type: text/csv; charset=utf-8');
  header('Content-Disposition: attachment; filename="smartdisc_throws.csv"');
  $out = fopen('php://output', 'w');
  fputcsv($out, ['id','scheibe_id','player_id','entfernung','geschwindigkeit','rotation','hoehe','erstellt_am'], ';');
  $stmt = $pdo->query("SELECT id, scheibe_id, player_id, entfernung, geschwindigkeit, rotation, hoehe, erstellt_am FROM wurfe WHERE geloescht = 0 ORDER BY erstellt_am DESC");
  while ($row = $stmt->fetch()) { fputcsv($out, $row, ';'); }
  fclose($out);
  exit;
}

// GET /api/scheiben - Liste aller Messsysteme/Scheiben
if ($path === "$prefix/scheiben" && $method === 'GET') {
  $stmt = $pdo->query("SELECT * FROM scheiben WHERE aktiv = 1 ORDER BY erstellt_am DESC");
  json_response(['items' => $stmt->fetchAll()]);
}

// POST /api/scheiben - Neues Messsystem registrieren
if ($path === "$prefix/scheiben" && $method === 'POST') {
  $input = json_decode(file_get_contents('php://input'), true) ?? [];
  if (empty($input['id'])) {
    json_response(['error'=>['code'=>'VALIDATION_ERROR','message'=>'id ist erforderlich']], 400);
  }
  $stmt = $pdo->prepare("
    INSERT INTO scheiben (id, name, modell, seriennummer, firmware_version, kalibrierungsdatum)
    VALUES (:id, :name, :modell, :seriennummer, :firmware_version, :kalibrierungsdatum)
  ");
  try {
    $stmt->execute([
      ':id' => $input['id'],
      ':name' => $input['name'] ?? null,
      ':modell' => $input['modell'] ?? null,
      ':seriennummer' => $input['seriennummer'] ?? null,
      ':firmware_version' => $input['firmware_version'] ?? null,
      ':kalibrierungsdatum' => $input['kalibrierungsdatum'] ?? null
    ]);
    log_audit('scheiben', $input['id'], 'INSERT', null, $input);
    json_response(['id' => $input['id'], 'message' => 'Messsystem erfolgreich registriert'], 201);
  } catch (Exception $e) {
    json_response(['error'=>['code'=>'INSERT_FAILED','message'=>$e->getMessage()]], 500);
  }
}

json_response(['error'=>['code'=>'NOT_FOUND','message'=>'Pfad nicht gefunden']], 404);
