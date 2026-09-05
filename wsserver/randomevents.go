package main

import (
	"database/sql"
	"encoding/json"
	"log"
	"math/rand"
	"strconv"
	"time"
)

var itoa = strconv.Itoa

var ferrengiNames = []string{"Ferrengi Marauder", "Ferrengi Corsair", "Ferrengi Raider", "Ferrengi Privateer", "Ferrengi Interceptor"}
var monsterNames = []string{"Void Kraken", "Ion Storm Entity", "Derelict Automaton", "Star Leviathan", "Nebula Wraith"}
var traderNames = []string{"Wandering Merchant", "Salvage Hulk", "Abandoned Freighter", "Lost Trader"}

// maxNpcDensity caps standing hostiles at roughly this fraction of sectors,
// so a long-uptime galaxy stays exciting without becoming absurd.
const maxNpcDensity = 0.15

// runEventEngine periodically fires a random galaxy event: raider spawns,
// monster sightings, raider packs, price shocks, derelict salvage
// opportunities, neutral mine fields, and ambient NPC roaming. Every
// notable event is written to events_log (picked up and broadcast by
// pollEvents) so REST-polling and offline clients see it too.
func runEventEngine(db *sql.DB, hub *Hub) {
	r := rand.New(rand.NewSource(time.Now().UnixNano()))
	for {
		wait := time.Duration(15+r.Intn(30)) * time.Second
		time.Sleep(wait)

		sectorCount, err := maxSectorID(db)
		if err != nil || sectorCount < 2 {
			continue
		}

		npcCount, err := currentNpcCount(db)
		if err != nil {
			continue
		}
		belowCap := float64(npcCount) < float64(sectorCount)*maxNpcDensity

		switch r.Intn(8) {
		case 0:
			if belowCap {
				spawnHostile(db, r, sectorCount, "ferrengi_raider", ferrengiNames, 80, 400, 300, 2500)
			}
		case 1:
			if belowCap {
				spawnHostile(db, r, sectorCount, "space_monster", monsterNames, 150, 600, 500, 4000)
			}
		case 2:
			priceShock(db, r, sectorCount)
		case 3:
			if belowCap {
				spawnHostile(db, r, sectorCount, "alien_trader", traderNames, 20, 60, 1000, 6000)
			}
		case 4:
			mineField(db, r, sectorCount)
		case 5:
			if belowCap {
				raiderPack(db, r, sectorCount)
			}
		case 6, 7:
			roamNpcs(db, r)
		}
	}
}

func currentNpcCount(db *sql.DB) (int, error) {
	var n int
	err := db.QueryRow(`SELECT COUNT(*) FROM npc_ships`).Scan(&n)
	return n, err
}

// raiderPack spawns a small cluster of raiders together in one sector for a
// tougher, more dramatic encounter than a lone hostile.
func raiderPack(db *sql.DB, r *rand.Rand, maxSector int) {
	sector := randomSector(r, maxSector)
	size := 2 + r.Intn(2)
	for i := 0; i < size; i++ {
		name := ferrengiNames[r.Intn(len(ferrengiNames))]
		fighters := 80 + r.Intn(320)
		shields := fighters / 2
		bounty := 300 + r.Intn(2200)
		db.Exec(
			`INSERT INTO npc_ships (kind, name, sector_id, fighters, shields, bounty_credits, aggressive) VALUES (?,?,?,?,?,?,1)`,
			"ferrengi_raider", name, sector, fighters, shields, bounty,
		)
	}
	title := "Raider pack detected"
	msg := "A pack of raiders has been spotted massing in sector " + itoa(sector) + ". Proceed with extreme caution."
	logEvent(db, "raider_pack_spawn", &sector, nil, title, msg, map[string]any{"size": size})
}

// roamNpcs nudges a few existing hostiles to an adjacent sector so the
// galaxy feels alive even between spawn events, instead of every NPC
// sitting frozen in the sector it was created in.
func roamNpcs(db *sql.DB, r *rand.Rand) {
	rows, err := db.Query(`SELECT id, sector_id FROM npc_ships ORDER BY RAND() LIMIT 5`)
	if err != nil {
		return
	}
	type npc struct{ id, sector int }
	var candidates []npc
	for rows.Next() {
		var n npc
		if rows.Scan(&n.id, &n.sector) == nil {
			candidates = append(candidates, n)
		}
	}
	rows.Close()

	// Deliberately not logged to events_log — this is ambient background
	// motion, not something worth a galaxy-wide notification.
	for _, n := range candidates {
		if r.Intn(2) == 0 {
			continue
		}
		var newSector int
		err := db.QueryRow(`SELECT to_sector FROM warps WHERE from_sector = ? ORDER BY RAND() LIMIT 1`, n.sector).Scan(&newSector)
		if err != nil {
			continue
		}
		db.Exec(`UPDATE npc_ships SET sector_id = ? WHERE id = ?`, newSector, n.id)
	}
}

