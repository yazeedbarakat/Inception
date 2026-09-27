up:
	mkdir -p /home/ybarakat/data/mariadb
	mkdir -p /home/ybarakat/data/wordpress
	docker compose up -d --build

down:
	docker compose down

clean: down
	docker compose down --rmi up -v

fclean: clean
	sudo rm -rf /home/ybarakat/data/mariadb/*
	sudo rm -rf /home/ybarakat/data/wordpress/*
	docker system prune -af --volumes

re: fclean up
