<?php
// HTTP Helper Functions

function json_response($data, $code=200){
  http_response_code($code);
  header('Content-Type: application/json; charset=utf-8');
  echo json_encode($data, JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT);
  exit;
}

function get_json_input() {
  return json_decode(file_get_contents('php://input'), true) ?? [];
}

function setup_cors() {
  header('Access-Control-Allow-Origin: *');
  header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
  header('Access-Control-Allow-Headers: Content-Type, Authorization');
  if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
  }
}

function parse_request_path() {
  $path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
  return rtrim($path, '/');
}

function get_request_method() {
  return $_SERVER['REQUEST_METHOD'];
}

