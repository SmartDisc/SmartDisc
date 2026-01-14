<?php
// Admin overview routes (trainer only)

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



