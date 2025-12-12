# HAMQTT

**HAMQTT** is a streamlined development framework designed to rapidly scaffold, build, and deploy **.NET-based MQTT integrations** for Home Assistant.

It abstracts away the complexity of managing Docker infrastructure, MQTT connectivity, and project scaffolding, allowing you to focus on the logic of your IoT integrations.

## 🚀 Features

  * **⚡ Rapid Scaffolding:** Generate new .NET integration projects in seconds using custom templates.
  * **🐳 Docker-First Workflow:** Automatically manages `docker-compose` configurations for development and production.
  * **🛠️ CLI Tooling:** Includes a powerful cross-platform CLI (`hamqtt`) to manage the entire lifecycle.
  * **🏠 Local Dev Environment:** One-command setup for a local Home Assistant and Mosquitto instance.
  * **🔄 Auto-Discovery Ready:** Built on top of `HAMQTT.Integration` to easily interface with Home Assistant's MQTT discovery protocol.

-----

## 📋 Prerequisites

Before using HAMQTT, ensure you have the following installed:

1.  **Docker Desktop** (or Docker Engine + Docker Compose)
2.  **PowerShell Core (pwsh)** (Required for cross-platform scripts on Linux/macOS; standard on Windows)
3.  **.NET SDK 10.0** (or compatible version)
4.  **Git**

-----

## 🛠️ Installation & Setup

### 1\. Bootstrap the Repository

If you are starting in an empty directory, you can bootstrap the toolchain automatically.

**Windows:**

```powershell
.\hamqtt.ps1
```

**Linux / macOS:**

```bash
./hamqtt
```

*Select **Yes** when prompted to clone the repository.*

### 2\. Initialize the Project

Once the tools are present, initialize the workspace. This sets up your `.env` secrets, creates the solution file, and installs the necessary project templates.

```bash
# Windows
.\hamqtt init

# Linux / macOS
./hamqtt init
```

> **Note on Credentials:** During initialization, you will be asked for your GitHub Username and a **Personal Access Token (PAT)**. This is required to restore the project templates and base libraries from the GitHub Package Registry.

-----

## 💻 Usage Guide

The `hamqtt` wrapper is your primary interface for the project.

### Managing Integrations

**Create a new integration:**
Scaffolds a new .NET project in `src/` and registers it in the development `docker-compose` file.

```bash
./hamqtt integrations new MyDeviceName
```

*(Tip: Use PascalCase for names, e.g., `SolarEdge`, `SmartMeter`)*

**List integrations:**
View the status of all local integrations.

```bash
./hamqtt integrations list
```

**Remove an integration:**
Deletes the project folder and removes it from the configuration.

```bash
./hamqtt integrations remove
```

### Running the Environment

**Start Full Development Environment:**
Starts Mosquitto, Home Assistant, and **all** your created integrations in Docker containers.

```bash
./hamqtt run dev
```

**Start Infrastructure Only (Bare Mode):**
Starts only Mosquitto and Home Assistant. Use this if you want to run/debug your .NET integration from your IDE (Visual Studio / Rider) while keeping the infrastructure containerized.

```bash
./hamqtt run dev --bare
```

### Deployment

**Build for Production:**
Generates a production-ready `docker-compose.yml` and `.env` file in the root directory (or specified output).

```bash
./hamqtt deploy
```

### Maintenance

**Update Tooling:**
Updates the core `hamqtt` scripts and templates from the master repository without touching your custom code.

```bash
./hamqtt update
```

**Clean Artifacts:**
Removes generated Docker files, build artifacts (`bin`/`obj`), and temporary folders.

```bash
./hamqtt clean
```

-----

## 📂 Project Structure

```text
/
├── hamqtt                 # Unix entry point
├── hamqtt.ps1             # Main CLI logic
├── docker-compose.yml     # (Generated) Production deployment file
├── scripts/               # Core PowerShell scripts
└── src/
    ├── .env               # Secrets (GitIgnored)
    ├── docker-compose.dev.yml # Local development infrastructure
    ├── ha_config/         # Local Home Assistant configuration
    ├── HAMQTT.Integration # Base library
    ├── HAMQTT.Integration.Template # NuGet Template source
    └── HAMQTT.Integration.MyDevice # (Your custom integrations...)
```

-----

## 🔒 Configuration & Secrets

Configuration is managed via the **`src/.env`** file.

  * **MQTT\_HOST**: Hostname of the broker (default: `mosquitto` for Docker, `localhost` for IDE).
  * **MQTT\_USERNAME**: Broker username.
  * **MQTT\_PASSWORD**: Broker password.
  * **GITHUB\_USERNAME / GITHUB\_PAT**: Credentials for restoring NuGet packages.

> ⚠️ **Security Warning:** The `src/.env` file contains sensitive credentials. It is added to `.gitignore` by default. Do not commit this file to version control.

-----

## 🤝 Contributing

1.  Fork the repository.
2.  Create a feature branch.
3.  Submit a Pull Request.

## 📄 License

[MIT License](https://www.google.com/search?q=LICENSE)
