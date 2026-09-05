<?php
declare(strict_types=1);

require __DIR__ . '/../../src/bootstrap.php';

use TradeWars\Core\Auth;
use TradeWars\Core\DB;
use TradeWars\Core\Response;

Auth::requirePlayer();

$rows = DB::conn()->query(
    'SELECT p.handle, p.credits, p.experience, p.alignment, st.name AS ship_name, c.tag AS corp_tag
     FROM players p
     LEFT JOIN ship_types st ON st.id = p.ship_type_id
     LEFT JOIN corporations c ON c.id = p.corporation_id
     WHERE p.is_alive = 1
     ORDER BY p.credits DESC LIMIT 50'
)->fetchAll();

Response::ok(['leaderboard' => $rows]);
