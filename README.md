# Liquid Playground

A Docker-based environment for running Apache NiFi with Python extensions. This project provides a convenient way to experiment with NiFi and develop custom Python processors.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Quick Guide](#quick-guide)
  - [Building the Image](#building-the-image-2)
  - [Starting the Container](#starting-the-container-2)
  - [Working with NiFi](#working-with-nifi)
- [Basic Usage](#basic-usage)
  - [Configuration](#configuration)
  - [Building the Image](#building-the-image)
  - [Starting the Container](#starting-the-container)
    - [Managing Credentials](#managing-credentials)
    - [Mounting Extensions](#mounting-extensions)
    - [Adding Port Mappings](#adding-port-mappings)
  - [Stopping the Container](#stopping-the-container)
- [Accessing NiFi](#accessing-nifi)
- [File Access](#file-access)
  - [Using the Files Directory](#using-the-files-directory)
- [Flow Persistence](#flow-persistence)
  - [Enabling Persistence](#enabling-persistence)
  - [How it Works](#how-it-works)
  - [Resetting State](#resetting-state)
- [Advanced Usage](#advanced-usage)
- [Troubleshooting](#troubleshooting)
  - [NiFi Fails to Start](#nifi-fails-to-start)
  - [Cannot Access NiFi Web UI](#cannot-access-nifi-web-ui)
  - [Python Processor Issues](#python-processor-issues)
- [Contributing](#contributing)
- [License](#license)

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)


## Quick Guide

This repository contains an example Python processor that can be used to test the Liquid Playground environment.

It is located in the `example/ParseDocument` directory.

> Note: This processor is not production ready and should not be used in a production environment.
 
In this guide, we will show you how the Playground environment can be used to experiment with Python processors.

### Building the Image

The `ExampleProcessor` uses [Google's Tesseract OCR](https://github.com/tesseract-ocr/tesseract) Engine to extract text
from PDF files. That means our NiFi image must have Tesseract OCR libraries installed.

To build the Playground image with Tesseract installed, first configure your `.env` file:

1. Copy the example environment file:
```bash
cp env.example .env
```

2. Edit `.env` and set the `SYSTEM_DEPENDENCIES` variable:
```bash
SYSTEM_DEPENDENCIES="tesseract-ocr, tesseract-ocr-eng, libtesseract-dev, libleptonica-dev, pkg-config"
```

3. Run the build script:
```bash
./build.sh
```

If any post-installation commands should be run, set the `POST_INSTALLATION_COMMANDS` variable in `.env`:

```bash
POST_INSTALLATION_COMMANDS="playwright install-deps, ls -la /"
```

Both variables can be combined in the `.env` file:

```bash
SYSTEM_DEPENDENCIES="tesseract-ocr, tesseract-ocr-eng, libtesseract-dev, libleptonica-dev, pkg-config"
POST_INSTALLATION_COMMANDS="playwright install-deps, ls -la /"
```



### Starting the Container
Now when we have an image with necessary libraries installed, we can start the container with the processor.

Set the `EXTENSION_PATHS` variable in your `.env` file to mount the example processor:

```bash
EXTENSION_PATHS="./example/ParseDocument"
```

Then run the start script:

```bash
./start.sh
```

Wait for the container to start. Your console output should look like this:

```
Stopping any existing container...
Checking if the Docker image exists...
Adding Python processor paths as volume mounts...
Starting the container...
[+] Running 3/3
 ✔ Network liquid-playground_default                    Created
 ✔ Container liquid-playground                          Started                                                                                                          0.3s 
Waiting for NiFi to start...
Still waiting for NiFi to start...

NiFi has started successfully!
Extracting credentials...

Username: bddec316-3c6f-4c1a-b601-91379f0e6572
Password: 3egF2be993otE/xnGFUdR5bZq0AxKz0B

Use these credentials to access NiFi: https://localhost:8443/nifi
```

### Working with NiFi

Access nifi on URL provided in the console output. By default, it will be http://localhost:8443/nifi
Enter Username and Password as provided in the console output.

Add FetchFile Processor with the following settings:
- File to Fetch: /files/dummy.pdf
- Leave other fields with their default values

Add ParseDocument Processor with the following settings:
- Input Format: PDF
- Infer Table Structure: False

Wait some time until NiFi installs processor dependencies and starts processing the file.

> You can track dependencies installation progress in logs of the NiFi.
> This can be done with the following command: `./logs.sh`
> or with docker command: `docker compose logs -f`

## Basic Usage

### Configuration

All configuration is done through environment variables in a `.env` file. To get started:

1. Copy the example environment file:
```bash
cp env.example .env
```

2. Edit `.env` to configure your settings (see `env.example` for detailed documentation of all available options).

### Building the Image

The project includes a build script that creates a Docker image based on Apache NiFi 2.4.0 with Python support:

```bash
./build.sh
```

You can specify additional system libraries to install by setting the `SYSTEM_DEPENDENCIES` variable in your `.env` file:

```bash
SYSTEM_DEPENDENCIES="tesseract-ocr, libtesseract-dev, poppler-utils, libgl1"
```

If any post-installation commands should be run, set the `POST_INSTALLATION_COMMANDS` variable:

```bash
POST_INSTALLATION_COMMANDS="playwright install-deps, ls -la /"
```

These are system libraries (apt packages) that might be required for certain Python packages to work properly, not Python packages themselves. Python packages will be managed by NiFi.

### Starting the Container
 
To start the container, use the start script:
 
```bash
./start.sh
```
 
This script will:
1. Stop any existing container
2. Check if the Docker image exists, and build it if necessary
3. Start the container (with persistence mounts if `PERSIST_NIFI_STATE=true`)
4. Wait for NiFi to start
5. Display the credentials (from environment variables or auto-generated)
 
#### Managing Credentials
 
By default, NiFi generates a random username and password on every start. You can set custom credentials using environment variables.
 
Set the `NIFI_USERNAME` and `NIFI_PASSWORD` variables in your `.env` file (password must be at least 12 characters):
 
```bash
NIFI_USERNAME="admin"
NIFI_PASSWORD="mysecurepassword123"
```

If these variables are not set, NiFi will auto-generate credentials on startup.
 
#### Mounting Extensions
 
You can mount Python processors and NAR files by setting the `EXTENSION_PATHS` variable in your `.env` file:
 
```bash
# Mount a single processor directory
EXTENSION_PATHS="./example/ParseDocument"

# Mount multiple extensions (comma-separated)
EXTENSION_PATHS="/path/to/processor1, /path/to/processor2, /path/to/my-extension.nar"
```
 
The script automatically detects the file type:
- Python files (`.py`) → mounted to Python extensions
- NAR files (`.nar`) → mounted to NiFi lib
- Folders with Python files → mounted as Python extension folders
- Folders with NAR files → each NAR file is mounted individually

#### Adding Port Mappings
 
You can expose additional ports from the container by setting the `ADDITIONAL_PORT_MAPPINGS` variable in your `.env` file:
 
```bash
ADDITIONAL_PORT_MAPPINGS="8999:8999, 5432:5432, 1337:1337"
```
 
This will map the specified ports in addition to the default port 8443. This is useful when your processors need to listen on additional ports (e.g., for OAuth callbacks or custom HTTP endpoints).
 
 ### Stopping the Container

To stop the container, use the stop script:

```bash
./stop.sh
```

## Accessing NiFi

Once the container is running, you can access NiFi at:

```
https://localhost:8443/nifi
```

Use the username and password displayed by the start script to log in.

## File Access

Liquid Playground includes a direct file mount that can be used to easily access files for processing with NiFi. This is particularly useful for testing data ingestion workflows.

### Using the Files Directory

From within NiFi, you can configure `FetchFile` processors to fetch files using:
- File to Fetch: /files/dummy.pdf

Any files placed in the local `./files` directory will be directly accessible to NiFi through the mounted path at `/files`, making it easy to feed files into your data processing workflows.

## Flow Persistence

By default, NiFi's flow configuration and repositories are ephemeral in a container. Liquid Playground can be configured to persist your work across container restarts.

### Enabling Persistence

To enable flow persistence, set the `PERSIST_NIFI_STATE` variable in your `.env` file:

```bash
PERSIST_NIFI_STATE="true"
```

### How it Works

When `PERSIST_NIFI_STATE=true`:

**During build (`./build.sh`):**
- Creates a `./state` folder in the project directory
- Copies the following directories from the NiFi image:
  - `conf` - NiFi configuration files
  - `database_repository` - NiFi database
  - `flowfile_repository` - FlowFile data
  - `content_repository` - Content data
  - `provenance_repository` - Provenance data
- If `./state` already exists, you will be prompted to confirm overwriting

**During start (`./start.sh`):**
- Mounts the `./state` directories into the container
- All flow configurations, users, and repositories are persisted locally

### Resetting State

To reset the NiFi state and start fresh:

1. Stop the container:
```bash
./stop.sh
```

2. Remove the state folder (requires sudo if not running as root):
```bash
sudo rm -rf ./state
```

3. Rebuild the image to recreate the state folder:
```bash
./build.sh
```

> **Note:** Removing the state folder requires root privileges because the files are owned by the NiFi user inside the container.

## Advanced Usage

For advanced configuration options including system libraries, custom Dockerfile modifications, extension mapping, manual container management, and more, see the [Advanced Usage Guide](docs/advanced_usage.md).

## Troubleshooting

### NiFi Fails to Start

If NiFi fails to start, check the logs for errors:

```bash
docker compose logs
```

Common issues include:
- Insufficient memory
- Port conflicts
- Permission issues with mounted volumes

### Cannot Access NiFi Web UI

If you cannot access the NiFi web UI:

1. Ensure the container is running:
   ```bash
   docker compose ps
   ```

2. Check if NiFi is fully started:
   ```bash
   docker compose logs | grep "Started Application"
   ```

3. Verify that port 8443 is not being used by another application:
   ```bash
   netstat -tuln | grep 8443
   ```

### Python Processor Issues

If your Python processors are not working correctly:

1. Ensure the Python file is in the `python_extensions` folder
2. Check the NiFi logs for Python-related errors
3. Verify that any required Python packages are installed in the container

> **Note:** Python processors within NiFi get reloaded only if the processors are stopped and not processing anything. If you make changes to your Python processor code, make sure to stop the processor before the changes will take effect.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the [Apache License, Version 2.0](LICENSE).
