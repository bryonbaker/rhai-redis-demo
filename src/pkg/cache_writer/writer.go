package cache_writer

import (
	"context"
	"fmt"

	"github.com/go-redis/redis/v8"
	"github.com/tjarratt/babble"
)

func WriteToCache(ctx context.Context, rdb *redis.Client) {
	fmt.Println("WriteToChache()")

	key := "key"
	value := generatePhrase()
	err := rdb.Set(ctx, key, value, 0).Err()
	if err != nil {
		panic(err)
	}
	fmt.Println("Write successful: {\"", key, "\"}:{\"", value, "\"}")

}

func generatePhrase() string {
	babbler := babble.NewBabbler()

	return babbler.Babble()
}
