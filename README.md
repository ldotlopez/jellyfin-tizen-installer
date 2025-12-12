# Jellyfin installer for Tizen OS through Docker

Docker-based installer to build and deploy Jellyfin to Samsung Tizen TVs.

This is a fork/adaptation of the original work. All credit for the initial concept and implementation goes to the original authors.

## Credits

This project is based on and inspired by:
- [Original project](https://github.com/babagreensheep/jellyfin-tizen-docker) by [babagreensheep](https://github.com/babagreensheep/jellyfin-tizen-docker)
- [jellyfin/jellyfin-tizen](https://github.com/jellyfin/jellyfin-tizen) - Official Jellyfin Tizen client
- [Reddit community guide](https://www.reddit.com/r/jellyfin/comments/s0438d/build_and_deploy_jellyfin_app_to_samsung_tizen/) - Community installation methods

## Prerequisites

- Docker or Podman (you should make some manual changes)
- Samsung TV with Tizen OS
- Internet connection

## Project Structure
```
.
├── docker/
│   ├── Dockerfile          # Multi-stage build for Jellyfin assets and runtime
│   ├── entrypoint.sh       # Container entry point with UID/GID mapping
│   └── run.sh              # Main script: downloads Tizen Studio, builds, and installs
├── install.sh              # Wrapper script to build and run the container
├── .env                    # Configuration file (create from .env.example)
├── cert/                   # Certificate storage (created automatically)
└── build/                  # Tizen Studio installation cache (created automatically)
```

## How It Works

This installer uses a runtime approach to avoid redistributing Samsung's Tizen Studio:

1. **Build time**: Builds Jellyfin web assets inside the Docker image
2. **Runtime**: Downloads and installs Tizen Studio when the container runs
3. **Installation**: Creates certificates, packages the app, and installs to your TV

The `/cert` and `/build` directories are mounted as volumes:
- `/cert`: Stores your Tizen certificate for reuse across installations
- `/build`: Caches Tizen Studio installation (~2GB) to avoid re-downloading

## Setup

### 1. Prepare Your TV

Enable developer mode on your Samsung TV (adapted from [official Tizen guide](https://developer.samsung.com/tv/develop/getting-started/using-sdk/tv-device)):

1. Turn on the TV
2. Go to the Apps page
3. Press `12345` on the remote control
4. Enable `Developer mode` in the dialog that appears
5. Enter the IP address of the host running Docker
6. Shut down and restart the TV as instructed
7. Return to the Apps page - you should see "Developer mode" indicator
8. Keep the TV on during installation

### 2. Configure Installation

Create a `.env` file in the project root:
```bash
# Certificate configuration
CERT_ALIAS=JellyfinDeveloper
CERT_COUNTRY=US
CERT_NAME=Jellyfin
CERT_PASSWORD=your_secure_password

# Jellyfin version to install
JELLYFIN_BRANCH=release-10.11.z

# Docker image settings
DOCKER_IMAGE_NAME=jellyfin-tizen-installer

# TV IP address (can be overridden at runtime)
TIZEN_TV_IP=192.168.1.100
```

**Important**: Keep your `.env` file secure as it contains your certificate password.

### 3. Run Installation
```bash
./install.sh
```

Or override the TV IP at runtime:
```bash
TIZEN_TV_IP=192.168.1.100 ./install.sh
```

The script will:
1. Build the Docker image with Jellyfin assets
2. Download and install Tizen Studio (cached for future runs)
3. Create or reuse your signing certificate
4. Build and package the Jellyfin app
5. Connect to your TV and install the app

### 4. Launch Jellyfin

After installation completes:
1. Go to your TV's Apps page
2. Find and launch the Jellyfin app
3. Configure it to connect to your Jellyfin server

## Advanced Usage

### Manual Build and Run

Build the image:
```bash
docker build \
    --build-arg JELLYFIN_BRANCH=release-10.11.z \
    -t jellyfin-tizen-installer \
    docker/
```

Run the container:
```bash
docker run --rm -it \
    -e PUID=$(id -u) \
    -e PGID=$(id -g) \
    -e CERT_ALIAS=JellyfinDeveloper \
    -e CERT_COUNTRY=US \
    -e CERT_NAME=Jellyfin \
    -e CERT_PASSWORD=your_password \
    -e TIZEN_TV_IP=192.168.1.100 \
    -v "$(pwd)/cert:/cert" \
    -v "$(pwd)/build:/build" \
    jellyfin-tizen-installer
```

### Interactive Shell

For debugging or manual control:
```bash
docker run --rm -it \
    -e PUID=$(id -u) \
    -e PGID=$(id -g) \
    -e CERT_ALIAS=JellyfinDeveloper \
    -e CERT_COUNTRY=US \
    -e CERT_NAME=Jellyfin \
    -e CERT_PASSWORD=your_password \
    -e TIZEN_TV_IP=192.168.1.100 \
    -v "$(pwd)/cert:/cert" \
    -v "$(pwd)/build:/build" \
    --entrypoint /bin/bash \
    jellyfin-tizen-installer
```

Then run `/run.sh` manually inside the container.

### Using Different Jellyfin Versions

Change the `JELLYFIN_BRANCH` in your `.env` file:
```bash
# For latest stable release
JELLYFIN_BRANCH=release-10.11.z

# For specific version
JELLYFIN_BRANCH=v10.8.13

# For development version
JELLYFIN_BRANCH=master
```

## Certificate Management

### Why Certificates Matter

Tizen requires apps to be signed with a certificate. If you reinstall Jellyfin with a different certificate, you must first uninstall the old version from your TV.

This installer automatically:

- Creates a certificate on first run and saves it to `./cert/`
- Reuses the same certificate on subsequent runs
- Allows you to reinstall without uninstalling first

### Certificate Location

Your certificate is stored in:
```
./cert/<CERT_NAME>.p12
```

**Backup this file** if you want to preserve the ability to update the app without uninstalling.

### Regenerating Certificates

To create a new certificate:
1. Delete the existing certificate: `rm ./cert/*.p12`
2. Run the installer again
3. **Important**: Uninstall the old app from your TV first, or the installation will fail

## Troubleshooting

### "Could not connect to TV"
- Ensure the TV is powered on
- Verify developer mode is enabled
- Check the TV's IP address is correct
- Ensure the TV and host are on the same network
- Try pinging the TV: `ping <TV_IP>`

### "Failed to download Tizen Studio"
- Check your internet connection
- The download is ~1.8GB and may take time
- If interrupted, delete `/build/tizen-studio.bin` and retry

### "Device ID not found"
- Make sure developer mode is enabled on the TV
- Restart the TV and try again
- Check that the TV's IP matches what you configured

### "Installation failed" (certificate mismatch)
- You're trying to install with a different certificate
- Either: Use the original certificate from `./cert/`
- Or: Uninstall Jellyfin from your TV first, then reinstall

### Permission Issues
- The container automatically matches the UID/GID of the `./cert` directory owner
- If you encounter permission errors, check ownership: `ls -la ./cert ./build`

## Environment Variables

### Required (set in `.env`):
- `CERT_ALIAS`: Certificate alias name
- `CERT_COUNTRY`: Two-letter country code (e.g., US, GB, DE)
- `CERT_NAME`: Certificate name
- `CERT_PASSWORD`: Certificate password
- `JELLYFIN_BRANCH`: Jellyfin version branch to build

### Optional:
- `TIZEN_TV_IP`: TV IP address (can be set at runtime)
- `DOCKER_IMAGE_NAME`: Docker image name (default: jellyfin-tizen-installer)
- `PUID`: User ID for file ownership (auto-detected from /cert)
- `PGID`: Group ID for file ownership (auto-detected from /cert)

## Technical Details

### Why Runtime Installation?

This project downloads Tizen Studio at runtime (not at Docker build time) to:
1. **Respect licensing**: Avoid redistributing Samsung's proprietary software
2. **Reduce image size**: Keep the Docker image small
3. **Stay current**: Always download the latest Tizen Studio version

### Caching Strategy

The `/build` volume caches:
- Tizen Studio installation (~2GB)
- Build artifacts

This means:
- First run: Downloads and installs Tizen Studio (~5-10 minutes)
- Subsequent runs: Uses cached installation (~1-2 minutes)

To force a fresh installation, delete the build directory:
```bash
rm -rf ./build/*
```

### UID/GID Mapping

The container automatically matches the file ownership of the host's `./cert` directory, ensuring generated files have correct permissions. You can override this by setting `PUID` and `PGID` environment variables.

## License

This project adapts and builds upon open-source community work. Please refer to the original Jellyfin project for licensing details:

- [Jellyfin License](https://github.com/jellyfin/jellyfin/blob/master/LICENSE)
- [Jellyfin Tizen License](https://github.com/jellyfin/jellyfin-tizen/blob/master/LICENSE)

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## Acknowledgments

Special thanks to:

- The Jellyfin team for creating excellent media server software
- Samsung for providing the Tizen SDK
- The community members who developed the original installation methods, specially to [babagreensheep](https://github.com/babagreensheep/)
- All contributors to the Jellyfin Tizen client
