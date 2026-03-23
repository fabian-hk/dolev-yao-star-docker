# Simple DY* Environment

The Docker image `fabianhk/dystar-with-code-server` provides a lightweight DY* development environment using code-server (VS Code in the browser). After starting the container, open http://localhost:8443 in your browser to access the editor. Place your project files in the repository `workspace` directory — that folder is mounted into the container when running the provided commands.

## Run the Container

### Linux

```bash
mkdir workspace
docker compose up
```

