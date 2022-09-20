package cache_reader

import (
	"context"
	"fmt"
	"time"

	"github.com/go-redis/redis/v8"
)

func ReadFromCache(ctx context.Context, rdb *redis.Client) {
	fmt.Println("ReadFromChache()")

	var timeDelay = 1
	ticker := time.NewTicker(time.Duration(timeDelay) * time.Second)
	// ead immediately before the timer
	readCache(ctx, rdb)
	for _ = range ticker.C {
		// Timer has fired. Read the cache
		readCache(ctx, rdb)
	}
	fmt.Printf("ERROR: ReadFromCache exited thread incorrectly")
}

func readCache(ctx context.Context, rdb *redis.Client) {

	key := "key"
	val, err := rdb.Get(ctx, key).Result()
	if err != nil {
		fmt.Println("Key \"", key, "\" returned no result.")
	}
	fmt.Println("Result: {\"", key, "\"}:{\"", val, "\"}")
}
