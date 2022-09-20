# Copyright 2022 Bryon Baker

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

clean:
	rm bin/redis-tester

build:
	go build -o bin/redis-tester cmd/main.go

package-reader: clean build
	podman build . -f Read-Dockerfile -t quay.io/brbaker/redis-read-tester:latest

package-writer: clean build
	podman build . -f Write-Dockerfile -t quay.io/brbaker/redis-write-tester:latest

test: clean build
	echo "Tsk tsk! make test is not implemented yet."

all: clean build