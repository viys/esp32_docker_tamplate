function Test-Docker {
    try {
        # 检查 Docker 服务是否正在运行
        $dockerStatus = docker info --format '{{.ServerVersion}}'
        if ($dockerStatus) {
            Write-Host "Docker 服务正在运行，版本: $dockerStatus" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "Docker 服务未启动。" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "Docker 未安装或未启动，请启动 Docker。" -ForegroundColor Red
        return $false
    }
}

function Show-Header {
    Write-Host "===============================" -ForegroundColor Cyan
    Write-Host "         ESP-IDF 开发工具         " -ForegroundColor Cyan
    Write-Host "===============================" -ForegroundColor Cyan
}

function Show-Menu {
    Show-Header
    Write-Host "请选择要执行的命令：`n" -ForegroundColor Yellow
    Write-Host "1. 创建项目 (create-project)"
    Write-Host "2. 设置目标芯片 (set-target)"
    Write-Host "3. 配置项目 (menuconfig)"
    Write-Host "4. 编译项目 (build)"
    Write-Host "5. 打开容器终端 (bash)"
    Write-Host "6. 启动串口服务器 (esp_rfc2217_server)"
    Write-Host "7. 烧录程序 (flash)"
    Write-Host "8. 串口监视器 (monitor)"
    Write-Host "9. 脚本使用帮助 (help)"
    Write-Host "0. 退出`n" -ForegroundColor Red
}

function Show-Help {
    Write-Host "`n===============================" -ForegroundColor Yellow
    Write-Host "      ESP-IDF 脚本使用帮助      " -ForegroundColor Yellow
    Write-Host "===============================" -ForegroundColor Yellow
    Write-Host "`n1. 创建项目：使用 create-project 创建新的 ESP-IDF 项目。"
    Write-Host "该命令将会创建一个新的 ESP-IDF 项目目录，并生成基础的项目文件结构。"
    Write-Host "你需要输入项目名称，脚本将会为你自动生成该项目的基础框架。`n"

    Write-Host "2. 设置目标芯片：通过 set-target 设置 ESP-IDF 项目的目标芯片。"
    Write-Host "该命令允许你指定 ESP-IDF 项目编译时使用的目标芯片类型，如 esp32s3、esp32s2 等。`n"

    Write-Host "3. 配置项目：通过 menuconfig 打开 ESP-IDF 项目的配置菜单。"
    Write-Host "该命令启动一个图形化的配置界面，你可以在这里配置项目的各种选项。`n"

    Write-Host "4. 编译项目：通过 build 命令编译指定的 ESP-IDF 项目。"
    Write-Host "该命令将会开始编译项目，生成固件文件，用于后续烧录到目标设备。`n"

    Write-Host "5. 打开ESP IDF容器终端：通过 bash 打开 ESP-IDF 容器的终端。"
    Write-Host "该命令打开一个交互式的终端，你可以直接在容器内执行命令。`n"

    Write-Host "6. 启动串口服务器：通过 esp_rfc2217_server 启动串口服务器，提供与目标设备的串口通信。"
    Write-Host "该命令将启动一个 RFC2217 串口服务器，用于通过网络与目标设备进行串口通信。`n"

    Write-Host "7. 烧录程序：通过 flash 命令将编译好的固件烧录到目标设备。"
    Write-Host "该命令将使用串口或者网络连接，将生成的固件烧录到目标设备。`n"

    Write-Host "8. 串口监视器：通过 monitor 命令连接到目标设备的串口并监视其输出。"
    Write-Host "该命令将打开一个串口监视器，实时显示目标设备的输出信息。`n"

    Write-Host "0. 退出脚本：退出当前脚本的执行。"
    Write-Host "该命令将会终止脚本并退出。`n"

    Write-Host "===============================" -ForegroundColor Yellow
}

function Show-Loading {
    $spinner = @('|', '/', '-', '\')
    $index = 0
    while ($true) {
        Write-Host -NoNewline "$($spinner[$index])"
        Start-Sleep -Milliseconds 100
        Write-Host -NoNewline "`b"
        $index = ($index + 1) % $spinner.Length
    }
}

function Initialize-Esptool {
    $toolPath = "scripts\esptool-win64"
    if (-Not (Test-Path $toolPath)) {
        Write-Host "未找到 $toolPath，正在运行 install_esptool.py 安装..." -ForegroundColor Yellow
        $installScript = "scripts\install_esptool.py"
        if (Test-Path $installScript) {
            python $installScript | Write-Host
            if (-Not (Test-Path $toolPath)) {
                Write-Error "安装失败，目录仍然不存在：$toolPath" -ForegroundColor Red
                return $false
            }
        } else {
            Write-Error "安装脚本未找到：$installScript" -ForegroundColor Red
            return $false
        }
    }
    return $true
}

function Invoke-MenuAction {
    param (
        [int]$Choice
    )

    switch ($Choice) {
        1 {
            $proj = Read-Host "请输入目标项目名称"
            docker-compose run --rm esp-idf idf.py create-project $proj
            $projPath = Join-Path -Path (Get-Location) -ChildPath $proj
            $parentPath = Split-Path -Path $projPath -Parent
            Get-ChildItem -Path $projPath -Force | ForEach-Object {
                $destination = Join-Path $parentPath $_.Name
                Move-Item -Path $_.FullName -Destination $destination -Force
            }
            Remove-Item -Path $projPath -Force
            exit
        }
        2 {
            $target = Read-Host "请输入目标芯片名称（如：esp32s3）"
            docker-compose run --rm esp-idf idf.py set-target $target
            exit
        }
        3 {
            docker-compose run --rm esp-idf idf.py menuconfig
            exit
        }
        4 {
            docker-compose run --rm esp-idf idf.py build
            exit
        }
        5 {
            docker-compose run --rm esp-idf bash
            exit
        }
        6 {
            $port = Read-Host "请输入目标串口设备名称（如：COM3）"
            if (Initialize-Esptool) {
                Push-Location "scripts\esptool-win64"
                .\esp_rfc2217_server -v -p 4000 $port
                Pop-Location
                exit
            }
        }
        7 {
            docker-compose run --rm esp-idf idf.py --port "rfc2217://host.docker.internal:4000?ign_set_control" flash
            exit
        }
        8 {
            docker-compose run --rm esp-idf idf.py --port "rfc2217://host.docker.internal:4000?ign_set_control" monitor
            exit
        }
        9 {
            Show-Help
            exit
        }
        0 {
            Write-Host "退出。" -ForegroundColor Red
            exit
        }
        Default {
            Write-Host "无效选择，请重试。" -ForegroundColor Red
        }
    }
}

# 在脚本开始时检查 Docker 是否启动
if (-Not (Test-Docker)) {
    exit
}

while ($true) {
    Show-Menu
    $selection = Read-Host "请输入数字选择（如 1-8 或 0 退出）"
    if ($selection -match '^\d+$') {
        $selection = [int]$selection
        Invoke-MenuAction -Choice $selection
    } else {
        Write-Host "无效输入，请输入有效数字（0-9）。" -ForegroundColor Red
    }
}
