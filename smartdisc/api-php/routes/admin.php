<?php
// Admin / Trainer-bezogene Routen

// GET /api/admin/overview - high level overview for trainers
if ($path === "$prefix/admin/overview" && $method === 'GET') {
  // Authentication required
  $token = require_auth();
  $user = get_user_by_token($token);
  if (!$user) {
    json_response(['error' => ['code' => 'UNAUTHORIZED', 'message' => 'Ungültiger Token']], 401);
  }

  // Only trainers are allowed to access this endpoint
  if (($user['role'] ?? null) !== 'trainer') {
    json_response(['error' => ['code' => 'FORBIDDEN', 'message' => 'Nur Trainer dürfen diesen Bereich sehen']], 403);
  }

  // a) All users with throws_count
  $usersStmt = $pdo->query("
    SELECT 
      u.id,
      u.email,
      u.role,
      u.created_at,
      (
        SELECT COUNT(*) 
        FROM wurfe w 
        WHERE w.player_id = u.id 
          AND w.geloescht = 0
      ) AS throws_count
    FROM users u
    ORDER BY u.created_at DESC
  ");
  $users = $usersStmt->fetchAll();

  // b) All discs with total throws_count_total
  $discsStmt = $pdo->query("
    SELECT
      s.id,
      s.name,
      s.aktiv,
      s.erstellt_am,
      (
        SELECT COUNT(*)
        FROM wurfe w
        WHERE w.scheibe_id = s.id
          AND w.geloescht = 0
      ) AS throws_count_total
    FROM scheiben s
    ORDER BY s.erstellt_am DESC
  ");
  $discs = $discsStmt->fetchAll();

  // c) Last 20 throws with joined player_email
  $throwsStmt = $pdo->query("
    SELECT
      w.id,
      w.scheibe_id,
      w.player_id,
      w.erstellt_am,
      w.rotation,
      w.hoehe,
      u.email AS player_email
    FROM wurfe w
    LEFT JOIN users u ON u.id = w.player_id
    WHERE w.geloescht = 0
    ORDER BY w.erstellt_am DESC
    LIMIT 20
  ");
  $throws = $throwsStmt->fetchAll();

  json_response([
    'users' => $users,
    'discs' => $discs,
    'throws_sample' => $throws,
  ]);
}

// Helper für Trainer-Request-Entscheidungen per Token
function handle_trainer_request_decision($status)
{
  global $pdo, $prefix;

  $token = $_GET['token'] ?? null;
  if (!$token) {
    json_response(['error' => ['code' => 'MISSING_TOKEN', 'message' => 'Token fehlt']], 400);
  }

  $stmt = $pdo->prepare("
    SELECT tr.id, tr.status, tr.user_id, u.email, u.first_name, u.last_name
    FROM trainer_requests tr
    JOIN users u ON u.id = tr.user_id
    WHERE tr.approval_token = :token
    LIMIT 1
  ");
  $stmt->execute([':token' => $token]);
  $request = $stmt->fetch();

  if (!$request) {
    json_response(['error' => ['code' => 'INVALID_TOKEN', 'message' => 'Ungültiger oder abgelaufener Token']], 404);
  }

  if ($request['status'] !== 'pending') {
    json_response(['error' => ['code' => 'ALREADY_DECIDED', 'message' => 'Diese Anfrage wurde bereits bearbeitet']], 400);
  }

  $update = $pdo->prepare("
    UPDATE trainer_requests
    SET status = :status,
        decided_at = datetime('now')
    WHERE id = :id
  ");
  $update->execute([
    ':status' => $status,
    ':id' => $request['id'],
  ]);

  $msg = $status === 'approved'
    ? 'Trainer-Anfrage wurde erfolgreich freigegeben.'
    : 'Trainer-Anfrage wurde abgelehnt.';

  json_response([
    'ok' => true,
    'message' => $msg,
    'user' => [
      'email' => $request['email'],
      'first_name' => $request['first_name'],
      'last_name' => $request['last_name'],
    ],
  ]);
}

// GET /api/admin/trainer-requests/approve?token=... - Anfrage freigeben
if ($path === "$prefix/admin/trainer-requests/approve" && $method === 'GET') {
  handle_trainer_request_decision('approved');
}

// GET /api/admin/trainer-requests/reject?token=... - Anfrage ablehnen
if ($path === "$prefix/admin/trainer-requests/reject" && $method === 'GET') {
  handle_trainer_request_decision('rejected');
}
