package utils

import (
	"context"
	"fmt"
	"log"
	"strconv"

	"github.com/go-redis/redis/v8"
)

func ConnectRedis(config *map[string]string) (context.Context, *redis.Client) {
	ctx := context.Background()

	db, err := strconv.Atoi((*config)["database"])
	if err != nil {
		log.Fatal("Error converting database from config to integer")
	}
	rdb := redis.NewClient(&redis.Options{
		Addr:     (*config)["server-address"],
		Password: (*config)["db-password"], // no password set
		DB:       db,
	})

	fmt.Println("Reddis connection: ", rdb)
	fmt.Println("Context:", ctx)

	return ctx, rdb
}
