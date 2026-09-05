<?php
declare(strict_types=1);

require __DIR__ . '/../../../src/bootstrap.php';

use TradeWars\Core\Auth;
use TradeWars\Core\Request;
use TradeWars\Core\Response;

$token = Request::bearerToken();
if ($token) {
    Auth::destroySession($token);
}
Response::ok();
