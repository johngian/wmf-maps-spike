mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
mkfile_dir := $(dir $(mkfile_path))

PHONY: help

help:
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

vendor: ## Fetch vendored dependencies
	git submodule init
	git submodule update

docker_build: ## Build docker images
	docker-compose build

docker_pull: ## Pull docker images
	docker-compose pull

bootstrap_env: ## Prepare environment variables
	cp $(mkfile_dir)dist/env-example $(mkfile_dir).env

run_services: vendor bootstrap_env docker_build docker_pull ## Bring services up
	docker-compose up -d postgis
	docker-compose run --service-ports bootstrap wait-for-it postgis:5432
	docker-compose up -d tegola tileserver-gl

bootstrap: run_services ## Download pbf and load data using imposm3
	docker-compose up bootstrap

clean:
	docker-compose stop
	docker-compose rm
	sudo git clean -fdx ./data
