<?php
declare(strict_types=1);

require __DIR__ . '/../../src/bootstrap.php';

use TradeWars\Core\Auth;
use TradeWars\Core\DB;
use TradeWars\Core\Request;
use TradeWars\Core\Response;

const ALLOWED = ['fuel_ore', 'organics', 'equipment', 'colonists'];

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    Response::error('POST required', 405);
}

$player = Auth::requirePlayer();
$commodity = (string)Request::input('commodity', '');
$qty = (int)Request::input('qty', 0);

if (!in_array($commodity, ALLOWED, true) || $qty <= 0) {
    Response::error('Invalid commodity or quantity');
}

$db = DB::conn();
$stmt = $db->prepare('SELECT * FROM planets WHERE sector_id = :s LIMIT 1');
$stmt->execute(['s' => $player['sector_id']]);
$planet = $stmt->fetch();

if (!$planet) {
    Response::error('There is no planet in this sector', 404);
}
if ((int)$planet['owner_player_id'] !== (int)$player['id']) {
    Response::error('You do not own this planet', 403);
}

$planetColumn = $commodity === 'colonists' ? 'colonists' : "{$commodity}_stock";
if ((int)$planet[$planetColumn] < $qty) {
    Response::error('The planet does not have that much in storage');
}

$holdsUsed = (int)$player['fuel_ore'] + (int)$player['organics'] + (int)$player['equipment'] + (int)$player['colonists'];
if ($holdsUsed + $qty > (int)$player['holds_total']) {
    Response::error('Not enough cargo hold space');
}

$db->beginTransaction();
try {
    $db->prepare("UPDATE planets SET {$planetColumn} = {$planetColumn} - :q WHERE id = :id")
        ->execute(['q' => $qty, 'id' => $planet['id']]);
    $db->prepare("UPDATE players SET {$commodity} = {$commodity} + :q WHERE id = :id")
        ->execute(['q' => $qty, 'id' => $player['id']]);
    $db->commit();
} catch (\Throwable $e) {
    $db->rollBack();
    throw $e;
}

Response::ok(['collected' => $qty]);
