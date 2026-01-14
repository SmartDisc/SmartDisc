<?php
require_once __DIR__ . '/db.php';
require_once __DIR__ . '/lib/http.php';
require_once __DIR__ . '/lib/auth.php';
require_once __DIR__ . '/lib/audit.php';

setup_cors();

$path = parse_request_path();
$method = get_request_method();
$prefix = '/api';

require_once __DIR__ . '/routes/misc.php';
require_once __DIR__ . '/routes/auth.php';
require_once __DIR__ . '/routes/wurfe.php';
require_once __DIR__ . '/routes/stats.php';
require_once __DIR__ . '/routes/revisionen.php';
require_once __DIR__ . '/routes/export.php';
require_once __DIR__ . '/routes/scheiben.php';
require_once __DIR__ . '/routes/admin.php';

json_response(['error'=>['code'=>'NOT_FOUND','message'=>'Pfad nicht gefunden']], 404);