func maxSectorID(db *sql.DB) (int, error) {
	var n int
	err := db.QueryRow(`SELECT COALESCE(MAX(id),0) FROM sectors`).Scan(&n)
	return n, err
}

func randomSector(r *rand.Rand, max int) int {
	// avoid Sector 1 (Federation safe zone)
	return 2 + r.Intn(max-1)
}

func spawnHostile(db *sql.DB, r *rand.Rand, maxSector int, kind string, names []string, fMin, fMax, bMin, bMax int) {
	sector := randomSector(r, maxSector)
	name := names[r.Intn(len(names))]
	fighters := fMin + r.Intn(fMax-fMin)
	shields := fighters / 2
	bounty := bMin + r.Intn(bMax-bMin)
	aggressive := 1
	if kind == "alien_trader" {
		aggressive = 0
	}

	_, err := db.Exec(
		`INSERT INTO npc_ships (kind, name, sector_id, fighters, shields, bounty_credits, aggressive) VALUES (?,?,?,?,?,?,?)`,
		kind, name, sector, fighters, shields, bounty, aggressive,
	)
	if err != nil {
		log.Printf("spawnHostile: %v", err)
		return
	}

	title := map[string]string{
		"ferrengi_raider": "Ferrengi raiders detected",
		"space_monster":   "Space monster sighted",
		"alien_trader":    "Derelict ship discovered",
	}[kind]
	msg := map[string]string{
		"ferrengi_raider": name + " has entered sector " + itoa(sector) + ". Approach with caution.",
		"space_monster":   name + " has been sighted in sector " + itoa(sector) + "!",
		"alien_trader":    name + " drifts silently in sector " + itoa(sector) + " — salvage it for a reward.",
	}[kind]

	logEvent(db, kind+"_spawn", &sector, nil, title, msg, map[string]any{"npc_kind": kind, "fighters": fighters, "bounty": bounty})
}

func priceShock(db *sql.DB, r *rand.Rand, maxSector int) {
	rows, err := db.Query(`SELECT id, sector_id FROM ports WHERE sector_id != 1 ORDER BY RAND() LIMIT 1`)
	if err != nil {
		return
	}
	defer rows.Close()
	if !rows.Next() {
		return
	}
	var portID, sectorID int
	rows.Scan(&portID, &sectorID)

	direction := 1.0
	verb := "spiked"
	if r.Intn(2) == 0 {
		direction = -1.0
		verb = "crashed"
	}
	pct := 0.15 + r.Float64()*0.25 // 15-40%
	factor := 1 + direction*pct

	_, err = db.Exec(
		`UPDATE ports SET fuel_ore_price = fuel_ore_price * ?, organics_price = organics_price * ?, equipment_price = equipment_price * ?
		 WHERE id = ?`, factor, factor, factor, portID,
	)
	if err != nil {
		log.Printf("priceShock: %v", err)
		return
	}

	title := "Cosmic storm rattles the markets"
	msg := "A cosmic storm has " + verb + " commodity prices at the port in sector " + itoa(sectorID) + "."
	logEvent(db, "cosmic_storm", &sectorID, nil, title, msg, map[string]any{"factor": factor})
}

func mineField(db *sql.DB, r *rand.Rand, maxSector int) {
	sector := randomSector(r, maxSector)
	qty := 2 + r.Intn(6)

	var existingID int
	err := db.QueryRow(`SELECT id FROM mines WHERE sector_id = ? AND owner_player_id IS NULL`, sector).Scan(&existingID)
	if err == nil {
		db.Exec(`UPDATE mines SET quantity = quantity + ? WHERE id = ?`, qty, existingID)
	} else {
		db.Exec(`INSERT INTO mines (sector_id, owner_player_id, quantity) VALUES (?, NULL, ?)`, sector, qty)
	}

	title := "Derelict mine field detected"
	msg := "Sensors have detected an unclaimed mine field drifting in sector " + itoa(sector) + ". Navigate carefully."
	logEvent(db, "mine_field", &sector, nil, title, msg, nil)
}

func logEvent(db *sql.DB, eventType string, sectorID *int, playerID *int, title, message string, data map[string]any) {
	var dataJSON any
	if data != nil {
		b, _ := json.Marshal(data)
		dataJSON = string(b)
	}
	_, err := db.Exec(
		`INSERT INTO events_log (event_type, sector_id, player_id, title, message, data) VALUES (?,?,?,?,?,?)`,
		eventType, sectorID, playerID, title, message, dataJSON,
	)
	if err != nil {
		log.Printf("logEvent: %v", err)
	}
}
