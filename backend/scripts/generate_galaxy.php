<?php
declare(strict_types=1);

/**
 * Galaxy generator / reseed script.
 *
 * Usage: php generate_galaxy.php [sector_count] [--wipe]
 *
 * Builds a connected warp graph (random spanning tree + extra random edges),
 * scatters ports (all 8 classic buy/sell class combinations), unclaimed
 * planets, and a handful of starting NPC hostiles. Sector 1 is always the
 * Federation homeworld / Stardock.
 */

require __DIR__ . '/../src/bootstrap.php';

use TradeWars\Core\DB;

$count = (int)($argv[1] ?? 500);
$wipe = in_array('--wipe', $argv, true);
$count = max(50, min(5000, $count));

$db = DB::conn();

if ($wipe) {
    fwrite(STDERR, "Wiping existing galaxy data...\n");
    $db->exec('SET FOREIGN_KEY_CHECKS = 0');
    foreach (['mines', 'npc_ships', 'planets', 'ports', 'warps', 'combat_log', 'events_log', 'sectors'] as $t) {
        $db->exec("TRUNCATE TABLE {$t}");
    }
    $db->exec('SET FOREIGN_KEY_CHECKS = 1');
} else {
    $existing = (int)$db->query('SELECT COUNT(*) FROM sectors')->fetchColumn();
    if ($existing > 0) {
        fwrite(STDERR, "Galaxy already has {$existing} sectors. Re-run with --wipe to regenerate.\n");
        exit(1);
    }
}

fwrite(STDERR, "Generating {$count} sectors...\n");

$cols = (int)ceil(sqrt($count));
$spacing = 140;

$db->beginTransaction();

$sectorStmt = $db->prepare(
    'INSERT INTO sectors (id, name, x, y, region, is_federation, has_port, hazard) VALUES (:id, :name, :x, :y, :region, :fed, :port, :hazard)'
);

for ($i = 1; $i <= $count; $i++) {
    $row = intdiv($i - 1, $cols);
    $col = ($i - 1) % $cols;
    $x = $col * $spacing + random_int(-30, 30);
    $y = $row * $spacing + random_int(-30, 30);
    $isFed = $i === 1;
    $hazard = !$isFed && random_int(1, 100) <= 8;
    $region = $isFed ? 'federation' : ($hazard ? 'nebula' : 'deep_space');

    $sectorStmt->execute([
        'id' => $i,
        'name' => $isFed ? 'Sol — Federation Space' : null,
        'x' => $x, 'y' => $y,
        'region' => $region,
        'fed' => $isFed ? 1 : 0,
        'port' => 0, // set true below once we know
        'hazard' => $hazard ? 1 : 0,
    ]);
}

// --- Warp graph: randomized spanning tree over a shuffled sector order,
// guaranteeing full connectivity, then extra random edges for density. ---
fwrite(STDERR, "Weaving warp lanes...\n");

$order = range(1, $count);
shuffle($order);
$adj = array_fill(1, $count, []);

for ($i = 1; $i < $count; $i++) {
    $a = $order[$i];
    // connect to a random *already placed* node to keep the tree connected
    $b = $order[random_int(0, $i - 1)];
    $adj[$a][$b] = true;
    $adj[$b][$a] = true;
}

// extra random edges — bias toward geometrically nearby sectors
$stmt = $db->query('SELECT id, x, y FROM sectors ORDER BY id');
$coords = [];
foreach ($stmt->fetchAll() as $r) {
    $coords[(int)$r['id']] = [(int)$r['x'], (int)$r['y']];
}

$extraEdges = (int)($count * 1.6);
for ($e = 0; $e < $extraEdges; $e++) {
    $a = random_int(1, $count);
    // pick from a small random sample, choose the geometrically closest as candidate
    $best = null;
    $bestDist = PHP_INT_MAX;
    for ($try = 0; $try < 6; $try++) {
        $b = random_int(1, $count);
        if ($b === $a || isset($adj[$a][$b])) {
            continue;
        }
        $dx = $coords[$a][0] - $coords[$b][0];
        $dy = $coords[$a][1] - $coords[$b][1];
        $dist = $dx * $dx + $dy * $dy;
        if ($dist < $bestDist) {
            $bestDist = $dist;
            $best = $b;
        }
    }
    if ($best !== null && count($adj[$a]) < 8 && count($adj[$best]) < 8) {
        $adj[$a][$best] = true;
        $adj[$best][$a] = true;
    }
}

$warpStmt = $db->prepare('INSERT IGNORE INTO warps (from_sector, to_sector) VALUES (:f, :t)');
foreach ($adj as $from => $tos) {
    foreach (array_keys($tos) as $to) {
        $warpStmt->execute(['f' => $from, 't' => $to]);
    }
}

// --- Ports: Stardock at sector 1, plus ~35% of other sectors ---
fwrite(STDERR, "Building ports...\n");

$portStmt = $db->prepare(
    'INSERT INTO ports (sector_id, name, class, fuel_ore_qty, fuel_ore_price, fuel_ore_mode,
     organics_qty, organics_price, organics_mode, equipment_qty, equipment_price, equipment_mode, credits)
     VALUES (:s, :n, :c, :foq, :fop, :fom, :oq, :op, :om, :eq, :ep, :em, :cr)'
);
$markHasPort = $db->prepare('UPDATE sectors SET has_port = 1 WHERE id = :id');

