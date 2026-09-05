<?php
declare(strict_types=1);

require __DIR__ . '/../../src/bootstrap.php';

use TradeWars\Core\Auth;
use TradeWars\Core\DB;
use TradeWars\Core\Request;
use TradeWars\Core\Response;

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    Response::error('POST required', 405);
}

$player = Auth::requirePlayer();
$scope = (string)Request::input('scope', 'galaxy');
$message = trim((string)Request::input('message', ''));

if (!in_array($scope, ['galaxy', 'sector', 'corp'], true)) {
    Response::error('Invalid scope');
}
if ($message === '' || mb_strlen($message) > 500) {
    Response::error('Message must be 1-500 characters');
}
if ($scope === 'corp' && $player['corporation_id'] === null) {
    Response::error('You are not in a corporation');
}

$db = DB::conn();
$db->prepare(
    'INSERT INTO chat_messages (scope, sector_id, corporation_id, player_id, handle, message)
     VALUES (:sc, :s, :c, :p, :h, :m)'
)->execute([
    'sc' => $scope,
    's' => $scope === 'sector' ? $player['sector_id'] : null,
    'c' => $scope === 'corp' ? $player['corporation_id'] : null,
    'p' => $player['id'],
    'h' => $player['handle'],
    'm' => $message,
]);

Response::ok();
