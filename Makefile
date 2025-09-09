NAME = inception
DOCKER_COMPOSE_FILE = ./docker-compose.yml

.PHONY: all up down clean re logs

all: up

up:
	mkdir -p ~/data2/wordpress
	mkdir -p ~/data2/mariadb
	docker compose -f $(DOCKER_COMPOSE_FILE) up -d

down:
	docker compose -f $(DOCKER_COMPOSE_FILE) down

clean: down
	docker system prune -a

fclean: clean
	docker volume rm $$(docker volume ls -q) 2>/dev/null || true
	rm -rf /data2/wordpress/*
	rm -rf /data2/mariadb/*

re: fclean up

logs:
	docker compose -f $(DOCKER_COMPOSE_FILE) logs -f