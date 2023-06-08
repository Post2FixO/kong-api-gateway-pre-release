# Authenticated API Gateway - Securing microservices

## Introduction

This project aims to decrease the barrier to setting up streamlined, secure & highly available API endpoints for any configuration, from single applications to distributed microservices.

Handling API resources for each microservice separately is a recipe for failure. API Gateways can centralize and improve authentication, rate limiting, response caching, monitoring and much more, leaving our deployed services focused on their functionality. If our services are exclusively accessed through an API Gateway and calling our services doesn't present further vulnerabilities, our services can be considered secure.

An [OIDC Django application example](https://github.com/Post2FixO/Django-OIDC-KeyCloak-Kong) that utilizes this stack, based on the audited [mozilla-django-oidc](https://github.com/mozilla/mozilla-django-oidc) library, is available. We are planning to add further examples for React and other frameworks to make this configuration more accessible.

_Warning_! The _docker-compose.yml_ file still contains hard-coded default credentials, encryption between systems isn't yet enabled so this installation is currently a POC and _not production-ready_. Our next goal is to get there so contributions are very welcome while we work to fix these main issues.

## Credits

The [kong-konga-keycloak](https://github.com/d4rkstar/kong-konga-keycloak) repository by [d4rkstar](https://github.com/d4rkstar) provided a more complete stack (that included Konga) that deployed after some work. He credits the article, [Securing APIs with Kong and Keycloak - Part 1](https://www.jerney.io/secure-apis-kong-keycloak-1/), by Joshua A Erney. 

The repo was 1-2 years dormant and broken. This project is also a departure because our aim is to serve a complete and deployable ecosystem, including example apps that utilize this stack.

### Requirements

- [**docker**](https://docs.docker.com/install/) (with [**docker-compose**](https://docs.docker.com/compose/overview/))
- [**jq**](https://stedolan.github.io/jq/). jq allows for JSON files to show up nicely in the terminal as installation output
- [Python3](https://docs.python-guide.org/starting/install3/linux/) (it's probably already installed)
- Konga does not run on Apple Silicone yet. Update if this changes
- Ensure that none of the ports used in the docker-compose.yml file are in use. You can stop the containers that are occupying our ports or change them in the script but this can be confusing.

### Installed versions

- Kong 2.7.1 - alpine
- Konga 0.14.7
- Keycloak latest

## Deployment

- Ensure above requirements
- Get and run the code
    - Clone the repo onto the host
    - Browse to the folder where the repo was cloned
    - Switch to the root user (See ['Manage Docker as a non root user'](https://docs.docker.com/engine/install/linux-postinstall/#manage-docker-as-a-non-root-user))
        ```
        sudo su
        ```
    - Run the begin.sh script
        ```
        source begin.sh
        ```
        

## Configure a mock API service
Run the following commands on the host directly 

#### Create a service
```
curl -s -X POST http://localhost:8001/services \
    -d name=mock-service \
    -d url=http://mockbin.org/request \
    | jq
```

#### Create the route (paste the 'id' output from the previous command)
```
curl -s -X POST http://localhost:8001/services/<paste here the ‘id’ from previous response>/routes -d "paths[]=/mock" \
    | python3 -mjson.tool
```

To verify that everything is working. Run in terminal
```
curl -s http://localhost:8000/mock
```

#### Expected response
```
  "startedDateTime": ...,
  "clientIPAddress": ...,
  "method": "GET",
  "url": "http://localhost/request",
  "httpVersion": ...,
  ...
```

## Configure KeyCloak (from a browser on another computer on the host's network)
    
- Reach your KeyCloak instance
    - Browse to the KeyCloak instance at - http://< Host IP>:8180
    - Login using the credentials from the docker-compose.yml file (if you need any security, change those credentials at this stage)
- Add realm
    - After login, click "Add Realm": (dropdown menu that says ‘Master’ on the upper left corner)
    - Realm name = kong
    - save it

- You’ll be redirected to the new realm. We need to add two clients:
    
    - Setup Kong client (OIDC plugin)
        - Go to 'Clients' tab
        - Click ‘Create client’
            - Client_id = kong
        - Click next
            - Client Authentication = true
            - Service account roles = true
        - Click next
            - Root URL = http://localhost:8000
            = Valid Redirect URI = /mock/*
        - Save it
        - [Enable OIDC scope](https://github.com/Post2FixO/authenticated-api-gateway/blob/main/README.md#connecting-your-own-application)

    - Setup Apllication client
        - Go to Clients
            - Click ‘Create client’
                - Client ID = myapp
            - Click next twice
                - Valid redirect URIs = myapp

- Create a user
    - username = demouser
    - password = demouser
    - Name = Demo User
    - Email = anything
    - Email verified = true
- Save
- Go to the credentials tab
    - Click Set password
        - password: demouser
    - Temporary = false
    - Save twice

    

## Configure the Konga UI
Before we can run this command we need to set up some bash variables. Run in terminal:

- Get kong OIDC client secret
    - get the client secret from the 'Credentials' tab of the first OIDC client we created from:
        ```
        http://<Host IP>:8180/admin/master/console/#/kong/clients/8543fb37-f39c-468b-91f7-7f3989df58a6/credentials
        ```
    - (unhide and copy)

- Setup your environment variables
```
CLIENT_SECRET=<copied OIDC Client secret>
REALM=kong
HOST_IP=<the local IP of the KeyCloak host machine>
```
- Then run this command on the host
```
curl -s -X POST http://localhost:8001/plugins \
  -d name=oidc \
  -d config.client_id=kong \
  -d config.client_secret=${CLIENT_SECRET} \
  -d config.bearer_only=yes \
  -d config.realm=${REALM} \
  -d config.introspection_endpoint=http://${HOST_IP}:8180/realms/${REALM}/protocol/openid-connect/token/introspect \
  -d config.discovery=http://${HOST_IP}:8180/auth/realms/${REALM}/.well-known/openid-configuration \
  | jq
```
    
#### Run final test
```
curl "http://${HOST_IP}:8000/mock" \
-H "Accept: application/json" -I
```

#### Expected output
```
-H "Accept: application/json" -I
HTTP/1.1 401 Unauthorized
Date: Sat, 03 Jun 2023 19:55:32 GMT
Connection: keep-alive
WWW-Authenticate: Bearer realm="kong",error="no Authorization header found"
X-Kong-Response-Latency: 59
Server: kong/2.8.1
```

### Connect Kong and Konga
- Reach the Konga UI
    ```
    http://<Host IP>:1337/
    ```
- Create the admin user
- In Konga UI, select 'CONNECTIONS'
- Select ‘Create Connection’
    - Under ‘DEFAULT’
        - Name = kong
        - Kong Admin URL = http://kong:8001
        - Press ‘CREATE CONNECTION’	
        - Press ‘ACTIVATE’	

## Test with Postman

- Create a POST request to:
    ```
    http://<Docker host local IP>:8180/realms/kong/protocol/openid-connect/token
    ```
    - Body key / values
        - username   - demouser
        - password   - demouser
        - grant_type - password
        - client_id  - myapp
- Create a GET request to:
    - <Docker host local IP>:8000/mock
    - Headers key / values
        - Accept - ‘application/json’
        - Authorization - ‘Bearer <output token from POST request>’

## Connecting your own Application

A user's directory metadata (e.g. name) and access token are obtained through Rest API calls to the OIDC client in our KeyCloak realm (e.g. myapp).

The user's metadata can be stored and used by our application and the access token authenticates the users calls through the API Gateway.

```
http://{host}:8180/realms/{realm}/protocol/openid-connect/userinfo
```

We will recieve an error if our OIDC KeyCloak client isn't in a users scope. To enable it, go to the 'Client Scopes' tab and enable 'openid'

![Client scopes](https://github.com/Post2FixO/authenticated-api-gateway/assets/4726774/8865c03a-b5c6-46c6-bfcd-a58fecd46eaa)

Next, to scope openid to your client, go to the 'Clients' tab > myapp client > 'Client scopes' tab > enable openid
![Client scopes](https://github.com/Post2FixO/authenticated-api-gateway/assets/4726774/435af4f9-3cd1-44e3-90af-f0adf90d3615)

You can test your configuration with PostMan or with direct curl requests before integrating it into your application [(**curl** cheatsheet](https://devhints.io/curl))
