<?php
declare(strict_types=1);

require __DIR__ . '/../../src/bootstrap.php';

use TradeWars\Core\Auth;
use TradeWars\Core\DB;
use TradeWars\Core\Request;
use TradeWars\Core\Response;
use TradeWars\Game\Events;
use TradeWars\Game\Galaxy;
use TradeWars\Game\PlayerOps;
use TradeWars\Game\TurnManager;

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    Response::error('POST required', 405);
}

$player = Auth::requirePlayer();
$player = TurnManager::maybeReset($player);

$to = (int)Request::input('to_sector', 0);
$from = (int)$player['sector_id'];

if ($to <= 0) {
    Response::error('to_sector is required');
}
if ($to === $from) {
    Response::error('You are already there');
}
if (!Galaxy::isAdjacent($from, $to)) {
    Response::error('No warp lane connects your sector to that one', 400, ['code' => 'not_adjacent']);
}

$db = DB::conn();
$stmt = $db->prepare('SELECT turn_cost FROM ship_types WHERE id = :id');
$stmt->execute(['id' => $player['ship_type_id']]);
$turnCost = (int)$stmt->fetchColumn();

if (!TurnManager::spend($player, $turnCost)) {
    Response::error('Not enough turns remaining', 402, ['code' => 'no_turns']);
}

$db->prepare('UPDATE players SET sector_id = :s, last_action_at = NOW() WHERE id = :id')
    ->execute(['s' => $to, 'id' => $player['id']]);

$sector = Galaxy::sector($to);

// Hostile mines: a chance to strike when entering a sector seeded with
// another player's (or nobody's) mines.
$mineHit = null;
$stmt = $db->prepare(
    'SELECT id, owner_player_id, quantity FROM mines WHERE sector_id = :s
     AND (owner_player_id IS NULL OR owner_player_id != :p) AND quantity > 0'
);
$stmt->execute(['s' => $to, 'p' => $player['id']]);
$mineFields = $stmt->fetchAll();

$playerFighters = (int)$player['fighters'];
$playerShields = (int)$player['shields'];

foreach ($mineFields as $field) {
    $qty = (int)$field['quantity'];
    $chance = min(60, 15 + $qty); // %
    if (random_int(1, 100) > $chance) {
        continue;
    }
    $damage = random_int(5, 15) + (int)round($qty * 1.5);
    $absorbed = min($playerShields, $damage);
    $playerShields -= $absorbed;
    $remaining = $damage - $absorbed;
    $playerFighters = max(0, $playerFighters - $remaining);

    $triggered = min($qty, random_int(1, 3));
    $db->prepare('UPDATE mines SET quantity = quantity - :q WHERE id = :id')
        ->execute(['q' => $triggered, 'id' => $field['id']]);

    $mineHit = ['damage' => $damage, 'fighters_lost' => $remaining, 'shields_absorbed' => $absorbed];
    Events::log('mine_strike', $to, (int)$player['id'], 'Mine field detonation',
        "{$player['handle']}'s ship struck a mine field in sector {$to}!");
    break;
}

$db->prepare('UPDATE players SET fighters = :f, shields = :sh WHERE id = :id')
    ->execute(['f' => $playerFighters, 'sh' => $playerShields, 'id' => $player['id']]);

if ($playerFighters <= 0) {
    PlayerOps::pod((int)$player['id']);
    Events::log('ship_lost', $to, (int)$player['id'], 'Ship destroyed by mines',
        "{$player['handle']}'s ship was destroyed by a mine field! They eject to an escape pod.");
    Response::ok([
        'sector_id' => 1,
        'sector' => Galaxy::sector(1),
        'turns_remaining' => (int)$player['turns_remaining'] - $turnCost,
        'mine_hit' => $mineHit,
        'ship_destroyed' => true,
    ]);
}

Response::ok([
    'sector_id' => $to,
    'sector' => $sector,
    'turns_remaining' => (int)$player['turns_remaining'] - $turnCost,
    'mine_hit' => $mineHit,
    'fighters' => $playerFighters,
    'shields' => $playerShields,
]);
