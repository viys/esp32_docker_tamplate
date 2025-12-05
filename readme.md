# 使用 Docker 设置 ESP32 开发环境

本指南介绍了如何使用 Docker 设置 ESP32 开发环境，并提供了一些 PowerShell 和 Bash 脚本来简化开发流程。这些脚本帮助您创建项目、设置目标芯片、编译、烧录和监视 ESP32 项目。

## 前提条件

- 安装 **Docker**。
- **PowerShell**（Windows 用户）或 **Bash**（Linux/macOS 用户）来运行提供的脚本。

## Docker 安装

1. 按照 [官方 Docker 网站](https://www.docker.com/get-started) 上的说明安装 Docker。
2. 安装完成后，在终端中运行以下命令来验证 Docker 是否安装成功：

   ```bash
   docker --version
   ```

## 拉取 ESP-IDF Docker 镜像

要在 Docker 中设置 ESP-IDF 开发环境，请从 Docker Hub 拉取官方 `espressif/idf` 镜像。运行以下命令：

```bash
docker pull espressif/idf:v5.4.1
```

此命令会下载 ESP32 开发所需的 `espressif/idf` Docker 镜像（版本 `v5.4.1`）。

## Docker Compose 设置

1. 确保已安装 `docker-compose`，如果没有，请参考 [Docker Compose 官方文档](https://docs.docker.com/compose/install/) 进行安装。

2. `docker-compose.yml` 文件允许您使用 Docker Compose 来管理 ESP32 开发环境。以下是 `docker-compose.yml` 文件的内容：

   ```yaml
   version: "3.8"
   
   services:
     esp-idf:
       image: espressif/idf:v5.4.1
       container_name: esp-idf-builder
       working_dir: /project
       volumes:
         - .:/project
       environment:
         - HOME=/tmp
         - IDF_GIT_SAFE_DIR=/project
       tty: true
       stdin_open: true
   ```

   该配置会将主机上的 `.` 目录挂载到 Docker 容器中的 `/project` 目录，并确保容器内的环境适合 ESP32 项目的编译。

## PowerShell 脚本 (`esp-idf-menu.ps1`)

`esp-idf-menu.ps1` 是一个基于 PowerShell 的菜单脚本，允许您与 ESP32 Docker 容器交互并管理 ESP32 项目。它包括创建项目、设置目标芯片、编译项目、配置设置以及烧录操作等功能。下面是该脚本的使用说明：

### 使用说明

1. **创建项目**：使用此选项，您可以在指定的目录中创建新的 ESP32 项目。
2. **设置目标芯片**：此选项用于设置目标芯片（例如 `esp32s3` 或 `esp32s2`）。
3. **编译项目**：选择此选项后，脚本会在指定的项目目录下执行 `idf.py build` 命令，开始编译项目。
4. **配置项目**：该选项会运行 `idf.py menuconfig`，以图形化界面进行项目配置。
5. **进入容器终端**：您可以选择进入 ESP-IDF Docker 容器的交互式终端，在容器内执行命令。
6. **启动串口服务器**：通过选择此选项，您可以启动串口服务器（`esp_rfc2217_server`），通过 RFC2217 协议进行串口通信。
7. **烧录程序**：选择此选项后，脚本会通过 `idf.py flash` 命令将程序烧录到 ESP32 设备上。
8. **串口监视器**：此选项会启动 `idf.py monitor` 命令，连接到 ESP32 设备并显示输出。

### 使用步骤

1. 打开 PowerShell 窗口，导航到包含 `esp-idf-menu.ps1` 脚本的目录。

2. 运行脚本：

   ```powershell
   .\esp-idf-menu.ps1
   ```

3. 脚本会显示一个菜单，您可以选择需要执行的操作。

### 注意事项

- 在执行某些操作时（如创建项目、设置目标芯片等），脚本会提示您输入必要的参数，如项目名称或目标芯片名称。
- 脚本会自动检测并安装 `esptool`，如果没有安装，它会尝试执行 `install_esptool.py` 脚本。

## Bash 脚本 (`esp-idf-menu.sh`)

对于 Linux 或 macOS 用户，您可以使用 `esp-idf-menu.sh` 脚本，它与 `esp-idf-menu.ps1` 脚本的功能相同。以下是该脚本的使用步骤：

1. 打开终端，导航到包含 `esp-idf-menu.sh` 脚本的目录。

2. 运行脚本：

   ```bash
   ./esp-idf-menu.sh
   ```

3. 脚本会显示一个菜单，您可以选择执行相应的操作。

## GitHub Actions 自动构建与发布（`.github/workflows/esp32.yml`）

此工作流会在您推送 tag（如 `v1.0.0`）到 `release` 分支时自动触发，并完成固件编译与 GitHub Release 发布。

### 自动构建与发布流程

1. **触发条件**：
   - 推送 tag（格式如 `v1.0.0`）到 `release` 分支
   - 或使用 GitHub 手动触发按钮
2. **构建步骤**：
   - 使用 `docker compose` 启动 `espressif/idf` 容器
   - 运行 `idf.py set-target <芯片型号>` 设置目标芯片
   - 编译固件
   - 将产物重命名为版本化名称，如：`esp32c3-v1.0.0.bin`
3. **发布步骤**：
   - 上传构建产物为 Artifact
   - 使用 [`softprops/action-gh-release`](https://github.com/softprops/action-gh-release) 创建 GitHub Release 并附加产物

### 更换目标芯片

默认构建的是 **ESP32-C3**（`esp32c3`）。如果您使用其他芯片，请在 `.github/workflows/esp32.yml` 中手动修改这两处：

```
yaml复制编辑# 将 esp32c3 替换为您的目标芯片（如 esp32、esp32s3）
idf.py set-target esp32c3
mv build/*.bin build/esp32c3-${VERSION}.bin
```

例如，如果您的芯片是 ESP32-S3，修改如下：

```
yaml复制编辑idf.py set-target esp32s3
mv build/*.bin build/esp32s3-${VERSION}.bin
```

请确保修改 `.bin`、`.elf`、`.map` 的命名一致。

### 注意事项

- 与 PowerShell 脚本类似，`esp-idf-menu.sh` 脚本会提示您输入必要的参数，并帮助您完成 ESP32 项目的管理。

## 总结

通过使用 Docker 和提供的脚本，您可以轻松地在隔离的环境中进行 ESP32 项目的开发。无论是在 Windows 还是 Linux/macOS 系统上，您都可以根据自己的需求运行相应的脚本来管理项目的生命周期。

如果遇到问题，请检查 Docker 配置和相关依赖是否正确安装，并确保按照文档中的步骤操作。
