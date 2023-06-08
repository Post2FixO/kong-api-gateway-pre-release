#!/bin/bash

# Build the Kong image
docker-compose build kong

# Start the Kong database container
docker-compose up -d kong-db

# Bootstrap Kong migrations
docker-compose run --rm kong kong migrations bootstrap

# Run Kong migrations
docker-compose run --rm kong kong migrations up

# Start the Kong service
docker-compose up -d kong

# Check the available Kong plugins
curl -s http://localhost:8001 | jq .plugins.available_on_server.oidc

# Start the Konga UI
docker-compose up -d konga

# Wait for the services to fully start up (adjust sleep duration as needed)
sleep 90s

# Start the Keycloak database container
docker-compose up -d keycloak-db

# Start the Keycloak service
docker-compose up -d keycloak

# After modifications, ensure start.sh has executable permissions (chmod +x start.sh) and test the script to verify that it starts services as expected
