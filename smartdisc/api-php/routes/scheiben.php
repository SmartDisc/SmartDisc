<?php

// GET /api/scheiben - Liste aller Messsysteme/Scheiben
// Trainer/Coaches sehen alle aktiven Discs.
// Spieler sehen nur Discs, die ihnen zugeordnet wurden.
if ($path === "$prefix/scheiben" && $method === 'GET') {
  // Aktuellen Benutzer aus Token ermitteln (falls vorhanden)
  $user = null;
  $token = get_bearer_token();
  if ($token) {
    $user = get_user_by_token($token);
  }

  // Basis-Query: alle aktiven Discs
  $sql = "
    SELECT 
      s.id, 
      s.name, 
      s.modell, 
      s.seriennummer, 
      s.firmware_version, 
      s.kalibrierungsdatum, 
      s.erstellt_am 
    FROM scheiben s
    WHERE s.aktiv = 1
  ";
  $params = [];

  // Spieler: nur zugeordnete Discs anzeigen
  if ($user && ($user['role'] ?? null) === 'player') {
    $sql .= "
      AND EXISTS (
        SELECT 1
        FROM disc_assignments da
        WHERE da.disc_id = s.id
          AND da.player_id = :current_player_id
      )
    ";
    $params[':current_player_id'] = $user['id'];
  }

  $sql .= " ORDER BY s.erstellt_am DESC";

  $stmt = $pdo->prepare($sql);
  foreach ($params as $k => $v) {
    $stmt->bindValue($k, $v);
  }
  $stmt->execute();
  json_response(['items' => $stmt->fetchAll()]);
}

// POST /api/scheiben - Neues Messsystem registrieren
if ($path === "$prefix/scheiben" && $method === 'POST') {
  $input = get_json_input();
  if (empty($input['id'])) {
    json_response(['error' => ['code' => 'VALIDATION_ERROR', 'message' => 'id ist erforderlich']], 400);
    exit;
  }
  
  // Get current user
  $user = null;
  $token = get_bearer_token();
  if ($token) {
    $user = get_user_by_token($token);
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
    
    // If a player created this disc, automatically assign it to them
    if ($user && ($user['role'] ?? null) === 'player') {
      $assignStmt = $pdo->prepare("
        INSERT INTO disc_assignments (player_id, disc_id)
        VALUES (:player_id, :disc_id)
      ");
      $assignStmt->execute([
        ':player_id' => $user['id'],
        ':disc_id' => $input['id']
      ]);
    }
    
    json_response(['id' => $input['id'], 'message' => 'Messsystem erfolgreich registriert'], 201);
  } catch (Exception $e) {
    // Check for duplicate key error
    $errorMsg = $e->getMessage();
    if (strpos($errorMsg, 'UNIQUE constraint failed') !== false || strpos($errorMsg, 'Integrity constraint violation: 19') !== false) {
      json_response(['error' => ['code' => 'DUPLICATE_KEY', 'message' => 'Disc ID already exists. Please choose a different ID.']], 400);
    } else {
      json_response(['error' => ['code' => 'INSERT_FAILED', 'message' => $errorMsg]], 500);
    }
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
