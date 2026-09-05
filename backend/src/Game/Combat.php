<?php
declare(strict_types=1);

namespace TradeWars\Game;

/**
 * Simple round-based combat resolver: each side fires a random fraction of
 * its remaining fighters per round; shields absorb damage before fighters
 * are lost. Runs up to 5 rounds or until one side is wiped out.
 */
final class Combat
{
    public static function fight(int $atkFighters, int $atkShields, int $defFighters, int $defShields): array
    {
        $af = $atkFighters;
        $as = $atkShields;
        $df = $defFighters;
        $ds = $defShields;
        $rounds = [];

        for ($round = 1; $round <= 5; $round++) {
            if ($af <= 0 || $df <= 0) {
                break;
            }
            $atkSalvo = max(1, (int)round($af * (random_int(10, 35) / 100)));
            $defSalvo = max(1, (int)round($df * (random_int(10, 35) / 100)));

            $dmgToDef = $atkSalvo;
            if ($ds > 0) {
                $absorb = min($ds, $dmgToDef);
                $ds -= $absorb;
                $dmgToDef -= $absorb;
            }
            $df = max(0, $df - $dmgToDef);

            $dmgToAtk = $defSalvo;
            if ($as > 0) {
                $absorb = min($as, $dmgToAtk);
                $as -= $absorb;
                $dmgToAtk -= $absorb;
            }
            $af = max(0, $af - $dmgToAtk);

            $rounds[] = [
                'round' => $round,
                'attacker_salvo' => $atkSalvo,
                'defender_salvo' => $defSalvo,
                'attacker_fighters_left' => $af,
                'attacker_shields_left' => $as,
                'defender_fighters_left' => $df,
                'defender_shields_left' => $ds,
            ];
        }

        if ($df <= 0 && $af > 0) {
            $outcome = 'attacker_wins';
        } elseif ($af <= 0 && $df > 0) {
            $outcome = 'defender_wins';
        } elseif ($af <= 0 && $df <= 0) {
            $outcome = 'mutual_destruction';
        } else {
            $outcome = $af > $df ? 'attacker_wins' : 'defender_retreats';
        }

        return [
            'outcome' => $outcome,
            'attacker_fighters' => $af,
            'attacker_shields' => $as,
            'defender_fighters' => $df,
            'defender_shields' => $ds,
            'rounds' => $rounds,
        ];
    }
}
