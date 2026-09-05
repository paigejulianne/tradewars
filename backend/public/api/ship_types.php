<?php
declare(strict_types=1);

require __DIR__ . '/../../src/bootstrap.php';

use TradeWars\Core\Auth;
use TradeWars\Core\DB;
use TradeWars\Core\Response;

Auth::requirePlayer();

$rows = DB::conn()->query('SELECT * FROM ship_types ORDER BY base_price ASC')->fetchAll();

Response::ok(['ship_types' => $rows]);
