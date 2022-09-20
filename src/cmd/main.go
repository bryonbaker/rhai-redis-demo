package main

import (
	"context"
	"fmt"
	"log"
	"os"

	"bakerapps.net/redis-demo/pkg/cache_reader"
	"bakerapps.net/redis-demo/pkg/cache_writer"
	"bakerapps.net/redis-demo/pkg/utils"
	"github.com/go-redis/redis/v8"
)

// Global variables to package
var config map[string]string

var ctx context.Context
var rdb *redis.Client

func init() {
	fmt.Println("Loading configuration")

	config = utils.ReadConfig("./config/app-config.properties")
	fmt.Println(config)

	ctx, rdb = utils.ConnectRedis(&config)
}

func main() {
	if len(os.Args) <= 1 {
		log.Fatal("Invalid number of arguments")
	}

	switch os.Args[1] {
	case "--write":
		cacheWriter()
	case "--read":
		cacheReader()
	default:
		log.Fatal("Unknown command line arg")
	}
}

func cacheWriter() {
	fmt.Println("Cache Writer")

	cache_writer.WriteToCache(ctx, rdb)
}

func cacheReader() {
	fmt.Println("Redis Reader")

	cache_reader.ReadFromCache(ctx, rdb)
}
