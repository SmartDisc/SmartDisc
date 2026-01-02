<?php
require_once __DIR__ . '/db.php';
require_once __DIR__ . '/lib/http.php';
require_once __DIR__ . '/lib/auth.php';
require_once __DIR__ . '/lib/audit.php';

// CORS und OPTIONS Handling - muss als erstes kommen
setup_cors();

// Request-Parsing
$path = parse_request_path();
$method = get_request_method();
$prefix = '/api';

// Route-Dateien in gleicher Reihenfolge wie vorher laden
require_once __DIR__ . '/routes/misc.php';      // health, ping
require_once __DIR__ . '/routes/auth.php';      // register, login, me, logout
require_once __DIR__ . '/routes/wurfe.php';     // GET list, GET by id, POST create, POST komplett
require_once __DIR__ . '/routes/messungen.php'; // POST bulk, GET list, POST create
require_once __DIR__ . '/routes/stats.php';     // GET summary
require_once __DIR__ . '/routes/revisionen.php'; // GET by table/id, GET list
require_once __DIR__ . '/routes/export.php';    // GET CSV
require_once __DIR__ . '/routes/scheiben.php';  // GET list, POST create

// NOT_FOUND - muss am Ende stehen
json_response(['error'=>['code'=>'NOT_FOUND','message'=>'Pfad nicht gefunden']], 404);
