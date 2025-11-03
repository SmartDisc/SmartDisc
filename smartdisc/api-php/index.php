<?php
require_once __DIR__ . '/db.php';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }

$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$method = $_SERVER['REQUEST_METHOD'];
$prefix = '/api';

function json_response($data, $code=200){
  http_response_code($code);
  header('Content-Type: application/json; charset=utf-8');
  echo json_encode($data, JSON_UNESCAPED_SLASHES);
  exit;
}

if ($path === "$prefix/health") {
  json_response(['status'=>'ok','db'=>'up']);
}

// GET /api/wurfe
if ($path === "$prefix/wurfe" && $method === 'GET') {
  $limit = isset($_GET['limit']) ? max(1, min(500, intval($_GET['limit']))) : 100;
  $where = [];
  $params = [];

  if (!empty($_GET['scheibe_id'])) { $where[] = "scheibe_id = :scheibe_id"; $params[':scheibe_id'] = $_GET['scheibe_id']; }
  if (isset($_GET['min_geschwindigkeit'])) { $where[] = "geschwindigkeit >= :minv"; $params[':minv'] = $_GET['min_geschwindigkeit']; }
  if (isset($_GET['from'])) { $where[] = "erstellt_am >= :from"; $params[':from'] = $_GET['from']; }
  if (isset($_GET['to'])) { $where[] = "erstellt_am <= :to"; $params[':to'] = $_GET['to']; }

  $sql = "SELECT * FROM wurfe " . (count($where) ? "WHERE ".implode(" AND ", $where) : "") . " ORDER BY erstellt_am DESC LIMIT :limit";
  $stmt = $pdo->prepare($sql);
  foreach ($params as $k=>$v) { if($k!==':'){ $stmt->bindValue($k, $v); } }
  $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
  $stmt->execute();
  json_response(['items'=>$stmt->fetchAll()]);
}

// POST /api/wurfe
if ($path === "$prefix/wurfe" && $method === 'POST') {
  $input = json_decode(file_get_contents('php://input'), true) ?? [];
  if (empty($input['scheibe_id'])) {
    json_response(['error'=>['code'=>'VALIDATION_ERROR','message'=>'scheibe_id ist erforderlich']], 400);
  }
  $id = $input['id'] ?? ('wurf_' . bin2hex(random_bytes(6)));
  $stmt = $pdo->prepare("INSERT INTO wurfe (id, scheibe_id, entfernung, geschwindigkeit) VALUES (:id, :scheibe_id, :entfernung, :geschwindigkeit)");
  try {
    $stmt->execute([
      ':id'=>$id,
      ':scheibe_id'=>$input['scheibe_id'],
      ':entfernung'=>$input['entfernung'] ?? null,
      ':geschwindigkeit'=>$input['geschwindigkeit'] ?? null
    ]);
    json_response(['id'=>$id], 201);
  } catch (Exception $e) {
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

// POST /api/messungen
if ($path === "$prefix/messungen" && $method === 'POST') {
  $input = json_decode(file_get_contents('php://input'), true) ?? [];
  if (empty($input['wurf_id']) || empty($input['zeitpunkt'])) {
    json_response(['error'=>['code'=>'VALIDATION_ERROR','message'=>'wurf_id und zeitpunkt sind erforderlich']], 400);
  }
  $id = $input['id'] ?? ('m_' . bin2hex(random_bytes(6)));
  $stmt = $pdo->prepare("
    INSERT INTO messungen (id, wurf_id, zeitpunkt, beschleunigung_x, beschleunigung_y, beschleunigung_z, temperatur)
    VALUES (:id, :wurf_id, :zeitpunkt, :ax, :ay, :az, :temp)
  ");
  try {
    $stmt->execute([
      ':id'=>$id,
      ':wurf_id'=>$input['wurf_id'],
      ':zeitpunkt'=>$input['zeitpunkt'],
      ':ax'=>$input['beschleunigung_x'] ?? null,
      ':ay'=>$input['beschleunigung_y'] ?? null,
      ':az'=>$input['beschleunigung_z'] ?? null,
      ':temp'=>$input['temperatur'] ?? null
    ]);
    json_response(['id'=>$id], 201);
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

// GET /api/export.csv
if ($path === "$prefix/export.csv" && $method === 'GET') {
  header('Content-Type: text/csv; charset=utf-8');
  header('Content-Disposition: attachment; filename="smartdisc_throws.csv"');
  $out = fopen('php://output', 'w');
  fputcsv($out, ['id','scheibe_id','entfernung','geschwindigkeit','erstellt_am'], ';');
  $stmt = $pdo->query("SELECT id, scheibe_id, entfernung, geschwindigkeit, erstellt_am FROM wurfe ORDER BY erstellt_am DESC");
  while ($row = $stmt->fetch()) { fputcsv($out, $row, ';'); }
  fclose($out);
  exit;
}

json_response(['error'=>['code'=>'NOT_FOUND','message'=>'Pfad nicht gefunden']], 404);
