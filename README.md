# Liquid Playground

A Docker-based environment for running Apache NiFi with Python extensions. This project provides a convenient way to experiment with NiFi and develop custom Python processors.

## Table of Contents
- [Prerequisites](#prerequisites-1)
- [Basic Usage](#basic-usage-1)
  - [Building the Image](#building-the-image-1)
  - [Starting the Container](#starting-the-container-1)
  - [Stopping the Container](#stopping-the-container-1)
- [Accessing NiFi](#accessing-nifi-1)
- [SFTP Integration](#sftp-integration-1)
  - [Using the SFTP Server](#using-the-sftp-server-1)
- [Practical Example Guide](#practical-example-guide-1)
  - [Building the Image](#building-the-image-2)
  - [Starting the Container](#starting-the-container-2)
  - [Working with NiFi](#working-with-nifi-1)
- [Advanced Usage](#advanced-usage-1)
  - [Adding System Libraries](#adding-system-libraries-1)
    - [System Libraries](#system-libraries-1)
    - [Modifying the Dockerfile Directly](#modifying-the-dockerfile-directly-1)
    - [Using a Different Base Image](#using-a-different-base-image-1)
  - [Mapping Python Extensions](#mapping-python-extensions-1)
    - [Using the Default python_extensions Folder](#using-the-default-python_extensions-folder-1)
    - [Mounting an Existing Python Processors Folder](#mounting-an-existing-python-processors-folder-1)
      - [Using the start.sh Script (Recommended)](#using-the-startsh-script-recommended-1)
      - [Manually Modifying docker-compose.yml](#manually-modifying-docker-composeyml-1)
    - [Multiple Python Extension Folders](#multiple-python-extension-folders-1)
    - [Using Relative Paths](#using-relative-paths-1)
  - [Using NiPyGen-Generated Processors](#using-nipygen-generated-processors-1)
  - [Manual Container Management](#manual-container-management-1)
    - [Building the Image Manually](#building-the-image-manually-1)
    - [Starting the Container Manually](#starting-the-container-manually-1)
    - [Checking Logs](#checking-logs-1)
    - [Stopping the Container Manually](#stopping-the-container-manually-1)
  - [Accessing the Container Shell](#accessing-the-container-shell-1)
- [Troubleshooting](#troubleshooting-1)
  - [NiFi Fails to Start](#nifi-fails-to-start-1)
  - [Cannot Access NiFi Web UI](#cannot-access-nifi-web-ui-1)
  - [Python Processor Issues](#python-processor-issues-1)
- [Contributing](#contributing-1)
- [License](#license-1)

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/)

## Basic Usage

### Building the Image

The project includes a build script that creates a Docker image based on Apache NiFi 2.4.0 with Python support:

```bash
./build.sh
```

You can also specify additional system libraries to install:

```bash
./build.sh tesseract-ocr libtesseract-dev poppler-utils libgl1
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
5. Display the generated username and password in a clean format (Username: value, Password: value)

You can also specify paths to Python processor directories to be mounted in the container:

```bash
./start.sh /path/to/processor1/folder /path/to/processor2/folder/ /path/to/processor3/file.py
```

This will mount each specified Python Processor inside the container's `/opt/nifi/nifi-current/python_extensions/` folder, making the processors available to NiFi.

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

## SFTP Integration

Liquid Playground includes an SFTP server that can be used to easily upload files for processing with NiFi. This is particularly useful for testing data ingestion workflows.

### Using the SFTP Server

From within NiFi, you can configure `GetSFTP` or `FetchSFTP` processors to fetch files using:
- Hostname: sftp
- Port: 22
- Username: user
- Password: password
- Remote Path: /upload

Any files placed in the local `./sftp_files` directory will be accessible to NiFi through the SFTP connection, making it easy to feed files into your data processing workflows.


## Practical Example Guide

This repository contains an example Python processor that can be used to test the Liquid Playground environment.

It is located in the `example/ParseDocument` directory.

> Note: This processor is not production ready and should not be used in a production environment.
 
In this guide, we will show you how the Playground environment can be used to experiment with Python processors.

### Building the Image

The `ExampleProcessor` uses [Google's Tesseract OCR](https://github.com/tesseract-ocr/tesseract) Engine to extract text
from PDF files. That means our NiFi image must have Tesseract OCR libraries installed.

To build the Playground image with Tesseract installed, run the following command:

```bash
./build.sh tesseract-ocr tesseract-ocr-eng libtesseract-dev libleptonica-dev pkg-config
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
 ✔ Network liquid-playground_liquid-playground-network  Created                                                                                                          0.1s 
 ✔ Container liquid-playground-sftp-1                   Started                                                                                                          0.3s 
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

Add FetchSFTP Processor with the following settings:
- Hostname: sftp
- Username: user
- Password: password
- Remote File: dummy.pdf
- Leave other fields with their default values

Add ParseDocument Processor with the following settings:
- Input Format: PDF
- Infer Table Structure: False
- Language: en

Wait some time until NiFi installs processor dependencies and starts processing the file.

> You can track dependencies installation progress in logs of the NiFi.
> This can be done with the following command: `./logs.sh`
> or with docker command: `docker compose logs -f`

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
FROM docker.env.liquidvu.com/liquid-nifi:master-2.2.0-latest-ci-python
```

3. Build the Docker image:

```bash
docker build -t nocodenation/liquid-playground:latest .
```

Note that changing the base image may require additional modifications to the Dockerfile or scripts to ensure compatibility.


### Mapping Python Extensions

#### Using the Default python_extensions Folder

By default, the `python_extensions` folder in the project root is mounted as a volume to the NiFi container at `/opt/nifi/nifi-current/python_extensions`. You can add your Python processors to this folder, and they will be available in NiFi.

Copy or create your Python processors into the `python_extensions` folder to make them available in NiFi.

#### Mounting an Existing Python Processors Folder 

There are two ways to mount existing folders with Python processors:

##### Using the start.sh Script (Recommended)

The easiest way to mount existing folders or files with Python processors is to pass their paths as arguments to the start.sh script:

```bash
./start.sh /path/to/processor1 /path/to/processor2/ /path/to/processor3.py
```

This will:
1. Mount each specified directory or file inside the container's `/opt/nifi/nifi-current/python_extensions/` folder
2. Use the directory/file name as the mount point name
3. Make the processors available to NiFi

For example, if you run:

```bash
./start.sh /home/user/my_processors /home/user/other_processors/ /home/user/file/Processor.py
```

The directories and files will be mounted as:
- `/opt/nifi/nifi-current/python_extensions/my_processors`
- `/opt/nifi/nifi-current/python_extensions/other_processors`
- `/opt/nifi/nifi-current/python_extensions/Processor.py`

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
