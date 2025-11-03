<?php
$DB_FILE = __DIR__ . '/data/smartdisc.sqlite';
if (!is_dir(__DIR__ . '/data')) { mkdir(__DIR__ . '/data', 0777, true); }
try {
  $pdo = new PDO('sqlite:' . $DB_FILE, null, null, [
    PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
  ]);
} catch (Exception $e) {
  http_response_code(500);
  header('Content-Type: application/json');
  echo json_encode(['error' => ['code'=>'DB_CONNECT_ERROR','message'=>$e->getMessage()]]);
  exit;
}
$pdo->exec("
CREATE TABLE IF NOT EXISTS wurfe (
    id TEXT PRIMARY KEY,
    scheibe_id TEXT NOT NULL,
    entfernung REAL,
    geschwindigkeit REAL,
    erstellt_am TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE TABLE IF NOT EXISTS messungen (
    id TEXT PRIMARY KEY,
    wurf_id TEXT NOT NULL,
    zeitpunkt TEXT NOT NULL,
    beschleunigung_x REAL,
    beschleunigung_y REAL,
    beschleunigung_z REAL,
    temperatur REAL
);");
