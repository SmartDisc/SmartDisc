<?php
// Auth routes: register, login, me, logout

// POST /api/auth/register - Benutzer registrieren
if ($path === "$prefix/auth/register") {
  if ($method !== 'POST') {
    json_response(['error'=>['code'=>'METHOD_NOT_ALLOWED','message'=>'Nur POST erlaubt']], 405);
  }
  $input = get_json_input();
  
  // Validation
  $errors = [];
  if (empty($input['first_name']) || trim($input['first_name']) === '') {
    $errors[] = 'Vorname ist erforderlich';
  }
  if (empty($input['last_name']) || trim($input['last_name']) === '') {
    $errors[] = 'Nachname ist erforderlich';
  }
  if (empty($input['email']) || !filter_var($input['email'], FILTER_VALIDATE_EMAIL)) {
    $errors[] = 'Gültige E-Mail-Adresse ist erforderlich';
  }
  if (empty($input['password']) || strlen($input['password']) < 6) {
    $errors[] = 'Passwort muss mindestens 6 Zeichen lang sein';
  }
  if (empty($input['password_confirm']) || $input['password'] !== $input['password_confirm']) {
    $errors[] = 'Passwörter stimmen nicht überein';
  }
  if (empty($input['role']) || !in_array($input['role'], ['player', 'trainer'])) {
    $errors[] = 'Rolle muss "player" oder "trainer" sein';
  }
  
  if (!empty($errors)) {
    json_response(['error'=>['code'=>'VALIDATION_ERROR','message'=>implode(', ', $errors)]], 400);
  }
  
  // Prüfe ob Email bereits existiert
  $checkStmt = $pdo->prepare("SELECT id FROM users WHERE email = :email");
  $checkStmt->execute([':email' => trim(strtolower($input['email']))]);
  if ($checkStmt->fetch()) {
    json_response(['error'=>['code'=>'EMAIL_EXISTS','message'=>'Diese E-Mail-Adresse ist bereits registriert']], 409);
  }
  
  // Passwort hashen
  $passwordHash = password_hash($input['password'], PASSWORD_DEFAULT);
  $userId = bin2hex(random_bytes(16));
  
  try {
    $pdo->beginTransaction();
    
    // User einfügen
    $stmt = $pdo->prepare("
      INSERT INTO users (id, first_name, last_name, email, password_hash, role, created_at)
      VALUES (:id, :first_name, :last_name, :email, :password_hash, :role, strftime('%Y-%m-%dT%H:%M:%fZ','now'))
    ");
    $stmt->execute([
      ':id' => $userId,
      ':first_name' => trim($input['first_name']),
      ':last_name' => trim($input['last_name']),
      ':email' => trim(strtolower($input['email'])),
      ':password_hash' => $passwordHash,
      ':role' => $input['role']
    ]);
    
    // Token generieren und speichern
    $token = create_auth_token($userId);
    
    $pdo->commit();
    
    json_response([
      'ok' => true,
      'token' => $token,
      'user' => [
        'id' => $userId,
        'first_name' => trim($input['first_name']),
        'last_name' => trim($input['last_name']),
        'email' => trim(strtolower($input['email'])),
        'role' => $input['role']
      ]
    ], 201);
  } catch (Exception $e) {
    $pdo->rollBack();
    json_response(['error'=>['code'=>'REGISTER_FAILED','message'=>$e->getMessage()]], 500);
  }
}

// POST /api/auth/login - Benutzer einloggen
if ($path === "$prefix/auth/login") {
  if ($method !== 'POST') {
    json_response(['error'=>['code'=>'METHOD_NOT_ALLOWED','message'=>'Nur POST erlaubt']], 405);
  }
  $input = get_json_input();
  
  // Validation
  if (empty($input['email']) || empty($input['password'])) {
    json_response(['error'=>['code'=>'VALIDATION_ERROR','message'=>'E-Mail und Passwort sind erforderlich']], 400);
  }
  
  // Benutzer suchen - nur anhand Email (email ist UNIQUE)
  $user = find_user_by_email($input['email']);
  
  if (!$user || !password_verify($input['password'], $user['password_hash'])) {
    json_response(['error'=>['code'=>'INVALID_CREDENTIALS','message'=>'Ungültige E-Mail oder Passwort']], 401);
  }
  
  // Token generieren und speichern
  try {
    $token = create_auth_token($user['id']);
  } catch (Exception $e) {
    json_response(['error'=>['code'=>'TOKEN_FAILED','message'=>'Token konnte nicht erstellt werden']], 500);
  }
  
  json_response([
    'ok' => true,
    'token' => $token,
    'user' => [
      'id' => $user['id'],
      'first_name' => $user['first_name'],
      'last_name' => $user['last_name'],
      'email' => $user['email'],
      'role' => $user['role']
    ]
  ]);
}

// GET /api/auth/me - Aktuellen Benutzer abrufen (mit Token)
if ($path === "$prefix/auth/me") {
  if ($method !== 'GET') {
    json_response(['error'=>['code'=>'METHOD_NOT_ALLOWED','message'=>'Nur GET erlaubt']], 405);
  }
  $token = require_auth();
  $user = get_user_by_token($token);
  
  if (!$user) {
    json_response(['error'=>['code'=>'INVALID_TOKEN','message'=>'Ungültiger Token']], 401);
  }
  
  json_response(['user' => $user]);
}

// POST /api/auth/logout - Ausloggen (Token löschen)
if ($path === "$prefix/auth/logout") {
  if ($method !== 'POST') {
    json_response(['error'=>['code'=>'METHOD_NOT_ALLOWED','message'=>'Nur POST erlaubt']], 405);
  }
  $token = require_auth();
  
  try {
    delete_auth_token($token);
    json_response(['ok' => true, 'message' => 'Erfolgreich ausgeloggt']);
  } catch (Exception $e) {
    json_response(['error'=>['code'=>'LOGOUT_FAILED','message'=>$e->getMessage()]], 500);
  }
}

