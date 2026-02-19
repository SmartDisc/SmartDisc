<?php

// GET /api/scheiben - Liste aller Messsysteme/Scheiben
if ($path === "$prefix/scheiben" && $method === 'GET') {
  $stmt = $pdo->query("SELECT id, name, modell, seriennummer, firmware_version, kalibrierungsdatum, erstellt_am FROM scheiben WHERE aktiv = 1 ORDER BY erstellt_am DESC");
  json_response(['items' => $stmt->fetchAll()]);
}

// POST /api/scheiben - Neues Messsystem registrieren
if ($path === "$prefix/scheiben" && $method === 'POST') {
  $input = get_json_input();
  if (empty($input['id'])) {
    json_response(['error' => ['code' => 'VALIDATION_ERROR', 'message' => 'id ist erforderlich']], 400);
    exit;
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
    json_response(['error' => ['code' => 'INSERT_FAILED', 'message' => $e->getMessage()]], 500);
    exit;
  }
}

if (preg_match("~^$prefix/scheiben/([^/]+)$~", $path, $m) && $method === 'DELETE') {
  $id = urldecode($m[1]);
  $stmt = $pdo->prepare("UPDATE scheiben SET aktiv = 0 WHERE id = :id");
  try {
    $stmt->execute([':id' => $id]);
    if ($stmt->rowCount() === 0) {
      json_response(['error' => ['code' => 'NOT_FOUND', 'message' => 'Messsystem nicht gefunden']], 404);
      exit;
    }
    log_audit('scheiben', $id, 'DELETE', null, ['aktiv' => 0]);
    json_response(['message' => 'Messsystem deaktiviert'], 200);
  } catch (Exception $e) {
    json_response(['error' => ['code' => 'DELETE_FAILED', 'message' => $e->getMessage()]], 500);
    exit;
  }
}
