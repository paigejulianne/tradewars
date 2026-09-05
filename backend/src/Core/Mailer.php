<?php
declare(strict_types=1);

namespace TradeWars\Core;

final class Mailer
{
    public static function send(string $toEmail, string $subject, string $bodyText): bool
    {
        $app = Config::get('app');
        $from = $app['mail_from'];
        $fromName = $app['mail_name'];

        $headers = [];
        $headers[] = 'From: ' . self::encodeHeader($fromName) . " <{$from}>";
        $headers[] = 'MIME-Version: 1.0';
        $headers[] = 'Content-Type: text/plain; charset=UTF-8';
        $headers[] = 'X-Mailer: TradeWars-PHP';

        $encodedSubject = self::encodeHeader($subject);

        return mail(
            $toEmail,
            $encodedSubject,
            $bodyText,
            implode("\r\n", $headers),
            '-f' . $from
        );
    }

    private static function encodeHeader(string $text): string
    {
        return '=?UTF-8?B?' . base64_encode($text) . '?=';
    }

    public static function sendVerification(string $toEmail, string $token): bool
    {
        $app = Config::get('app');
        $link = $app['url'] . '/api/auth/verify.php?token=' . urlencode($token);
        $body = "Welcome to TradeWars: Galactic Frontier!\n\n"
            . "Confirm your email address to activate your account and claim your first ship:\n\n"
            . "{$link}\n\n"
            . "This link expires in 24 hours. If you didn't create this account, ignore this email.\n\n"
            . "— The TradeWars: Galactic Frontier team\n";
        return self::send($toEmail, 'Verify your TradeWars account', $body);
    }

    public static function sendPasswordReset(string $toEmail, string $token): bool
    {
        $app = Config::get('app');
        $link = $app['url'] . '/reset-password?token=' . urlencode($token);
        $body = "A password reset was requested for your TradeWars account.\n\n"
            . "Reset your password here:\n\n{$link}\n\n"
            . "This link expires in 1 hour. If you didn't request this, you can safely ignore this email.\n\n"
            . "— The TradeWars: Galactic Frontier team\n";
        return self::send($toEmail, 'Reset your TradeWars password', $body);
    }
}
