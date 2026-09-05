<?php
declare(strict_types=1);

require __DIR__ . '/../../src/bootstrap.php';

use TradeWars\Core\Auth;
use TradeWars\Core\DB;
use TradeWars\Core\Request;
use TradeWars\Core\Response;
use TradeWars\Game\Economy;

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    Response::error('POST required', 405);
}

$player = Auth::requirePlayer();
$commodity = (string)Request::input('commodity', '');
$action = (string)Request::input('action', '');
$qty = (int)Request::input('qty', 0);

if (!in_array($action, ['buy', 'sell'], true)) {
    Response::error('action must be buy or sell');
}

$db = DB::conn();
$stmt = $db->prepare('SELECT * FROM ports WHERE sector_id = :s');
$stmt->execute(['s' => $player['sector_id']]);
$port = $stmt->fetch();
if (!$port) {
    Response::error('There is no port in this sector', 404);
}
$port = Economy::regen($port);

$result = Economy::trade($port, $player, $commodity, $action, $qty);
if (!$result['ok']) {
    Response::error($result['error'], 400);
}

Response::ok(['port' => $result['port'], 'player' => $result['player'], 'total' => $result['total']]);
