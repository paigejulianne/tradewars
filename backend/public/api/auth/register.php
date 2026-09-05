<?php
declare(strict_types=1);

require __DIR__ . '/../../../src/bootstrap.php';

use TradeWars\Core\Config;
use TradeWars\Core\DB;
use TradeWars\Core\Auth;
use TradeWars\Core\Mailer;
use TradeWars\Core\Request;
use TradeWars\Core\Response;

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    Response::error('POST required', 405);
}

$email = trim((string)Request::input('email', ''));
$password = (string)Request::input('password', '');
$handle = trim((string)Request::input('handle', ''));

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    Response::error('Enter a valid email address');
}
if (strlen($password) < 8) {
    Response::error('Password must be at least 8 characters');
}
if (!preg_match('/^[A-Za-z0-9_\-]{3,20}$/', $handle)) {
    Response::error('Handle must be 3-20 characters: letters, numbers, - or _');
}

$db = DB::conn();

$stmt = $db->prepare('SELECT id FROM users WHERE email = :e');
$stmt->execute(['e' => $email]);
if ($stmt->fetch()) {
    Response::error('An account with that email already exists', 409);
}

$stmt = $db->prepare('SELECT id FROM players WHERE handle = :h');
$stmt->execute(['h' => $handle]);
if ($stmt->fetch()) {
    Response::error('That callsign is already taken', 409);
}

$token = Auth::randomToken();

$db->beginTransaction();
try {
    $db->prepare(
        'INSERT INTO users (email, password_hash, verification_token, verification_sent_at)
         VALUES (:e, :p, :t, NOW())'
    )->execute([
        'e' => $email,
        'p' => Auth::hashPassword($password),
        't' => $token,
    ]);
    $userId = (int)$db->lastInsertId();

    $app = Config::get('app');
    $db->prepare(
        'INSERT INTO players (user_id, handle, credits, turns_remaining, turns_reset_at)
         VALUES (:u, :h, :cr, :tr, NOW())'
    )->execute([
        'u' => $userId,
        'h' => $handle,
        'cr' => $app['starting_credits'],
        'tr' => $app['starting_turns'],
    ]);

    $db->commit();
} catch (\Throwable $e) {
    $db->rollBack();
    throw $e;
}

Mailer::sendVerification($email, $token);

Response::ok(['message' => 'Account created. Check your email to verify and start playing.']);
