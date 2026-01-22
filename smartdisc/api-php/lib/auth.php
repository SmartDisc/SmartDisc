<?php
// Auth Helper Functions

function get_bearer_token()
{
  $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
  if (empty($authHeader) || !preg_match('/^Bearer (.+)$/', $authHeader, $matches)) {
    return null;
  }
  return $matches[1];
}

function require_auth()
{
  $token = get_bearer_token();
  if (!$token) {
    json_response(['error' => ['code' => 'UNAUTHORIZED', 'message' => 'Token fehlt']], 401);
  }
  return $token;
}

function get_user_by_token($token)
{
  global $pdo;
  $stmt = $pdo->prepare("
    SELECT u.id, u.first_name, u.last_name, u.email, u.role, u.created_at
    FROM users u
    INNER JOIN auth_tokens at ON u.id = at.user_id
    WHERE at.token = :token
  ");
  $stmt->execute([':token' => $token]);
  return $stmt->fetch();
}

function find_user_by_email($email)
{
  global $pdo;
  $stmt = $pdo->prepare("SELECT * FROM users WHERE email = :email");
  $stmt->execute([':email' => trim(strtolower($email))]);
  return $stmt->fetch();
}

function create_auth_token($userId)
{
  global $pdo;
  $token = bin2hex(random_bytes(24));
  $stmt = $pdo->prepare("
    INSERT INTO auth_tokens (user_id, token, created_at)
    VALUES (:user_id, :token, strftime('%Y-%m-%dT%H:%M:%fZ','now'))
  ");
  $stmt->execute([
    ':user_id' => $userId,
    ':token' => $token
  ]);
  return $token;
}

function delete_auth_token($token)
{
  global $pdo;
  $stmt = $pdo->prepare("DELETE FROM auth_tokens WHERE token = :token");
  $stmt->execute([':token' => $token]);
}
