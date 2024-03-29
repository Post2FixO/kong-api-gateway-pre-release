# Authenticated API Gateway - Securing Microservices

This repo is temporary and is most likely not working due to a bunch of unbranched changes. A working repo is in the works and should be released soon under the same open source MIT license.

## Introduction

This is a barrier lowering 'get the basics working, easily' project. This repo provides a clean Kong based, Dockerized, open source API Gateway stack. Kong is built on the Nginx proxy which might be required in your stack.

- This stack is a 'bare bones' high performance API Gateway suitable for enterprize
- [Gluu](https://gluu.org/docs/gg/) is another option.  

### Why use API Gateways

When API calls to multiple micro-services pass through an API Gateway, it's easier to streamline API security, monitoring, rate limiting, access controls, response caching and more. It's impractical to implement and maintain these capabilities seperately for individual micro-services. An API Gateway lets developers of services focus on building clean and secure services instead of being bogged down by maintaining a web of duplicate software.

## Deplying the stack

### Requirements

- [**docker**](https://docs.docker.com/install/) (with [**docker-compose**](https://docs.docker.com/compose/overview/))
- [**jq**](https://stedolan.github.io/jq/) (for JSON formatting in the terminal)
- [Python3](https://docs.python-guide.org/starting/install3/linux/) (should be already installed)
- Konga does not run on Apple Silicone yet. Update if this changes
- Ensure that none of the ports used in the `docker-compose.yml` file are in use. You can stop containers that occupy ports or update the ports in the script

### Deployment steps

1. Clone the repository onto the host machine.
2. Browse to the folder where the repository was cloned.
3. Switch to the root user by running:
    ```shell
    sudo su
    ```
4. Run the `start.sh` script:
    ```shell
    source start.sh
    ```

## Configuration

### Configure a mock API service

Run the following commands directly on the host machine:

1. Create a service:
    ```shell
    curl -s -X POST http://localhost:8001/services \
        -d name=mock-service \
        -d url=http://mockbin.org/request \
        | jq
    ```

2. Create the route (paste the 'id' output from the previous command):
    ```shell
    curl -s -X POST http://localhost:8001/services/<paste-here-the-id-from-previous-response>/routes -d "paths[]=/mock" \
        | python3 -mjson.tool
    ```

3. To verify that everything is working, run the following command in the terminal:
    ```shell
    curl -s http://localhost:8000/mock
    ```

    Expected response:
    ```json
    {
        "startedDateTime": ...,
        "clientIPAddress": ...,
        "method": "GET",
        "url": "http://localhost/request",
        "httpVersion": ...,
        ...
    }
    ```

### Configure KeyCloak

Access the KeyCloak instance from a browser on another computer on the host's network:

- Browse to the KeyCloak instance at http://<Host IP>:8180.
- Login using the credentials from the `docker-compose.yml` file (if you need any security, change those credentials at this stage).
- Follow the steps below to set up KeyCloak.

#### Add Realm

- After login, click "Add Realm" (dropdown menu that says 'Master' on the upper left corner).
- Realm name: kong.
- Save it.

#### Setup Kong Client (OIDC plugin)

- Go to the 'Clients' tab.
- Click 'Create client':
  - Client ID: kong.
  - Click next.
  - Client Authentication: true.
  - Service account roles: true.
  - Click next.
  - Root URL: http://localhost:8000.
  - Valid Redirect URI: /mock/\*.
  - Save it.
  - [Enable OIDC scope](https://github.com/Post2FixO/authenticated-api-gateway/blob/main/README.md#connecting-your-own-application)

#### Setup Application Client

- Go to Clients.
- Click 'Create client':
  - Client ID: myapp.
  - Click next twice.
  - Valid redirect URIs: myapp.

#### Create a user

- Username: demouser.
- Password: demouser.
- Name: Demo User.
- Email: anything.
- Email verified: true.
- Save it.
- Go to the credentials tab.
- Click 'Set password':
  - Password: demouser.
  - Temporary: false.
  - Save twice.

### Configure the Konga UI

Before running the following command, set up the required bash variables. Run the following command on the host:

```shell
CLIENT_SECRET=<copied-OIDC-Client-secret>
REALM=kong
HOST_IP=<local-IP-of-the-KeyCloak-host-machine>

    
#### Then run this command on the host:
    
```shell
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
    
```shell
curl "http://${HOST_IP}:8000/mock" \
-H "Accept: application/json" -I
```
##### Expected output
```shell
    -H "Accept: application/json" -I
HTTP/1.1 401 Unauthorized
Date: Sat, 03 Jun 2023 19:55:32 GMT
Connection: keep-alive
WWW-Authenticate: Bearer realm="kong",error="no Authorization header found"
X-Kong-Response-Latency: 59
Server: kong/2.8.1
```

## Connect Konga with Kong

Access the Konga UI at:
```  
http://<Host IP>:1337/
```

- Create the admin user
    - In the Konga UI, select 'CONNECTIONS'
    - Select 'Create Connection':Under 'DEFAULT':Name: kong
        - Kong Admin URL: http://kong:8001
        - Press 'CREATE CONNECTION'
        - Press 'ACTIVATE'
    
## Test with Postman
    
### Create a POST request to:
```
http://<Docker-host-local-IP>:8180/realms/kong/protocol/openid-connect/token
```

- Body key/values:
    - username: demouser
    - password: demouser
    - grant_type: password
    - client_id: myapp
### Create a GET request to:
```
<Docker-host-local-IP>:8000/mock
```

- Headers key/values:
    - Accept: 'application/json'
    - Authorization: 'Bearer <output-token-from-POST-request>'

## Connecting your own Application
    
A user's directory metadata (e.g., name) and access token are obtained through REST API calls to the OIDC client in our KeyCloak realm (e.g., myapp).

- The user's metadata can be stored and used by our application, and the access token authenticates the user's calls through the API Gateway
```
http://{host}:8180/realms/{realm}/protocol/openid-connect/userinfo
```
- We will receive an error if our OIDC KeyCloak client isn't in a user's scope. 
    - To enable it, go to the 'Client Scopes' tab and enable 'openid':
    
![Client scopes](https://github.com/Post2FixO/authenticated-api-gateway/assets/4726774/8865c03a-b5c6-46c6-bfcd-a58fecd46eaa)

- Next, to scope openid to your client, go to the 'Clients' tab > myapp client > 'Client scopes' tab > enable openid:

![Client scopes](https://github.com/Post2FixO/authenticated-api-gateway/assets/4726774/435af4f9-3cd1-44e3-90af-f0adf90d3615)

- You can test your configuration with Postman or with direct curl requests before integrating it into your application (curl cheatsheet).

Note: The instructions provided assume a Linux-based host machine. Adjust the commands accordingly if using a different operating system.

Feel free to contribute and provide feedback to improve this project further. Contributions are very welcome!
    
# Repo status
    
## What's working
- IAM enabled (using the Kong & Keycloak integration)
    - SSO
        - Login to web app with KeyCloak
        - Genrating an API token using SSO credentials
        - Refreshing the API token
    - Token
        - Generate a token
        - Store the token as a session cookie
    Authorization
        - Allow users to call specific APIs (still complicated to do)
        - Instantly revoke a token when a user is deactivated in KeyCloak
- A Django app
    - An extra repo provides a Django demo app (frontend & backend) based on the audited Mozilla OIDC Django repo
    - It maybe a good starting point for building your own application


## Backlog (sorted by priority)
- Security
    - Updating versions of core components and dependencies
    - Imporving the Docker files
    - Making it easier for devs to set secure default credentials
- Deployment simplification
    - The setup involves a Bash start script, the Dockerfile + docker-compose.yml file and multiple manual commands and manual steps. We need to streamline this process to make everything easier to deploy.
    - Unifi scripts, commands and automate manual steps
    - Add environment variables in the startup script for main settable parmaters of the stack
    
