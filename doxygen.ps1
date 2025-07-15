param (
    [string]$Command
)

function Show-Help {
    Write-Host @"
📘 用法：
    .\doxygen.ps1          打开 Doxygen 文档
    .\doxygen.ps1 build    构建 Doxygen 文档
    .\doxygen.ps1 help     显示本帮助信息
"@
}

# -----------------------
# 工具检查函数
# -----------------------

function Check-Doxygen {
    try {
        $version = & doxygen --version 2>$null
        if (-not $version) { throw }
        Write-Host "✔ Doxygen found: version $version"
        return $true
    } catch {
        Write-Warning "❌ Doxygen 未找到，请访问 https://www.doxygen.nl/download.html 下载并安装。"
        return $false
    }
}

function Check-Graphviz {
    try {
        $dotVersion = & dot -V 2>&1
        if (-not $dotVersion) { throw }
        Write-Host "✔ Graphviz (dot) found: $dotVersion"
        return $true
    } catch {
        Write-Warning "❌ Graphviz 未找到，请访问 https://graphviz.org/download/ 下载并安装。"
        return $false
    }
}

function Convert-MarkdownCode($markdownPath) {
    $content = Get-Content $markdownPath -Raw

    # 使用正则提取所有代码块，并处理它们
    $pattern = '(?ms)(^[ \t]*)(```[^\n]*\r?\n)(.*?)(^\1```)'  # 提取缩进、起始符、代码、结束符

    $converted = [regex]::Replace($content, $pattern, {
        param($m)

        $indent  = $m.Groups[1].Value  # 统一缩进
        $codeRaw = $m.Groups[3].Value  # 原始代码内容（含缩进）

        # 对每行代码移除统一缩进
        $codeLines = $codeRaw.Split("`n")
        $cleanedLines = $codeLines | ForEach-Object {
            $_ -replace "^$indent", ""
        }

        # 拼接成新的 @verbatim 块，保留缩进
        return "$indent@verbatim`n" + ($cleanedLines -join "`n") + "`n@endverbatim"
    })

    return $converted
}

# -----------------------
# 主逻辑根据命令选择
# -----------------------

$Command = $Command.ToLowerInvariant()

switch ($Command) {

    "build" {
        $readmePath = "readme.md"
        $backupPath = "readme.md.bak"

        # 工具检查
        $hasDoxygen = Check-Doxygen
        $hasGraphviz = Check-Graphviz
        if (-not ($hasDoxygen -and $hasGraphviz)) {
            Write-Error "🚫 请先安装缺失的工具后再运行本脚本。"
            exit 1
        }

        # 检查 README
        if (-Not (Test-Path $readmePath)) {
            Write-Error "❌ $readmePath not found."
            exit 1
        }

        # 备份
        Copy-Item -Path $readmePath -Destination $backupPath -Force
        Write-Host "📁 readme.md backup created."

        try {
            $converted = Convert-MarkdownCode($readmePath);
            Set-Content -Path $readmePath -Value $converted -Encoding UTF8
            Write-Host "🔧 Code blocks converted to @verbatim."

            & doxygen.exe .\Doxyfile
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Doxygen executed successfully."

                # 移动 html 内容
                $htmlDir = ".\docs\html"
                $docsDir = ".\docs"

                if (Test-Path $htmlDir) {
                    $items = Get-ChildItem -Path $htmlDir
                    foreach ($item in $items) {
                        $dest = Join-Path $docsDir $item.Name
                        if (Test-Path $dest) {
                            Remove-Item -Path $dest -Recurse -Force
                        }
                        Move-Item -Path $item.FullName -Destination $docsDir
                    }
                    Remove-Item -Path $htmlDir -Recurse -Force
                    Write-Host "📂 Moved contents from docs/html to docs."
                } else {
                    Write-Warning "⚠️ 目录 $htmlDir 不存在，无法移动 HTML 文件。"
                }
            } else {
                Write-Warning "⚠️ Doxygen exited with code $LASTEXITCODE"
            }
        }
        finally {
            Move-Item -Path $backupPath -Destination $readmePath -Force
            Write-Host "🔄 readme.md restored to original."
        }
    }

    "help" { Show-Help }

    default {
        $indexPath = "docs/index.html"
        if (Test-Path $indexPath) {
            Invoke-Item $indexPath
            Write-Host "🌐 正在打开文档：$indexPath"
        } else {
            Write-Error "❌ 未找到文件：$indexPath，请先运行 build 构建文档。"
        }
    }
}
