package main

import (
	"database/sql"
	"log"
	"time"
)

// pollEvents tails events_log and fans new rows out over the hub — this is
// how ambient random events, combat results, and planet claims that PHP (or
// this server's own event engine) writes reach connected clients in real time.
func pollEvents(db *sql.DB, hub *Hub) {
	var lastID int64
	if err := db.QueryRow(`SELECT COALESCE(MAX(id),0) FROM events_log`).Scan(&lastID); err != nil {
		log.Printf("pollEvents init: %v", err)
	}

	ticker := time.NewTicker(1500 * time.Millisecond)
	defer ticker.Stop()
	for range ticker.C {
		rows, err := db.Query(
			`SELECT id, event_type, sector_id, player_id, title, message, data, created_at
			 FROM events_log WHERE id > ? ORDER BY id ASC LIMIT 100`, lastID)
		if err != nil {
			log.Printf("pollEvents query: %v", err)
			continue
		}
		for rows.Next() {
			var (
				id                    int64
				eventType, title, msg string
				sectorID, playerID    sql.NullInt64
				data                  sql.NullString
				createdAt             time.Time
			)
			if err := rows.Scan(&id, &eventType, &sectorID, &playerID, &title, &msg, &data, &createdAt); err != nil {
				continue
			}
			lastID = id

			out := OutMessage{
				"type": "event", "id": id, "event_type": eventType,
				"title": title, "message": msg, "created_at": createdAt.Format(time.RFC3339),
			}
			if sectorID.Valid {
				out["sector_id"] = sectorID.Int64
			}
			if playerID.Valid {
				out["player_id"] = playerID.Int64
			}
			if data.Valid {
				out["data"] = data.String
			}

			if sectorID.Valid {
				hub.BroadcastSector(int(sectorID.Int64), out)
			} else {
				hub.BroadcastAll(out)
			}
		}
		rows.Close()
	}
}

// pollChat tails chat_messages so galaxy/sector/corp chat is broadcast
// consistently regardless of whether it originated over REST or WS.
func pollChat(db *sql.DB, hub *Hub) {
	var lastID int64
	if err := db.QueryRow(`SELECT COALESCE(MAX(id),0) FROM chat_messages`).Scan(&lastID); err != nil {
		log.Printf("pollChat init: %v", err)
	}

	ticker := time.NewTicker(1 * time.Second)
	defer ticker.Stop()
	for range ticker.C {
		rows, err := db.Query(
			`SELECT id, scope, sector_id, corporation_id, player_id, handle, message, created_at
			 FROM chat_messages WHERE id > ? ORDER BY id ASC LIMIT 200`, lastID)
		if err != nil {
			log.Printf("pollChat query: %v", err)
			continue
		}
		for rows.Next() {
			var (
				id                     int64
				scope, handle, message string
				sectorID, corpID       sql.NullInt64
				playerID               int
				createdAt              time.Time
			)
			if err := rows.Scan(&id, &scope, &sectorID, &corpID, &playerID, &handle, &message, &createdAt); err != nil {
				continue
			}
			lastID = id

			out := OutMessage{
				"type": "chat", "id": id, "scope": scope, "player_id": playerID,
				"handle": handle, "message": message, "created_at": createdAt.Format(time.RFC3339),
			}

			switch scope {
			case "sector":
				if sectorID.Valid {
					hub.BroadcastSector(int(sectorID.Int64), out)
				}
			case "corp":
				if corpID.Valid {
					broadcastCorp(db, hub, int(corpID.Int64), out)
				}
			default:
				hub.BroadcastAll(out)
			}
		}
		rows.Close()
	}
}

func broadcastCorp(db *sql.DB, hub *Hub, corpID int, out OutMessage) {
	rows, err := db.Query(`SELECT player_id FROM corporation_members WHERE corporation_id = ?`, corpID)
	if err != nil {
		return
	}
	defer rows.Close()
	for rows.Next() {
		var pid int
		if rows.Scan(&pid) == nil {
			hub.SendToPlayer(pid, out)
		}
	}
}
