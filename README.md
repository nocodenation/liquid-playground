# Liquid Playground

A Docker-based environment for running Apache NiFi with Python extensions. This project provides a convenient way to experiment with NiFi and develop custom Python processors.

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

This will mount each specified directory inside the container's `/opt/nifi/nifi-current/python_extensions/` folder, making the processors available to NiFi.

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

Use the username and password displayed by the start script (in the format "Username: value" and "Password: value") to log in.

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
