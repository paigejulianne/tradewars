<?php
declare(strict_types=1);

require __DIR__ . '/../../src/bootstrap.php';

use TradeWars\Core\Auth;
use TradeWars\Core\DB;
use TradeWars\Core\Request;
use TradeWars\Core\Response;
use TradeWars\Game\Combat;
use TradeWars\Game\Events;
use TradeWars\Game\Galaxy;
use TradeWars\Game\PlayerOps;
use TradeWars\Game\TurnManager;

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    Response::error('POST required', 405);
}

$player = Auth::requirePlayer();
$player = TurnManager::maybeReset($player);
$targetType = (string)Request::input('target_type', '');
$targetId = (int)Request::input('target_id', 0);

if (!in_array($targetType, ['player', 'npc'], true)) {
    Response::error('target_type must be player or npc');
}
if ((int)$player['fighters'] <= 0) {
    Response::error('You have no fighters to attack with');
}
if (!TurnManager::spend($player, 2)) {
    Response::error('Not enough turns remaining', 402, ['code' => 'no_turns']);
}

$db = DB::conn();
$sectorId = (int)$player['sector_id'];

if ($targetType === 'npc') {
    $stmt = $db->prepare('SELECT * FROM npc_ships WHERE id = :id AND sector_id = :s');
    $stmt->execute(['id' => $targetId, 's' => $sectorId]);
    $npc = $stmt->fetch();
    if (!$npc) {
        Response::error('That target is not in this sector', 404);
    }

    $result = Combat::fight((int)$player['fighters'], (int)$player['shields'], (int)$npc['fighters'], (int)$npc['shields']);

    $db->prepare('UPDATE players SET fighters = :f, shields = :s WHERE id = :id')
        ->execute(['f' => $result['attacker_fighters'], 's' => $result['attacker_shields'], 'id' => $player['id']]);

    $looted = 0;
    if ($result['outcome'] === 'attacker_wins') {
        $looted = (int)$npc['bounty_credits'];
        $db->prepare('UPDATE players SET credits = credits + :c WHERE id = :id')
            ->execute(['c' => $looted, 'id' => $player['id']]);
        $db->prepare('DELETE FROM npc_ships WHERE id = :id')->execute(['id' => $npc['id']]);
        Events::log('combat', $sectorId, (int)$player['id'], 'Hostile destroyed',
            "{$player['handle']} destroyed {$npc['name']} in sector {$sectorId} and looted {$looted} credits.");
    } elseif ($result['outcome'] === 'defender_wins') {
        PlayerOps::pod((int)$player['id']);
        Events::log('combat', $sectorId, (int)$player['id'], 'Ship destroyed',
            "{$player['handle']}'s ship was destroyed by {$npc['name']}! They eject to an escape pod.");
    } else {
        $db->prepare('UPDATE npc_ships SET fighters = :f, shields = :s WHERE id = :id')
            ->execute(['f' => $result['defender_fighters'], 's' => $result['defender_shields'], 'id' => $npc['id']]);
    }

    $db->prepare(
        'INSERT INTO combat_log (sector_id, attacker_player_id, defender_npc_id, outcome, fighters_lost_attacker, fighters_lost_defender, credits_looted, detail)
         VALUES (:s, :a, :n, :o, :fla, :fld, :cl, :d)'
    )->execute([
        's' => $sectorId, 'a' => $player['id'], 'n' => $npc['id'], 'o' => $result['outcome'],
        'fla' => (int)$player['fighters'] - $result['attacker_fighters'],
        'fld' => (int)$npc['fighters'] - $result['defender_fighters'],
        'cl' => $looted, 'd' => json_encode($result['rounds']),
    ]);

    Response::ok(['result' => $result, 'looted' => $looted]);
}

// target_type === 'player'
$stmt = $db->prepare('SELECT * FROM players WHERE id = :id AND sector_id = :s AND is_alive = 1');
$stmt->execute(['id' => $targetId, 's' => $sectorId]);
$defender = $stmt->fetch();
if (!$defender) {
    Response::error('That player is not in this sector', 404);
}
if ((int)$defender['id'] === (int)$player['id']) {
    Response::error('You cannot attack yourself');
}

$result = Combat::fight((int)$player['fighters'], (int)$player['shields'], (int)$defender['fighters'], (int)$defender['shields']);

$db->prepare('UPDATE players SET fighters = :f, shields = :s WHERE id = :id')
    ->execute(['f' => $result['attacker_fighters'], 's' => $result['attacker_shields'], 'id' => $player['id']]);
$db->prepare('UPDATE players SET fighters = :f, shields = :s WHERE id = :id')
    ->execute(['f' => $result['defender_fighters'], 's' => $result['defender_shields'], 'id' => $defender['id']]);

$looted = 0;
if ($result['outcome'] === 'attacker_wins') {
    $looted = (int)round((int)$defender['credits'] * 0.2);
    $db->prepare('UPDATE players SET credits = credits - :c WHERE id = :id')->execute(['c' => $looted, 'id' => $defender['id']]);
    $db->prepare('UPDATE players SET credits = credits + :c WHERE id = :id')->execute(['c' => $looted, 'id' => $player['id']]);
    PlayerOps::pod((int)$defender['id']);
    Events::log('combat', $sectorId, (int)$player['id'], 'Player defeated',
        "{$player['handle']} defeated {$defender['handle']} in sector {$sectorId} and looted {$looted} credits!");
} elseif ($result['outcome'] === 'defender_wins') {
    PlayerOps::pod((int)$player['id']);
    Events::log('combat', $sectorId, (int)$defender['id'], 'Attacker repelled',
        "{$defender['handle']} fought off an attack from {$player['handle']} in sector {$sectorId}!");
}

$db->prepare(
    'INSERT INTO combat_log (sector_id, attacker_player_id, defender_player_id, outcome, fighters_lost_attacker, fighters_lost_defender, credits_looted, detail)
     VALUES (:s, :a, :df, :o, :fla, :fld, :cl, :d)'
)->execute([
    's' => $sectorId, 'a' => $player['id'], 'df' => $defender['id'], 'o' => $result['outcome'],
    'fla' => (int)$player['fighters'] - $result['attacker_fighters'],
    'fld' => (int)$defender['fighters'] - $result['defender_fighters'],
    'cl' => $looted, 'd' => json_encode($result['rounds']),
]);

Response::ok(['result' => $result, 'looted' => $looted]);
