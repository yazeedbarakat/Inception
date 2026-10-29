    .PHONY: all down clean fclean re

all:
	mkdir -p /home/ybarakat/data/mariadb
	mkdir -p /home/ybarakat/data/wordpress
	docker compose -f ./srcs/docker-compose.yml up -d --build

down:
	docker compose -f ./srcs/docker-compose.yml down

clean:
	docker compose -f ./srcs/docker-compose.yml down --rmi all -v

fclean: clean
	sudo rm -rf /home/ybarakat/data/mariadb/*
	sudo rm -rf /home/ybarakat/data/wordpress/*

re: fclean all
