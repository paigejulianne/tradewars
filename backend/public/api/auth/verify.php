<?php
declare(strict_types=1);

require __DIR__ . '/../../../src/bootstrap.php';

use TradeWars\Core\DB;

function renderPage(string $title, string $message, bool $success): never
{
    header('Content-Type: text/html; charset=utf-8');
    $color = $success ? '#3ddc84' : '#ff5c5c';
    echo <<<HTML
<!doctype html>
<html><head><meta charset="utf-8"><title>{$title}</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
body{background:#05060f;color:#e8ecff;font-family:-apple-system,Segoe UI,Roboto,sans-serif;
display:flex;align-items:center;justify-content:center;height:100vh;margin:0;text-align:center}
.card{max-width:420px;padding:2.5rem;border:1px solid #2a2f55;border-radius:12px;background:#0c0e1c}
h1{color:{$color};font-size:1.4rem}
a{color:#7fd1ff}
</style></head>
<body><div class="card"><h1>{$title}</h1><p>{$message}</p>
<p><a href="/">Return to TradeWars</a></p></div></body></html>
HTML;
    exit;
}

$token = $_GET['token'] ?? '';
if (!$token || !preg_match('/^[a-f0-9]{64}$/', $token)) {
    renderPage('Invalid link', 'This verification link is malformed.', false);
}

$db = DB::conn();
$stmt = $db->prepare(
    'SELECT id, email_verified_at, verification_sent_at FROM users WHERE verification_token = :t'
);
$stmt->execute(['t' => $token]);
$user = $stmt->fetch();

if (!$user) {
    renderPage('Invalid or expired link', 'We could not find a pending verification for this link.', false);
}
if ($user['email_verified_at'] !== null) {
    renderPage('Already verified', 'Your email is already verified. You can log in now.', true);
}
$sentAt = new DateTimeImmutable($user['verification_sent_at']);
if ($sentAt->modify('+24 hours') < new DateTimeImmutable('now')) {
    renderPage('Link expired', 'This verification link expired. Please register again or request a new one.', false);
}

$db->prepare(
    'UPDATE users SET email_verified_at = NOW(), verification_token = NULL WHERE id = :id'
)->execute(['id' => $user['id']]);

renderPage('Email verified!', 'Your account is active. Head back to TradeWars and log in to claim your ship.', true);
