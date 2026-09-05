<?php
declare(strict_types=1);

require __DIR__ . '/../../../src/bootstrap.php';

use TradeWars\Core\DB;
use TradeWars\Core\Auth;
use TradeWars\Core\Mailer;
use TradeWars\Core\Request;
use TradeWars\Core\Response;

if (($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') {
    Response::error('POST required', 405);
}

$email = trim((string)Request::input('email', ''));
$db = DB::conn();
$stmt = $db->prepare('SELECT id FROM users WHERE email = :e');
$stmt->execute(['e' => $email]);
$user = $stmt->fetch();

if ($user) {
    $token = Auth::randomToken();
    $db->prepare(
        'INSERT INTO password_resets (user_id, token, expires_at) VALUES (:u, :t, DATE_ADD(NOW(), INTERVAL 1 HOUR))'
    )->execute(['u' => $user['id'], 't' => $token]);
    Mailer::sendPasswordReset($email, $token);
}

// Always respond ok — do not leak whether an email is registered.
Response::ok(['message' => 'If that email is registered, a reset link is on its way.']);
