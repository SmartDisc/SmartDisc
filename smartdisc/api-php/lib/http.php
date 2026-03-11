<?php
// HTTP Helper Functions

function json_response($data, $code = 200)
{
  http_response_code($code);
  header('Content-Type: application/json; charset=utf-8');
  echo json_encode($data, JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT);
  exit;
}

function get_json_input()
{
  $raw = file_get_contents('php://input');
  $decoded = json_decode($raw, true);
  if ($raw !== '' && $raw !== false && json_last_error() !== JSON_ERROR_NONE) {
    json_response(['error' => ['code' => 'INVALID_JSON', 'message' => 'Invalid JSON in request body']], 400);
  }
  return $decoded ?? [];
}

function setup_cors()
{
  header('Access-Control-Allow-Origin: *');
  header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
  header('Access-Control-Allow-Headers: Content-Type, Authorization');
  if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
  }
}

function parse_request_path()
{
  $path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
  return rtrim($path, '/');
}

function get_request_method()
{
  return $_SERVER['REQUEST_METHOD'];
}
