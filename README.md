# Liquid Playground

A Docker-based environment for running Apache NiFi with Python extensions. This project provides a convenient way to experiment with NiFi and develop custom Python processors.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Quick Guide](#quick-guide)
  - [Building the Image](#building-the-image-2)
  - [Starting the Container](#starting-the-container-2)
  - [Working with NiFi](#working-with-nifi)
- [Basic Usage](#basic-usage)
  - [Building the Image](#building-the-image)
  - [Starting the Container](#starting-the-container)
  - [Stopping the Container](#stopping-the-container)
- [Accessing NiFi](#accessing-nifi)
- [File Access](#file-access)
  - [Using the Files Directory](#using-the-files-directory)
- [Flow Persistence](#flow-persistence)
- [Java NAR Extensions](#java-nar-extensions)
  - [NAR Deployment Directory](#nar-deployment-directory)
  - [Quick NAR Deployment](#quick-nar-deployment)
  - [Production NAR Deployment](#production-nar-deployment)
  - [Verifying NAR Installation](#verifying-nar-installation)
  - [NAR Loading Precedence](#nar-loading-precedence)
  - [Troubleshooting NAR Deployment](#troubleshooting-nar-deployment)
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

To build the Playground image with Tesseract installed, run the following command:

Recommended (new) syntax using `--system-dependencies` as a comma-separated list of apt packages:

```bash
./build.sh --system-dependencies "tesseract-ocr, tesseract-ocr-eng, libtesseract-dev, libleptonica-dev, pkg-config"
```

If any post-installation commands should be run, they can be specified using the `--post-install-commands` flag (a comma separated list of shell commands):

```bash
./build.sh --post-install-commands "playwright install-deps,ls -la /"
```

Both flags can be combined:

```bash
./build.sh --system-dependencies "tesseract-ocr, tesseract-ocr-eng, libtesseract-dev, libleptonica-dev, pkg-config" --post-install-commands "playwright install-deps,ls -la /"
```



### Starting the Container
Now when we have an image with necessary libraries installed, we can start the container with the processor:

```bash
./start.sh ./example/ParseDocument
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

### Building the Image

The project includes a build script that creates a Docker image based on Apache NiFi 2.4.0 with Python support:

```bash
./build.sh
```

You can also specify additional system libraries to install with `--system-dependencies` flag (a comma separated list of apt packages):

```bash
./build.sh --system-dependencies "tesseract-ocr,libtesseract-dev,poppler-utils,libgl1"
```

If any post-installation commands should be run, they can be specified using the `--post-install-commands` flag (a comma separated list of shell commands):

```bash
./build.sh --post-install-commands "playwright install-deps,ls -la /"
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
 3. Start the container
 4. Wait for NiFi to start
 5. Display the credentials (generated, from file, or from arguments)
 
 #### Managing Credentials
 
 By default, NiFi generates a random username and password on every start. You can control this behavior using command-line arguments or a credentials file.
 
 **1. Using CLI Arguments**
 
 You can provide a specific username and password directly (password must be at least 12 characters):
 
 ```bash
 ./start.sh -u admin -p mysecurepassword123
 ```
 
 **2. Saving Credentials**
 
 To save the credentials (whether generated or provided via CLI) to a `.credentials` file for future use, use the `-s` or `--save-credentials` flag:
 
 ```bash
 # Save generated credentials
 ./start.sh -s
 
 # Save provided credentials
 ./start.sh -u admin -p mysecurepassword123 -s
 ```
 
 **3. Using Saved Credentials**
 
 If a valid `.credentials` file exists in the project root, `./start.sh` will automatically use it.
 
 ```bash
 ./start.sh
 # Output: Using credentials from FILE: ...
 ```
 
 #### Mounting Python Processors
 
 You can also specify paths to Python processor directories to be mounted in the container:
 
 ```bash
 ./start.sh /path/to/processor1/folder /path/to/processor2/folder/ /path/to/processor3/file.py
 ```
 
 This will mount each specified Python Processor inside the container's `/opt/nifi/nifi-current/python_extensions/` folder, making the processors available to NiFi.
 
 You can combine credential arguments with processor paths:
 
 ```bash
 ./start.sh -u admin -p password123456 -s ./my_processor/
 ```

 #### Adding Port Mappings
 
 You can expose additional ports from the container using the `--add-port-mapping` flag. Port mappings are specified in a comma-separated format:
 
 ```bash
 ./start.sh --add-port-mapping "8999:8999,5432:5432,1337:1337"
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

By default, NiFi's flow configuration and repositories are ephemeral in a container. Liquid Playground has been configured to persist your work automatically.

### How it Works
- All flow configurations, users, and content repositories are persisted in the local `./state` directory.
- On startup, `start.sh` mounts this directory into the container.
- If `./state/conf` is empty (first run), the script automatically bootstraps it with the default configuration from the image.

### Resetting the Environment
If you want to wipe all flows and start fresh (factory reset), use the `--clear-all-flows` (or `-c`) flag:

```bash
./start.sh --clear-all-flows
```

This will:
1. Delete the local `./state` directory.
2. Restart the container.
3. Re-initialize the configuration from defaults.


# --> The following documentation should be part or a README.md in liquid-library, since there the development takes place
# --> here the only important thing is that the user should place the freshly built nar files into the nar nar_extensions folder
<!-- ## Java NAR Extensions

Liquid Playground supports custom Java NAR (NiFi Archive) files for extending NiFi with Java-based processors and controller services.

### NAR Deployment Directory

Custom NARs should be placed in the `./nar_extensions/` directory. This directory is:
- Volume-mounted to `/opt/nifi/nifi-current/nar_extensions/` inside the container
- Persisted across container restarts
- Separate from the container's built-in `/opt/nifi/nifi-current/lib/` directory

### Quick NAR Deployment

For development and testing, you can deploy NARs without rebuilding the Docker image:

```bash
# 1. Build your NAR files
cd /path/to/your/nar-project
mvn clean package

# 2. Copy NARs to the nar_extensions directory
cp target/*.nar /path/to/liquid-playground/nar_extensions/

# 3. Restart the container to automatically deploy NARs
docker restart liquid-playground
```

**What happens on startup:**
- The container's entrypoint script automatically detects NARs in `nar_extensions/`
- NARs are copied to `/opt/nifi/nifi-current/lib/` before NiFi starts
- No manual `docker exec` commands required

**Updating existing NARs:**
```bash
# Copy updated NARs
cp target/*.nar /path/to/liquid-playground/nar_extensions/

# Clear NAR cache to force reload
docker exec liquid-playground rm -rf /opt/nifi/nifi-current/work/nar/extensions/<nar-name>-*

# Restart container (entrypoint will deploy NARs automatically)
docker restart liquid-playground
```

**Important Notes:**
- NiFi loads NARs from multiple locations with precedence: `lib/` (highest) > `nar_extensions/` > cache
- Always clear the NAR cache when updating NARs, or NiFi will continue using old cached versions
- The `nar_extensions/` directory persists across container restarts via volume mount

### Production NAR Deployment

For production deployments, NARs should be built into the Docker image:

```bash
# 1. Place your NAR files in the ./files/ directory
cp /path/to/your/*.nar ./files/

# 2. Rebuild the Docker image
./build.sh

# 3. Start the container with the new image
./start.sh
```

The Dockerfile automatically copies `*.nar` files from `./files/` to `/opt/nifi/nifi-current/lib/` during image build.

### Verifying NAR Installation

After deploying NARs, verify they were loaded correctly:

```bash
# Check if NARs are loaded
docker exec liquid-playground grep "your-nar-name" /opt/nifi/nifi-current/logs/nifi-app.log | grep "Loaded NAR"

# List all loaded NARs
docker exec liquid-playground ls -la /opt/nifi/nifi-current/lib/*.nar

# Check NAR cache
docker exec liquid-playground ls -la /opt/nifi/nifi-current/work/nar/extensions/
```

### NAR Loading Precedence

NiFi loads NARs from these locations in order of precedence:

1. `/opt/nifi/nifi-current/lib/` (built into Docker image - **highest precedence**)
2. `/opt/nifi/nifi-current/nar_extensions/` (volume-mounted from `./nar_extensions/`)
3. `/opt/nifi/nifi-current/work/nar/extensions/` (unpacked NAR cache)

**Best Practice:** Remove old versions from higher-precedence locations when updating NARs:

```bash
# Remove old NAR from lib directory
docker exec liquid-playground rm -f /opt/nifi/nifi-current/lib/your-nar-*.nar

# Clear cache for the NAR
docker exec liquid-playground rm -rf /opt/nifi/nifi-current/work/nar/extensions/your-nar-*

# Restart to load from nar_extensions
docker restart liquid-playground
```

### Troubleshooting NAR Deployment

**Problem:** After deploying a new NAR, NiFi still uses the old version

**Solution:** Clear the NAR cache and remove old versions:
```bash
docker exec liquid-playground rm -rf /opt/nifi/nifi-current/work/nar/extensions/<nar-name>-*
docker exec liquid-playground rm -f /opt/nifi/nifi-current/lib/<nar-name>-*.nar
docker restart liquid-playground
```

**Problem:** NAR fails to load with ClassNotFoundException

**Solution:** Ensure all dependency NARs are also deployed:
```bash
# Check NAR dependencies in the logs
docker exec liquid-playground grep "Failed to load" /opt/nifi/nifi-current/logs/nifi-app.log
``` -->


# --> The following documentation should be part or a README.md in liquid-library, since there the development takes place
<!-- ### Managing Node.js Frontends with NiFi Services

Some NiFi controller services (like NodeJS App Gateway) can manage Node.js frontend applications. This requires additional runtime dependencies and port configuration.

#### Installing Bun Runtime

[Bun](https://bun.sh) is a fast JavaScript runtime that can be used to run Next.js and other Node.js applications. To add Bun to your liquid-playground image:

```bash
./build.sh --post-install-commands "curl -fsSL https://bun.sh/install | bash,cp /root/.bun/bin/bun /usr/local/bin/bun,chmod +x /usr/local/bin/bun"
```

This will:
1. Download and install Bun
2. Make it globally available
3. Set proper permissions

Alternatively, you can install Node.js instead:

```bash
./build.sh --system-dependencies "nodejs,npm"
``` -->

# --> the following service ports are not common, but specific to each service, so the documentation for each service port and how to expose it would go into the README.md of that specific development that makes use of this service port.
<!-- #### Exposing Service Ports

Different NiFi services require different ports to be exposed. Use the `--add-port-mapping` flag with `start.sh`:

**Common Service Ports:**

| Service | Port | Purpose |
|---------|------|---------|
| NodeJS App API Gateway | 8888 | HTTP API gateway for Node.js apps |
| NodeJS App API Gateway (Alt) | 8889 | Alternative gateway port |
| Frontend Applications | 3000 | Next.js/React dev servers |
| Admin Interfaces | 5050 | Database admin tools (pgAdmin, etc.) |
| Custom HTTP Services | 9999 | General purpose HTTP services |
| Log Viewer | 5050 | Application log viewer | 

**Example: Starting with NodeJS App Gateway**

```bash
# Build image with Bun runtime
./build.sh --post-install-commands "curl -fsSL https://bun.sh/install | bash,cp /root/.bun/bin/bun /usr/local/bin/bun,chmod +x /usr/local/bin/bun"

# Start with required ports exposed
./start.sh --add-port-mapping "8888:8888,8889:8889,3000:3000"
```

**Example: Multiple Services**

```bash
# Expose ports for gateway, frontend, and log viewer
./start.sh --add-port-mapping "8888:8888,3000:3000,5050:5050"
```

#### Service-Specific Configuration

**NodeJS App Gateway Service:**
- Ports: 8888 (primary), 8889 (secondary)
- Runtime: Requires Bun or Node.js
- Purpose: Manages Node.js app lifecycle and HTTP routing
- Volume mount: Frontend apps in `/files/` directory

**Frontend Applications (Next.js, React, etc.):**
- Port: 3000 (default dev server)
- Runtime: Requires Bun or Node.js
- Managed by: NodeJS App Gateway controller service
- Location: `/files/<app-name>/` in container

**Important Notes:**
- Only expose ports that your services actually need
- Port mappings can be changed anytime by restarting with different `--add-port-mapping` values
- For production, consider using a reverse proxy instead of exposing all ports directly
-->
## Advanced Usage

### Adding System Libraries

#### System Libraries

You can add system libraries (apt packages) to the Docker image by passing them as arguments to the build script:

```bash
./build.sh tesseract-ocr libtesseract-dev poppler-utils libgl1
```

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

You can mount Python and NAR files from any location on your computer by passing paths to the start.sh script:

```bash
./start.sh /path/to/python_processor /path/to/my-extension.nar
```

**The script automatically detects the file type:**
- Python files (.py) → mounted to Python extensions
- NAR files (.nar) → mounted to NiFi
- Folders with Python files → mounted as Python extension folders
- Folders with NAR files → each NAR file is mounted individually

**Examples:**

```bash
# Mount a single Python processor
./start.sh /home/user/MyProcessor.py

# Mount a NAR file
./start.sh /home/user/my-service.nar

# Mount a folder containing Python processors
./start.sh /home/user/my_processors

# Mount a folder containing NAR files
./start.sh /home/user/nar_files

# Mount multiple extensions at once
./start.sh /path/to/python /path/to/processor.py /path/to/service.nar
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
