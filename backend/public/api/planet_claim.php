<?php
declare(strict_types=1);

require __DIR__ . '/../../src/bootstrap.php';

use TradeWars\Core\Auth;
use TradeWars\Core\DB;
use TradeWars\Core\Request;
use TradeWars\Core\Response;
use TradeWars\Game\Events;

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    Response::error('POST required', 405);
}

$player = Auth::requirePlayer();
$name = trim((string)Request::input('name', $player['handle'] . "'s Colony"));
$name = substr($name, 0, 64) ?: 'Unnamed Colony';

$db = DB::conn();
$stmt = $db->prepare('SELECT * FROM planets WHERE sector_id = :s LIMIT 1');
$stmt->execute(['s' => $player['sector_id']]);
$planet = $stmt->fetch();

if (!$planet) {
    Response::error('There is no planet in this sector', 404);
}
if ($planet['owner_player_id'] !== null) {
    Response::error('This planet is already claimed', 409);
}

$db->prepare('UPDATE planets SET owner_player_id = :p, name = :n WHERE id = :id')
    ->execute(['p' => $player['id'], 'n' => $name, 'id' => $planet['id']]);

Events::log('planet_claimed', (int)$player['sector_id'], (int)$player['id'],
    'New colony founded', "{$player['handle']} claimed {$name} in sector {$player['sector_id']}.");

Response::ok(['message' => "You claimed {$name}."]);
