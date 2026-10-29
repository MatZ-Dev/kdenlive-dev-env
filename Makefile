.PHONY: build
build:                ## Build arch-env image (build/debug from host Qt Creator)
build:
	docker compose build

.PHONY: shell
shell:                ## Drop into the arch-env container
shell:
	xhost +local:docker >/dev/null
	docker compose run --rm kdenlive-arch-env

.PHONY: build-all-in-one
build-all-in-one:     ## Build all-in-one image (Qt Creator inside container)
build-all-in-one:
	docker build -t kdenlive-dev docker/all-in-one-dev

.PHONY: start
start:                ## Start all-in-one container
start:
	./shell.sh
