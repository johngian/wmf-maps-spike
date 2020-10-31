mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
mkfile_dir := $(dir $(mkfile_path))

PHONY: help

help:
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

docker_build: ## Build docker images
	docker-compose build
	docker build -f dist/osm-init.Dockerfile -t osm-init:latest $(mkfile_dir)

docker_pull: ## Pull docker images
	docker-compose pull

docker_up: docker_build docker_pull ## Bring services up
	docker-compose up -d

prepare_db: docker_up ## Download pbf and load data using imposm3
	docker run --network host osm-init:latest wait-for-it 127.0.0.1:5432
	docker run --network host --env-file $(mkfile_dir).env \
			-v $(mkfile_dir)data/pbf:/srv/pbf \
			-v $(mkfile_dir)config/imposm_mapping.yml:/etc/imposm/mapping.yml \
			-v $(mkfile_dir)sql:/srv/sql \
			osm-init:latest osm-initial-import $(ARGS)

all: docker_up prepare_db

clean:
	docker-compose stop
	docker-compose rm
	sudo git clean -fdx ./data
