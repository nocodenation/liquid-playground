# Advanced Usage

## Adding System Libraries

### System Libraries

You can add system libraries (apt packages) to the Docker image by setting the `SYSTEM_DEPENDENCIES` variable in your `.env` file:

```bash
SYSTEM_DEPENDENCIES="tesseract-ocr, libtesseract-dev, poppler-utils, libgl1"
```

Then run `./build.sh` to rebuild the image with these packages installed.

These are system libraries that might be required for certain Python packages to work properly, not Python packages themselves.

### Modifying the Dockerfile Directly

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

### Using a Different Base Image

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


## Mapping Extensions

You can add custom extensions to NiFi in two ways:
- **Python processors** (.py files) - For custom Python-based processors
- **NAR files** (.nar files) - For custom Java-based components

### Using the Default Folders

By default, two folders are available:
- `python_extensions/` - For Python processors
- `nar_extensions/` - For NAR files

Simply copy your files into these folders and restart the container.

### Mounting Extensions from Anywhere

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

#### Manually Modifying docker-compose.yml

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

### Multiple Python Extension Folders

You can mount multiple folders with Python processors by adding more volume mappings:

```yaml
volumes:
  - ./python_extensions:/opt/nifi/nifi-current/python_extensions:r
  - /path/to/processors1:/opt/nifi/nifi-current/python_extensions/custom1:r
  - /path/to/processors2:/opt/nifi/nifi-current/python_extensions/custom2:r
```

### Using Relative Paths

You can also use relative paths for your volume mappings:

```yaml
volumes:
  - ./python_extensions:/opt/nifi/nifi-current/python_extensions:r
  - ../my_processors:/opt/nifi/nifi-current/python_extensions/my_processors:r
```

In this example, `../my_processors` refers to a folder named `my_processors` in the parent directory of your project.

### Using NiPyGen-Generated Processors

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

## Manual Container Management

If you prefer to manage the container manually instead of using the provided scripts, you can use Docker Compose directly:

### Building the Image Manually

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

### Starting the Container Manually

```bash
docker compose up -d
```

### Checking Logs

Use simple command:

```bash
./logs.sh
```

or full command:

```bash
docker compose logs -f
```

### Stopping the Container Manually

```bash
docker compose down
```

## Accessing the Container Shell

You can access the shell of the running container for debugging or advanced configuration:

```bash
docker exec -it liquid-playground bash
```
