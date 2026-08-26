<?php
$host = getenv('DB_HOST') ?: 'postgresql';
$db = getenv('DB_NAME') ?: 'moodle';
$user = getenv('DB_USER') ?: 'moodle';
$pass = getenv('DB_PASSWORD');
$dsn = "pgsql:host=$host;dbname=$db";
try {
    $pdo = new PDO($dsn, $user, $pass);
    echo "DB OK\n";
} catch (Exception $e) {
    echo "DB FAIL: " . $e->getMessage() . "\n";
}
