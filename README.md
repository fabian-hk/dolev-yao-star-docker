# Simple DY* Environment

The Docker image `fabianhk/dystar-with-code-server` provides a lightweight DY* development environment using code-server (VS Code in the browser). After starting the container, open http://localhost:8443 in your browser to access the editor. Place your project files in the repository `workspace` directory — that folder is mounted into the container when running the provided commands.

## Run the Container

### Linux

- Clone this repository
- Install [Docker Engine](https://docs.docker.com/engine/install) or [Docker Desktop](https://www.docker.com/products/docker-desktop/) (tested with Docker Engine on Ubuntu)
- Open a terminal window in the root of the downloaded repository and run:

```bash
docker compose up
```

### Windows

- Clone or download and extract this repository
- Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) (tested with WSL 2 backend)
- Open a terminal window in the root of the downloaded repository and run:

```bash
docker compose up
```

### MacOS (Apple Silicon and Intel Chip)

- Clone or download and extract this repository
- Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) (tested with Apple Silicon)
- Open a terminal window in the root of the downloaded repository and run:

```bash
docker compose up
```
