<?php
declare(strict_types=1);

require __DIR__ . '/../../src/bootstrap.php';

use TradeWars\Core\Auth;
use TradeWars\Core\DB;
use TradeWars\Core\Response;

$player = Auth::requirePlayer();
$id = (int)($_GET['id'] ?? $player['corporation_id'] ?? 0);

if ($id <= 0) {
    Response::ok(['corporations' => DB::conn()->query(
        'SELECT id, name, tag, treasury, (SELECT COUNT(*) FROM corporation_members m WHERE m.corporation_id = c.id) AS member_count
         FROM corporations c ORDER BY treasury DESC LIMIT 100'
    )->fetchAll()]);
}

$db = DB::conn();
$stmt = $db->prepare('SELECT * FROM corporations WHERE id = :id');
$stmt->execute(['id' => $id]);
$corp = $stmt->fetch();
if (!$corp) {
    Response::error('No such corporation', 404);
}

$stmt = $db->prepare(
    'SELECT p.id, p.handle, p.experience, cm.role FROM corporation_members cm
     JOIN players p ON p.id = cm.player_id WHERE cm.corporation_id = :id ORDER BY cm.role, p.experience DESC'
);
$stmt->execute(['id' => $id]);
$members = $stmt->fetchAll();

Response::ok(['corporation' => $corp, 'members' => $members]);
