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
  - [Adding System Libraries](#adding-system-libraries)
    - [System Libraries](#system-libraries)
    - [Modifying the Dockerfile Directly](#modifying-the-dockerfile-directly)
    - [Using a Different Base Image](#using-a-different-base-image)
  - [Mapping Extensions](#mapping-extensions)
    - [Using the Default Folders](#using-the-default-folders)
    - [Mounting Extensions from Anywhere](#mounting-extensions-from-anywhere)
    - [Multiple Extension Folders](#multiple-extension-folders)
    - [Using Relative Paths](#using-relative-paths)
  - [Using NiPyGen-Generated Processors](#using-nipygen-generated-processors)
  - [Manual Container Management](#manual-container-management)
    - [Building the Image Manually](#building-the-image-manually)
    - [Starting the Container Manually](#starting-the-container-manually)
    - [Checking Logs](#checking-logs)
    - [Stopping the Container Manually](#stopping-the-container-manually)
  - [Accessing the Container Shell](#accessing-the-container-shell)
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

### Adding System Libraries

#### System Libraries

You can add system libraries (apt packages) to the Docker image by setting the `SYSTEM_DEPENDENCIES` variable in your `.env` file:

```bash
SYSTEM_DEPENDENCIES="tesseract-ocr, libtesseract-dev, poppler-utils, libgl1"
```

Then run `./build.sh` to rebuild the image with these packages installed.

These are system libraries that might be required for certain Python packages to work properly, not Python packages themselves.

#### Modifying the Dockerfile Directly

For more advanced usage, you can modify the Dockerfile directly to add system libraries:

1. Open the Dockerfile in a text editor:

```bash
nano Dockerfile
```

2. Locate the line that installs packages:

```dockerfile
RUN apt-get install -y python3 python3-pip
```

3. Add your system libraries directly to this line:

```dockerfile
RUN apt-get install -y python3 python3-pip tesseract-ocr libtesseract-dev poppler-utils libgl1
```

4. Build the Docker image:

```bash
docker build -t nocodenation/liquid-playground:latest .
```

This approach gives you more control over the Docker image build process and allows you to make other customizations to the Dockerfile as needed.

#### Using a Different Base Image

If you need to use a different base image (e.g., a different version of Apache NiFi), you'll need to modify the Dockerfile:

1. Open the Dockerfile in a text editor:

```bash
nano Dockerfile
```

2. Modify the first line that specifies the base image:

```dockerfile
FROM apache/nifi:2.4.0
```

Change it to your desired base image, for example:

```dockerfile
FROM docker.env.liquidvu.com/liquid-nifi:master-2.7.0-latest-ci-python
```

3. Build the Docker image:

```bash
docker build -t nocodenation/liquid-playground:latest .
```

Note that changing the base image may require additional modifications to the Dockerfile or scripts to ensure compatibility.


### Mapping Extensions

You can add custom extensions to NiFi in two ways:
- **Python processors** (.py files) - For custom Python-based processors
- **NAR files** (.nar files) - For custom Java-based components

#### Using the Default Folders

By default, two folders are available:
- `python_extensions/` - For Python processors
- `nar_extensions/` - For NAR files

Simply copy your files into these folders and restart the container.

#### Mounting Extensions from Anywhere

You can mount Python and NAR files from any location on your computer by setting the `EXTENSION_PATHS` variable in your `.env` file:

```bash
EXTENSION_PATHS="/path/to/python_processor, /path/to/my-extension.nar"
```

**The script automatically detects the file type:**
- Python files (.py) → mounted to Python extensions
- NAR files (.nar) → mounted to NiFi
- Folders with Python files → mounted as Python extension folders
- Folders with NAR files → each NAR file is mounted individually

**Examples:**

```bash
# Mount a single Python processor
EXTENSION_PATHS="/home/user/MyProcessor.py"

# Mount a NAR file
EXTENSION_PATHS="/home/user/my-service.nar"

# Mount a folder containing Python processors
EXTENSION_PATHS="/home/user/my_processors"

# Mount a folder containing NAR files
EXTENSION_PATHS="/home/user/nar_files"

# Mount multiple extensions at once (comma-separated)
EXTENSION_PATHS="/path/to/python, /path/to/processor.py, /path/to/service.nar"
```

##### Manually Modifying docker-compose.yml

Alternatively, you can manually modify the `docker-compose.yml` file:

1. Open the `docker-compose.yml` file in a text editor
2. Locate the `volumes` section under the `liquid-playground` service
3. Add a new volume mapping for your existing folder

Example of mounting an existing folder:

```yaml
services:
  liquid-playground:
    image: nocodenation/liquid-playground:latest
    container_name: liquid-playground
    volumes:
      - ./python_extensions:/opt/nifi/nifi-current/python_extensions:r
      - /path/to/your/processor:/opt/nifi/nifi-current/python_extensions/custom:r
      - /path/to/your/processor_file.py:/opt/nifi/nifi-current/python_extensions/your_file.py:r
    ports:
      - "8443:8443"
```

In this example, `/path/to/your/processor` is the absolute path to your existing folder on your host machine, and it will be mounted at `/opt/nifi/nifi-current/python_extensions/custom` inside the container.
`/path/to/your/processor_file.py` is the absolute path to your existing processor file on your host machine, and it will be mounted at `/opt/nifi/nifi-current/python_extensions/your_file.py` inside the container.

#### Multiple Python Extension Folders

You can mount multiple folders with Python processors by adding more volume mappings:

```yaml
volumes:
  - ./python_extensions:/opt/nifi/nifi-current/python_extensions:r
  - /path/to/processors1:/opt/nifi/nifi-current/python_extensions/custom1:r
  - /path/to/processors2:/opt/nifi/nifi-current/python_extensions/custom2:r
```

#### Using Relative Paths

You can also use relative paths for your volume mappings:

```yaml
volumes:
  - ./python_extensions:/opt/nifi/nifi-current/python_extensions:r
  - ../my_processors:/opt/nifi/nifi-current/python_extensions/my_processors:r
```

In this example, `../my_processors` refers to a folder named `my_processors` in the parent directory of your project.

#### Using NiPyGen-Generated Processors

[NiPyGen](https://github.com/nocodenation/NiPyGen) is a tool for generating Python processors for Apache NiFi. NiPyGen-generated processors have a specific structure and need to be placed at the root level of the Python extensions directory.

To use NiPyGen-generated processors with Liquid Playground, you need to modify the docker-compose.yml file to mount your NiPyGen folder directly as the Python extensions volume:

1. Open the `docker-compose.yml` file in a text editor
2. Locate the `volumes` section under the `liquid-playground` service
3. Replace the default volume mapping with your NiPyGen folder

Example of mounting a NiPyGen folder:

```yaml
services:
  liquid-playground:
    image: nocodenation/liquid-playground:latest
    container_name: liquid-playground
    volumes:
      - /path/to/your/nipygen/folder:/opt/nifi/nifi-current/python_extensions:r
    ports:
      - "8443:8443"
```

In this example, `/path/to/your/nipygen/folder` is the absolute path to your folder containing NiPyGen-generated processors on your host machine, and it will be mounted directly as `/opt/nifi/nifi-current/python_extensions` inside the container.

This direct mounting is necessary because NiPyGen-generated processors expect to be at the root level of the Python extensions directory, not in a subdirectory.

### Manual Container Management

If you prefer to manage the container manually instead of using the provided scripts, you can use Docker Compose directly:

#### Building the Image Manually

1. Open the Dockerfile in a text editor:

```bash
nano Dockerfile
```

2. Locate the line that installs packages (line 5):

```dockerfile
RUN apt-get install -y python3 python3-pip
```

3. Add your system libraries to this line:

```dockerfile
RUN apt-get install -y python3 python3-pip tesseract-ocr libtesseract-dev poppler-utils libgl1
```

4. Save the file and build the Docker image:

```bash
docker build -t nocodenation/liquid-playground:latest .
```

#### Starting the Container Manually

```bash
docker compose up -d
```

#### Checking Logs

Use simple command:

```bash
./logs.sh
```

or full command:

```bash
docker compose logs -f
```

#### Stopping the Container Manually

```bash
docker compose down
```

### Accessing the Container Shell

You can access the shell of the running container for debugging or advanced configuration:

```bash
docker exec -it liquid-playground bash
```

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
