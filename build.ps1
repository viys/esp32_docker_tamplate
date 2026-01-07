param (
    [Parameter(Position = 0, Mandatory = $true)]
    [ValidateSet(
        "create-project",
        "set-target",
        "menuconfig",
        "build",
        "bash",
        "esp_rfc2217_server",
        "flash",
        "monitor",
        "help"
    )]
    [string]$Action,

    [Parameter(Position = 1)]
    [string]$Param
)

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

function Invoke-CreateProject {
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$ProjectName
    )

    docker-compose run --rm esp-idf idf.py create-project $ProjectName

    $projPath   = Join-Path -Path (Get-Location) -ChildPath $ProjectName
    $parentPath = Split-Path -Path $projPath -Parent

    Get-ChildItem -Path $projPath -Force | ForEach-Object {
        $destination = Join-Path $parentPath $_.Name
        Move-Item -Path $_.FullName -Destination $destination -Force
    }

    Remove-Item -Path $projPath -Recurse -Force
}

function Invoke-SetTarget {
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$Target
    )

    docker-compose run --rm esp-idf idf.py set-target $Target
}

function Invoke-Menuconfig {
    docker-compose run --rm esp-idf idf.py menuconfig
}

function Invoke-Build {
    docker-compose run --rm esp-idf idf.py build
}

function Invoke-Bash {
    docker-compose run --rm esp-idf bash
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

function Invoke-EspRfc2217Server {
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$Port
    )
    if (Initialize-Esptool) {
        Push-Location "scripts\esptool-win64"
        .\esp_rfc2217_server -v -p 4000 $Port
        Pop-Location
    }
}

function Invoke-Flash {
    docker-compose run --rm esp-idf idf.py --port "rfc2217://host.docker.internal:4000?ign_set_control" flash
}

function Invoke-Monitor {
    docker-compose run --rm esp-idf idf.py --port "rfc2217://host.docker.internal:4000?ign_set_control" monitor
}

function Invoke-Help {
    Write-Host ""
    Write-Host "ESP-IDF Docker 管理脚本 使用说明" -ForegroundColor Cyan
    Write-Host "===================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "create-project <项目名>：创建项目" -ForegroundColor Yellow
    Write-Host "   使用 create-project 创建新的 ESP-IDF 项目。"
    Write-Host "   脚本将调用 idf.py create-project，并生成基础项目结构。"
    Write-Host ""

    Write-Host "set-target <芯片名>：设置目标芯片" -ForegroundColor Yellow
    Write-Host "   设置 ESP-IDF 项目的目标芯片类型。"
    Write-Host "   常见示例：esp32、esp32s2、esp32s3、esp32c3 等。"
    Write-Host ""

    Write-Host "menuconfig：项目配置" -ForegroundColor Yellow
    Write-Host "   打开 ESP-IDF 的 menuconfig 配置界面。"
    Write-Host "   可用于配置组件、外设、日志等级等参数。"
    Write-Host ""

    Write-Host "build：编译项目" -ForegroundColor Yellow
    Write-Host "   编译当前 ESP-IDF 项目。"
    Write-Host "   成功后会生成可用于烧录的固件文件。"
    Write-Host ""

    Write-Host "bash：进入容器终端" -ForegroundColor Yellow
    Write-Host "   打开 ESP-IDF Docker 容器的交互式 Bash 终端。"
    Write-Host "   适合手动执行 idf.py 或调试环境问题。"
    Write-Host ""

    Write-Host "esp_rfc2217_server <串口>：启动串口服务器" -ForegroundColor Yellow
    Write-Host "   启动 RFC2217 串口服务器。"
    Write-Host "   示例：esp_rfc2217_server COM3"
    Write-Host "   用于通过网络方式将本地串口映射给 Docker 容器。"
    Write-Host ""

    Write-Host "flash：烧录固件" -ForegroundColor Yellow
    Write-Host "   通过 RFC2217 网络串口将固件烧录到目标设备。"
    Write-Host "   需要先启动 esp_rfc2217_server。"
    Write-Host ""

    Write-Host "monitor：串口监视" -ForegroundColor Yellow
    Write-Host "   连接到目标设备串口并实时监视输出日志。"
    Write-Host "   同样依赖 RFC2217 串口服务器。"
    Write-Host ""

    Write-Host "help：显示帮助：" -ForegroundColor Yellow
    Write-Host "   显示本帮助信息。"
    Write-Host ""

    Write-Host "使用示例：" -ForegroundColor Cyan
    Write-Host "  .\build.ps1 create-project my_app"
    Write-Host "  .\build.ps1 set-target esp32s3"
    Write-Host "  .\build.ps1 menuconfig"
    Write-Host "  .\build.ps1 build"
    Write-Host "  .\build.ps1 flash"
    Write-Host ""
}

try {

    if ($Action -ne "help" -and -not (Test-Docker)) {
        exit
    }

    switch ($Action) {
        "create-project" {
            if (-not $Param) {
                $Param = Read-Host "请输入目标项目名称"
            }
            Invoke-CreateProject -ProjectName $Param
        }
        "set-target" {
            if (-not $Param) {
                $Param = Read-Host "请输入目标芯片名称（如：esp32s3）"
            }
            Invoke-SetTarget -Target $Param
        }
        "menuconfig" {
            Invoke-Menuconfig
        }
        "build" {
            Invoke-Build
        }
        "bash" {
            Invoke-Bash
        }
        "esp_rfc2217_server" {
            if (-not $Param) {
                $Param = Read-Host "请输入目标串口设备名称（如：COM3）"
            }
            Invoke-EspRfc2217Server -Port $Param
        }
        "flash" {
            Invoke-Flash
        }
        "monitor" {
            Invoke-Monitor
        }
        "help" {
            Invoke-Help
        }
        Default {
            Invoke-Help
        }
    }
}
catch {
    Write-Host $_ -ForegroundColor Red
}
