docker compose build kong
docker compose up -d kong-db
docker compose run --rm kong kong migrations bootstrap
docker compose run --rm kong kong migrations up
docker compose up -d kong
curl -s http://localhost:8001 | jq .plugins.available_on_server.oidc
docker compose up -d konga
sleep 90s
docker compose up -d keycloak-db
docker compose up -d keycloak
