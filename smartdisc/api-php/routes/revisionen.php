<?php
// Revisionen routes: GET by table/id, GET list

// GET /api/revisionen/:tabelle/:id - Revisionshistorie abrufen
if (preg_match("#^$prefix/revisionen/([^/]+)/([^/]+)$#", $path, $matches) && $method === 'GET') {
  $tabelle = $matches[1];
  $datensatzId = $matches[2];

  // Validierung der Tabelle
  if (!in_array($tabelle, ['wurfe', 'scheiben'])) {
    json_response(['error' => ['code' => 'VALIDATION_ERROR', 'message' => 'Ungültige Tabelle']], 400);
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

  if (!empty($_GET['tabelle'])) {
    $where[] = "tabelle = :tabelle";
    $params[':tabelle'] = $_GET['tabelle'];
  }
  if (!empty($_GET['datensatz_id'])) {
    $where[] = "datensatz_id = :datensatz_id";
    $params[':datensatz_id'] = $_GET['datensatz_id'];
  }
  if (!empty($_GET['operation'])) {
    $where[] = "operation = :operation";
    $params[':operation'] = $_GET['operation'];
  }
  if (!empty($_GET['from'])) {
    $where[] = "zeitpunkt >= :from";
    $params[':from'] = $_GET['from'];
  }
  if (!empty($_GET['to'])) {
    $where[] = "zeitpunkt <= :to";
    $params[':to'] = $_GET['to'];
  }

  $sql = "SELECT * FROM audit_log";
  if (count($where)) {
    $sql .= " WHERE " . implode(" AND ", $where);
  }
  $sql .= " ORDER BY zeitpunkt DESC LIMIT :limit";

  $stmt = $pdo->prepare($sql);
  foreach ($params as $k => $v) {
    $stmt->bindValue($k, $v);
  }
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
