<?php
// Scheiben routes: GET list, POST create

// GET /api/scheiben - Liste aller Messsysteme/Scheiben
if ($path === "$prefix/scheiben" && $method === 'GET') {
  $stmt = $pdo->query("SELECT * FROM scheiben WHERE aktiv = 1 ORDER BY erstellt_am DESC");
  json_response(['items' => $stmt->fetchAll()]);
}

// POST /api/scheiben - Neues Messsystem registrieren
if ($path === "$prefix/scheiben" && $method === 'POST') {
  $input = get_json_input();
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

