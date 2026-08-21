Set-StrictMode -Version Latest

$script:MawSkillName = 'multiple-agent-workflow-config'
$script:MawUtf8NoBom = [Text.UTF8Encoding]::new($false)

function Get-MawHome {
    if (-not [string]::IsNullOrWhiteSpace($env:MAW_HOME)) {
        return [IO.Path]::GetFullPath($env:MAW_HOME)
    }
    [IO.Path]::GetFullPath($HOME)
}

function Get-MawRepositoryRoot {
    [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
}

function Find-MawDistributionRoot {
    param([Parameter(Mandatory)][string]$StartPath)

    $current = [IO.DirectoryInfo]::new([IO.Path]::GetFullPath($StartPath))
    while ($null -ne $current) {
        if ([IO.File]::Exists((Join-Path $current.FullName 'distribution-manifest.json'))) {
            return $current.FullName
        }
        $current = $current.Parent
    }
    return $null
}

function Read-MawJson {
    param([Parameter(Mandatory)][string]$Path)

    if (-not [IO.File]::Exists($Path)) {
        throw "JSON file does not exist: '$Path'."
    }
    [IO.File]::ReadAllText($Path) | ConvertFrom-Json
}

function Write-MawJson {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Value
    )

    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path))
    $temporary = "$Path.$([Guid]::NewGuid().ToString('N')).tmp"
    [IO.File]::WriteAllText(
        $temporary,
        ($Value | ConvertTo-Json -Depth 12),
        $script:MawUtf8NoBom
    )
    [IO.File]::Move($temporary, $Path, $true)
}

function Get-MawFileHash {
    param([Parameter(Mandatory)][string]$Path)

    if (-not [IO.File]::Exists($Path)) {
        throw "Cannot hash missing file: '$Path'."
    }
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Test-MawPathWithin {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Candidate
    )

    $rootPath = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $candidatePath = [IO.Path]::GetFullPath($Candidate)
    $candidatePath.StartsWith($rootPath, [StringComparison]::OrdinalIgnoreCase)
}

function Resolve-MawSkillSource {
    param([Parameter(Mandatory)][string]$SourceRoot)

    $root = [IO.Path]::GetFullPath($SourceRoot)
    foreach ($candidate in @(
        (Join-Path $root "src\skills\$script:MawSkillName"),
        (Join-Path $root "skills\$script:MawSkillName"),
        (Join-Path $root $script:MawSkillName),
        $root
    )) {
        if ([IO.File]::Exists((Join-Path $candidate 'SKILL.md'))) {
            return [IO.Path]::GetFullPath($candidate)
        }
    }
    throw "Could not locate '$script:MawSkillName' below '$root'."
}

function Get-MawClientTarget {
    param([Parameter(Mandatory)][ValidateSet('Codex', 'Claude', 'ZCode')][string]$Client)

    $base = switch ($Client) {
        'Codex' { Join-Path (Get-MawHome) '.agents\skills' }
        'Claude' { Join-Path (Get-MawHome) '.claude\skills' }
        'ZCode' { Join-Path (Get-MawHome) '.zcode\skills' }
    }
    Join-Path $base $script:MawSkillName
}

function Get-MawRecordPath {
    param([Parameter(Mandatory)][ValidateSet('Codex', 'Claude', 'ZCode')][string]$Client)

    Join-Path (Get-MawHome) ".maw\installations\$script:MawSkillName\$Client.json"
}

function Get-MawBackupRoot {
    $stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
    Join-Path (Get-MawHome) ".maw\backups\$script:MawSkillName\$stamp"
}

function Get-MawLinkTarget {
    param([Parameter(Mandatory)][string]$Path)

    $item = Get-Item -LiteralPath $Path -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) {
        return $null
    }
    $target = @($item.Target)[0]
    if ([string]::IsNullOrWhiteSpace([string]$target)) {
        return $null
    }
    [IO.Path]::GetFullPath([string]$target)
}

function Get-MawPackageVersion {
    param([Parameter(Mandatory)][string]$SourceRoot)

    $root = Find-MawDistributionRoot $SourceRoot
    if ($null -ne $root) {
        return [string](Read-MawJson (Join-Path $root 'distribution-manifest.json')).packageVersion
    }
    'unknown'
}

function New-MawInstallationRecord {
    param(
        [Parameter(Mandatory)][string]$Client,
        [Parameter(Mandatory)][string]$Mode,
        [Parameter(Mandatory)][string]$Target,
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$InstallationId
    )

    [ordered]@{
        schemaVersion = 1
        installationId = $InstallationId
        skillName = $script:MawSkillName
        client = $Client
        mode = $Mode
        target = [IO.Path]::GetFullPath($Target)
        source = [IO.Path]::GetFullPath($Source)
        version = $Version
        skillHash = Get-MawFileHash (Join-Path $Source 'SKILL.md')
        installedAtUtc = [DateTime]::UtcNow.ToString('o')
    }
}
