<?php
// Disc assignment routes (trainer assigns discs to players)

// GET /api/assignments/players - Get all players (for trainer)
if ($path === "$prefix/assignments/players" && $method === 'GET') {
  $token = require_auth();
  $user = get_user_by_token($token);
  if (!$user) {
    json_response(['error' => ['code' => 'UNAUTHORIZED', 'message' => 'Ungültiger Token']], 401);
  }
  if (($user['role'] ?? null) !== 'trainer') {
    json_response(['error' => ['code' => 'FORBIDDEN', 'message' => 'Nur Trainer dürfen diesen Bereich sehen']], 403);
  }

  $stmt = $pdo->query("
    SELECT 
      id,
      first_name,
      last_name,
      email,
      created_at
    FROM users
    WHERE role = 'player'
    ORDER BY last_name, first_name
  ");
  json_response(['players' => $stmt->fetchAll()]);
}

// GET /api/assignments/player/:playerId - Get assigned discs for a player
if (preg_match("~^$prefix/assignments/player/([^/]+)$~", $path, $m) && $method === 'GET') {
  $token = require_auth();
  $user = get_user_by_token($token);
  if (!$user) {
    json_response(['error' => ['code' => 'UNAUTHORIZED', 'message' => 'Ungültiger Token']], 401);
  }
  
  $playerId = urldecode($m[1]);
  
  // Trainer can see any player's assignments, players can only see their own
  if (($user['role'] ?? null) === 'player' && $user['id'] !== $playerId) {
    json_response(['error' => ['code' => 'FORBIDDEN', 'message' => 'Keine Berechtigung']], 403);
  }

  $stmt = $pdo->prepare("
    SELECT 
      da.id,
      da.disc_id,
      da.player_id,
      da.assigned_at,
      s.name AS disc_name,
      u.first_name || ' ' || u.last_name AS assigned_by_name
    FROM disc_assignments da
    JOIN scheiben s ON s.id = da.disc_id
    LEFT JOIN users u ON u.id = da.assigned_by
    WHERE da.player_id = :player_id
    ORDER BY da.assigned_at DESC
  ");
  $stmt->execute([':player_id' => $playerId]);
  json_response(['assignments' => $stmt->fetchAll()]);
}

// POST /api/assignments - Assign disc to player (trainer only)
if ($path === "$prefix/assignments" && $method === 'POST') {
  $token = require_auth();
  $user = get_user_by_token($token);
  if (!$user) {
    json_response(['error' => ['code' => 'UNAUTHORIZED', 'message' => 'Ungültiger Token']], 401);
  }
  if (($user['role'] ?? null) !== 'trainer') {
    json_response(['error' => ['code' => 'FORBIDDEN', 'message' => 'Nur Trainer dürfen Discs zuordnen']], 403);
  }

  $input = get_json_input();
  if (empty($input['disc_id']) || empty($input['player_id'])) {
    json_response(['error' => ['code' => 'VALIDATION_ERROR', 'message' => 'disc_id und player_id sind erforderlich']], 400);
  }

  // Check if disc exists
  $discCheck = $pdo->prepare("SELECT id FROM scheiben WHERE id = :disc_id AND aktiv = 1");
  $discCheck->execute([':disc_id' => $input['disc_id']]);
  if (!$discCheck->fetch()) {
    json_response(['error' => ['code' => 'NOT_FOUND', 'message' => 'Disc nicht gefunden']], 404);
  }

  // Check if player exists and is a player
  $playerCheck = $pdo->prepare("SELECT id FROM users WHERE id = :player_id AND role = 'player'");
  $playerCheck->execute([':player_id' => $input['player_id']]);
  if (!$playerCheck->fetch()) {
    json_response(['error' => ['code' => 'NOT_FOUND', 'message' => 'Spieler nicht gefunden']], 404);
  }

  try {
    $stmt = $pdo->prepare("
      INSERT INTO disc_assignments (disc_id, player_id, assigned_by)
      VALUES (:disc_id, :player_id, :assigned_by)
      ON CONFLICT(disc_id, player_id) DO NOTHING
    ");
    $stmt->execute([
      ':disc_id' => $input['disc_id'],
      ':player_id' => $input['player_id'],
      ':assigned_by' => $user['id']
    ]);
    
    if ($stmt->rowCount() === 0) {
      json_response(['error' => ['code' => 'ALREADY_ASSIGNED', 'message' => 'Disc ist bereits diesem Spieler zugeordnet']], 409);
    } else {
      json_response(['message' => 'Disc erfolgreich zugeordnet'], 201);
    }
  } catch (Exception $e) {
    json_response(['error' => ['code' => 'ASSIGNMENT_FAILED', 'message' => $e->getMessage()]], 500);
  }
}

// DELETE /api/assignments/:assignmentId - Remove disc assignment (trainer only)
if (preg_match("~^$prefix/assignments/(\d+)$~", $path, $m) && $method === 'DELETE') {
  $token = require_auth();
  $user = get_user_by_token($token);
  if (!$user) {
    json_response(['error' => ['code' => 'UNAUTHORIZED', 'message' => 'Ungültiger Token']], 401);
  }
  if (($user['role'] ?? null) !== 'trainer') {
    json_response(['error' => ['code' => 'FORBIDDEN', 'message' => 'Nur Trainer dürfen Zuordnungen entfernen']], 403);
  }

  $assignmentId = (int)$m[1];
  $stmt = $pdo->prepare("DELETE FROM disc_assignments WHERE id = :id");
  $stmt->execute([':id' => $assignmentId]);
  
  if ($stmt->rowCount() === 0) {
    json_response(['error' => ['code' => 'NOT_FOUND', 'message' => 'Zuordnung nicht gefunden']], 404);
  } else {
    json_response(['message' => 'Zuordnung erfolgreich entfernt'], 200);
  }
}

// GET /api/assignments/my-discs - Get assigned discs for current player
if ($path === "$prefix/assignments/my-discs" && $method === 'GET') {
  $token = require_auth();
  $user = get_user_by_token($token);
  if (!$user) {
    json_response(['error' => ['code' => 'UNAUTHORIZED', 'message' => 'Ungültiger Token']], 401);
  }
  if (($user['role'] ?? null) !== 'player') {
    json_response(['error' => ['code' => 'FORBIDDEN', 'message' => 'Nur für Spieler']], 403);
  }

  $stmt = $pdo->prepare("
    SELECT 
      s.id,
      s.name,
      s.modell,
      s.seriennummer,
      s.firmware_version,
      s.kalibrierungsdatum,
      s.erstellt_am,
      da.assigned_at
    FROM disc_assignments da
    JOIN scheiben s ON s.id = da.disc_id
    WHERE da.player_id = :player_id AND s.aktiv = 1
    ORDER BY s.id
  ");
  $stmt->execute([':player_id' => $user['id']]);
  json_response(['discs' => $stmt->fetchAll()]);
}
