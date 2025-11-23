<?php
// Router für PHP Built-in Server
$requestUri = $_SERVER['REQUEST_URI'];
$requestPath = parse_url($requestUri, PHP_URL_PATH);

// Alle Requests zu index.php weiterleiten
if (file_exists(__DIR__ . $requestPath) && $requestPath !== '/') {
    return false; // Serve file directly
}

// Alle API-Requests zu index.php weiterleiten
require __DIR__ . '/index.php';

