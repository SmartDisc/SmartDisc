<?php
// Stats routes: GET summary

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