$portNamesPrefix = ['Trading Post', 'Exchange', 'Bazaar', 'Depot', 'Free Port', 'Outpost', 'Terminal', 'Emporium'];
$portNamesSuffix = ['Alpha', 'Prime', 'Station', 'Nine', 'Reach', 'Point', 'Gate', 'Anchorage', 'Junction'];

function portMode(int $class, int $bit): string
{
    // 3-bit class-1 encodes buy(1)/sell(0) per commodity: bit2=fuel, bit1=organics, bit0=equipment
    return (($class - 1) >> $bit) & 1 ? 'buy' : 'sell';
}

// Sector 1: special Stardock, always sells everything (class-like, but forced 'sell' all)
$portStmt->execute([
    's' => 1, 'n' => 'Stardock Prime', 'c' => 0,
    'foq' => 20000, 'fop' => 45, 'fom' => 'sell',
    'oq' => 20000, 'op' => 110, 'om' => 'sell',
    'eq' => 20000, 'ep' => 170, 'em' => 'sell',
    'cr' => 50000000,
]);
$markHasPort->execute(['id' => 1]);

for ($i = 2; $i <= $count; $i++) {
    if (random_int(1, 100) > 35) {
        continue;
    }
    $class = random_int(1, 8);
    $name = $portNamesPrefix[array_rand($portNamesPrefix)] . ' ' . $portNamesSuffix[array_rand($portNamesSuffix)];

    $portStmt->execute([
        's' => $i, 'n' => $name, 'c' => $class,
        'foq' => random_int(3000, 15000), 'fop' => random_int(30, 70), 'fom' => portMode($class, 2),
        'oq' => random_int(3000, 15000), 'op' => random_int(80, 160), 'om' => portMode($class, 1),
        'eq' => random_int(3000, 15000), 'ep' => random_int(150, 300), 'em' => portMode($class, 0),
        'cr' => random_int(200000, 2000000),
    ]);
    $markHasPort->execute(['id' => $i]);
}

// --- Planets: ~10% of non-federation sectors, unclaimed ---
fwrite(STDERR, "Scattering planets...\n");

$planetStmt = $db->prepare(
    'INSERT INTO planets (sector_id, name, type, colonists, max_colonists, fighters, citadel_level, fuel_ore_stock, organics_stock, equipment_stock)
     VALUES (:s, :n, :t, 0, :maxc, 0, 0, 0, 0, 0)'
);
$planetTypes = ['class_m', 'class_k', 'class_o', 'class_h', 'class_c'];
$planetPrefixes = ['New', 'Old', 'Fort', 'Port', 'Nova', 'Terra'];
$planetSuffixes = ['Haven', 'Reach', 'Hope', 'Landing', 'Rock', 'World', 'Station'];

for ($i = 2; $i <= $count; $i++) {
    if (random_int(1, 100) > 10) {
        continue;
    }
    $name = $planetPrefixes[array_rand($planetPrefixes)] . ' ' . $planetSuffixes[array_rand($planetSuffixes)];
    $planetStmt->execute([
        's' => $i, 'n' => $name,
        't' => $planetTypes[array_rand($planetTypes)],
        'maxc' => random_int(1000000, 8000000),
    ]);
}

// --- A handful of starting NPC hostiles ---
fwrite(STDERR, "Deploying hostiles...\n");

$npcStmt = $db->prepare(
    'INSERT INTO npc_ships (kind, name, sector_id, fighters, shields, bounty_credits, aggressive) VALUES (:k, :n, :s, :f, :sh, :b, :agg)'
);
$ferrengiNames = ['Ferrengi Marauder', 'Ferrengi Corsair', 'Ferrengi Raider', 'Ferrengi Privateer'];
$monsterNames = ['Void Kraken', 'Ion Storm Entity', 'Derelict Automaton', 'Star Leviathan'];
$traderNames = ['Wandering Merchant', 'Salvage Hulk', 'Abandoned Freighter', 'Lost Trader'];

// A lively galaxy from the first login: roughly 1 in 8 sectors starts with
// a hostile or salvage target. The Go event engine keeps spawning (and
// roaming) more over time, capped at ~15% sector density.
$npcCount = max(40, (int)($count * 0.12));
for ($i = 0; $i < $npcCount; $i++) {
    $sector = random_int(2, $count);
    $roll = random_int(1, 100);
    $kind = $roll <= 45 ? 'ferrengi_raider' : ($roll <= 80 ? 'space_monster' : 'alien_trader');
    $names = ['ferrengi_raider' => $ferrengiNames, 'space_monster' => $monsterNames, 'alien_trader' => $traderNames][$kind];
    $npcStmt->execute([
        'k' => $kind,
        'n' => $names[array_rand($names)],
        's' => $sector,
        'f' => $kind === 'alien_trader' ? random_int(20, 60) : random_int(80, 400),
        'sh' => $kind === 'alien_trader' ? random_int(10, 30) : random_int(50, 200),
        'b' => $kind === 'alien_trader' ? random_int(1000, 6000) : random_int(300, 2500),
        'agg' => $kind === 'alien_trader' ? 0 : 1,
    ]);
}

$db->commit();

fwrite(STDERR, "Done. {$count} sectors generated.\n");
