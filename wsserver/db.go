package main

import (
	"database/sql"
	"log"
	"os"
	"time"

	_ "github.com/go-sql-driver/mysql"
)

func mustOpenDB() *sql.DB {
	dsn := os.Getenv("TW_DB_DSN")
	if dsn == "" {
		dsn = "tradewars:@tcp(127.0.0.1:3306)/tradewars?parseTime=true"
	}
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		log.Fatalf("db open: %v", err)
	}
	db.SetMaxOpenConns(10)
	db.SetConnMaxLifetime(time.Hour)
	if err := db.Ping(); err != nil {
		log.Fatalf("db ping: %v", err)
	}
	return db
}

// Player is the minimal player identity we need for presence + auth.
type Player struct {
	ID       int
	UserID   int
	Handle   string
	SectorID int
	CorpID   sql.NullInt64
}

func lookupPlayerByToken(db *sql.DB, token string) (*Player, error) {
	row := db.QueryRow(`
		SELECT p.id, p.user_id, p.handle, p.sector_id, p.corporation_id
		FROM sessions s
		JOIN players p ON p.user_id = s.user_id
		WHERE s.token_hash = SHA2(?, 256) AND s.expires_at > NOW()
	`, token)
	var p Player
	if err := row.Scan(&p.ID, &p.UserID, &p.Handle, &p.SectorID, &p.CorpID); err != nil {
		return nil, err
	}
	return &p, nil
}

func refreshPlayerSector(db *sql.DB, playerID int) (int, error) {
	var sectorID int
	err := db.QueryRow(`SELECT sector_id FROM players WHERE id = ?`, playerID).Scan(&sectorID)
	return sectorID, err
}
