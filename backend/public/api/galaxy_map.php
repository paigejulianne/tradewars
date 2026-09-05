<?php
declare(strict_types=1);

require __DIR__ . '/../../src/bootstrap.php';

use TradeWars\Core\Auth;
use TradeWars\Core\DB;
use TradeWars\Core\Response;

Auth::requirePlayer();

$db = DB::conn();
$sectors = $db->query(
    'SELECT id, name, x, y, region, is_federation, has_port, hazard FROM sectors ORDER BY id'
)->fetchAll();
$warps = $db->query('SELECT from_sector AS `from`, to_sector AS `to` FROM warps')->fetchAll();

Response::ok(['sectors' => $sectors, 'warps' => $warps]);
