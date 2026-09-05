<?php
declare(strict_types=1);

namespace TradeWars\Core;

final class Auth
{
    public const SESSION_DAYS = 30;

    public static function hashPassword(string $password): string
    {
        return password_hash($password, PASSWORD_DEFAULT);
    }

    public static function verifyPassword(string $password, string $hash): bool
    {
        return password_verify($password, $hash);
    }

    public static function randomToken(int $bytes = 32): string
    {
        return bin2hex(random_bytes($bytes));
    }

    public static function tokenHash(string $token): string
    {
        return hash('sha256', $token);
    }

    public static function createSession(int $userId): string
    {
        $token = self::randomToken();
        $stmt = DB::conn()->prepare(
            'INSERT INTO sessions (user_id, token_hash, ip, user_agent, expires_at)
             VALUES (:uid, :hash, :ip, :ua, DATE_ADD(NOW(), INTERVAL :days DAY))'
        );
        $stmt->execute([
            'uid'  => $userId,
            'hash' => self::tokenHash($token),
            'ip'   => $_SERVER['REMOTE_ADDR'] ?? null,
            'ua'   => substr($_SERVER['HTTP_USER_AGENT'] ?? '', 0, 255),
            'days' => self::SESSION_DAYS,
        ]);
        return $token;
    }

    public static function destroySession(string $token): void
    {
        $stmt = DB::conn()->prepare('DELETE FROM sessions WHERE token_hash = :h');
        $stmt->execute(['h' => self::tokenHash($token)]);
    }

    /** Returns the authenticated user row, or null. Also touches last_seen_at. */
    public static function userFromRequest(): ?array
    {
        $token = Request::bearerToken();
        if (!$token) {
            return null;
        }
        $hash = self::tokenHash($token);
        $stmt = DB::conn()->prepare(
            'SELECT u.* FROM sessions s
             JOIN users u ON u.id = s.user_id
             WHERE s.token_hash = :h AND s.expires_at > NOW()'
        );
        $stmt->execute(['h' => $hash]);
        $user = $stmt->fetch();
        if (!$user) {
            return null;
        }
        DB::conn()->prepare('UPDATE sessions SET last_seen_at = NOW() WHERE token_hash = :h')
            ->execute(['h' => $hash]);
        return $user;
    }

    public static function requireUser(): array
    {
        $user = self::userFromRequest();
        if (!$user) {
            Response::error('Unauthorized', 401);
        }
        if ((int)$user['is_banned'] === 1) {
            Response::error('Account banned', 403);
        }
        return $user;
    }

    /** Returns the player row for the authenticated user, or errors out. */
    public static function requirePlayer(): array
    {
        $user = self::requireUser();
        $stmt = DB::conn()->prepare('SELECT * FROM players WHERE user_id = :uid');
        $stmt->execute(['uid' => $user['id']]);
        $player = $stmt->fetch();
        if (!$player) {
            Response::error('No player character for this account yet', 409, ['code' => 'no_player']);
        }
        return $player;
    }
}
