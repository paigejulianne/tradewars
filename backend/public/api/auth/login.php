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

$email = trim((string)Request::input('email', ''));
$password = (string)Request::input('password', '');

$db = DB::conn();
$stmt = $db->prepare('SELECT * FROM users WHERE email = :e');
$stmt->execute(['e' => $email]);
$user = $stmt->fetch();

if (!$user || !Auth::verifyPassword($password, $user['password_hash'])) {
    Response::error('Invalid email or password', 401);
}
if ((int)$user['is_banned'] === 1) {
    Response::error('This account has been banned', 403);
}
if ($user['email_verified_at'] === null) {
    Response::error('Please verify your email before logging in', 403, ['code' => 'unverified']);
}

$token = Auth::createSession((int)$user['id']);
$db->prepare('UPDATE users SET last_login_at = NOW() WHERE id = :id')->execute(['id' => $user['id']]);

$pstmt = $db->prepare('SELECT * FROM players WHERE user_id = :uid');
$pstmt->execute(['uid' => $user['id']]);
$player = $pstmt->fetch();

Response::ok([
    'token' => $token,
    'user' => ['id' => (int)$user['id'], 'email' => $user['email'], 'is_admin' => (bool)$user['is_admin']],
    'player' => $player,
]);
