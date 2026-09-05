<?php
declare(strict_types=1);

require __DIR__ . '/../../../src/bootstrap.php';

use TradeWars\Core\DB;
use TradeWars\Core\Auth;
use TradeWars\Core\Request;
use TradeWars\Core\Response;

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    Response::error('POST required', 405);
}

$token = (string)Request::input('token', '');
$password = (string)Request::input('password', '');

if (strlen($password) < 8) {
    Response::error('Password must be at least 8 characters');
}

$db = DB::conn();
$stmt = $db->prepare(
    'SELECT * FROM password_resets WHERE token = :t AND used_at IS NULL AND expires_at > NOW()'
);
$stmt->execute(['t' => $token]);
$reset = $stmt->fetch();

if (!$reset) {
    Response::error('This reset link is invalid or has expired', 400);
}

$db->beginTransaction();
try {
    $db->prepare('UPDATE users SET password_hash = :p WHERE id = :id')
        ->execute(['p' => Auth::hashPassword($password), 'id' => $reset['user_id']]);
    $db->prepare('UPDATE password_resets SET used_at = NOW() WHERE id = :id')
        ->execute(['id' => $reset['id']]);
    $db->prepare('DELETE FROM sessions WHERE user_id = :id')
        ->execute(['id' => $reset['user_id']]);
    $db->commit();
} catch (\Throwable $e) {
    $db->rollBack();
    throw $e;
}

Response::ok(['message' => 'Password updated. You can log in now.']);
