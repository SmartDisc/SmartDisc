<?php
// Trainer routes: disc assignment to players

// GET /api/trainer/players - Liste aller Spieler
if ($path === "$prefix/trainer/players" && $method === 'GET') {
  $token = require_auth();
  $user = get_user_by_token($token);
  
  if (!$user || ($user['role'] ?? null) !== 'trainer') {
    json_response(['error' => ['code' => 'FORBIDDEN', 'message' => 'Nur Trainer']], 403);
  }

  $stmt = $pdo->query("SELECT id, first_name, last_name, email FROM users WHERE role = 'player' ORDER BY last_name, first_name");
  json_response(['items' => $stmt->fetchAll()]);
}

// GET /api/trainer/players/{id}/discs - Discs eines Spielers
if (preg_match("#^$prefix/trainer/players/([^/]+)/discs$#", $path, $matches) && $method === 'GET') {
  $token = require_auth();
  $user = get_user_by_token($token);
  
  if (!$user || ($user['role'] ?? null) !== 'trainer') {
    json_response(['error' => ['code' => 'FORBIDDEN', 'message' => 'Nur Trainer']], 403);
  }
  $playerId = urldecode($matches[1]);

  $stmt = $pdo->prepare("
    SELECT s.id, s.name, s.modell, s.seriennummer
    FROM scheiben s
    INNER JOIN player_discs pd ON s.id = pd.disc_id
    WHERE pd.player_id = :player_id AND s.aktiv = 1
    ORDER BY s.name
  ");
  $stmt->execute([':player_id' => $playerId]);
  json_response(['items' => $stmt->fetchAll()]);
}

// POST /api/trainer/players/{id}/discs - Disc zuordnen
if (preg_match("#^$prefix/trainer/players/([^/]+)/discs$#", $path, $matches) && $method === 'POST') {
  $token = require_auth();
  $user = get_user_by_token($token);
  
  if (!$user || ($user['role'] ?? null) !== 'trainer') {
    json_response(['error' => ['code' => 'FORBIDDEN', 'message' => 'Nur Trainer']], 403);
    exit;
  }
  $playerId = urldecode($matches[1]);
  $input = get_json_input();
  $discId = $input['disc_id'] ?? null;

  if (empty($discId)) {
    json_response(['error' => ['code' => 'VALIDATION_ERROR', 'message' => 'disc_id ist erforderlich']], 400);
    exit;
  }

  // Prüfe ob Disc existiert und aktiv ist
  $discCheck = $pdo->prepare("SELECT id FROM scheiben WHERE id = :disc_id AND aktiv = 1");
  $discCheck->execute([':disc_id' => $discId]);
  if (!$discCheck->fetch()) {
    json_response(['error' => ['code' => 'NOT_FOUND', 'message' => 'Disc nicht gefunden oder inaktiv']], 404);
    exit;
  }

  // Prüfe ob Zuordnung bereits existiert
  $checkStmt = $pdo->prepare("SELECT 1 FROM player_discs WHERE player_id = :player_id AND disc_id = :disc_id");
  $checkStmt->execute([':player_id' => $playerId, ':disc_id' => $discId]);
  if ($checkStmt->fetch()) {
    json_response(['error' => ['code' => 'ALREADY_ASSIGNED', 'message' => 'Disc ist diesem Spieler bereits zugeordnet']], 409);
    exit;
  }

  try {
    // Explicitly set assigned_at to ensure NOT NULL constraint is satisfied
    $stmt = $pdo->prepare("
      INSERT INTO player_discs (player_id, disc_id, assigned_at) 
      VALUES (:player_id, :disc_id, strftime('%Y-%m-%dT%H:%M:%fZ','now'))
    ");
    $stmt->execute([':player_id' => $playerId, ':disc_id' => $discId]);
    log_audit('player_discs', "$playerId-$discId", 'INSERT', null, ['player_id' => $playerId, 'disc_id' => $discId]);
    json_response(['message' => 'Disc erfolgreich zugeordnet'], 201);
  } catch (PDOException $e) {
    // Check for unique constraint violation (duplicate entry)
    if ($e->getCode() == '23000' || strpos($e->getMessage(), 'UNIQUE constraint') !== false) {
      json_response(['error' => ['code' => 'ALREADY_ASSIGNED', 'message' => 'Disc ist diesem Spieler bereits zugeordnet']], 409);
    } else {
      json_response(['error' => ['code' => 'ASSIGNMENT_FAILED', 'message' => $e->getMessage()]], 500);
    }
  }
}

// DELETE /api/trainer/players/{id}/discs/{discId} - Zuordnung entfernen
if (preg_match("#^$prefix/trainer/players/([^/]+)/discs/([^/]+)$#", $path, $matches) && $method === 'DELETE') {
  $token = require_auth();
  $user = get_user_by_token($token);
  
  if (!$user || ($user['role'] ?? null) !== 'trainer') {
    json_response(['error' => ['code' => 'FORBIDDEN', 'message' => 'Nur Trainer']], 403);
  }
  $playerId = urldecode($matches[1]);
  $discId = urldecode($matches[2]);

  try {
    $stmt = $pdo->prepare("DELETE FROM player_discs WHERE player_id = :player_id AND disc_id = :disc_id");
    $stmt->execute([':player_id' => $playerId, ':disc_id' => $discId]);
    if ($stmt->rowCount() === 0) {
      json_response(['error' => ['code' => 'NOT_FOUND', 'message' => 'Zuordnung nicht gefunden']], 404);
    } else {
      log_audit('player_discs', "$playerId-$discId", 'DELETE', ['player_id' => $playerId, 'disc_id' => $discId], null);
      json_response(['message' => 'Zuordnung erfolgreich entfernt'], 200);
    }
  } catch (Exception $e) {
    json_response(['error' => ['code' => 'DELETE_FAILED', 'message' => $e->getMessage()]], 500);
  }
}
