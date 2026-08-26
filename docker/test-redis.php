<?php
$host = getenv('REDIS_HOST') ?: 'redis';
$port = getenv('REDIS_PORT') ?: 6379;
$pass = getenv('REDIS_PASSWORD');
$c = @fsockopen($host, $port, $e, $s, 2);
echo $c ? "Redis OK\n" : "Redis FAIL\n";
if ($c) {
    fclose($c);
}
