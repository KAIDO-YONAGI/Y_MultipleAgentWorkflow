function Resolve-WorkflowTemplate {
    param([Parameter(Mandatory)][string]$ScriptRoot)

    foreach ($relativePath in @(
        '..\assets\workflow-template',
        '..\templates\workflow-template'
    )) {
        $candidate = [IO.Path]::GetFullPath((Join-Path $ScriptRoot $relativePath))
        if ([IO.Directory]::Exists($candidate)) {
            return [pscustomobject]@{
                AssetRoot = $candidate
                TemporaryRoot = $null
            }
        }
    }

    $archivePath = [IO.Path]::GetFullPath(
        (Join-Path $ScriptRoot '..\templates\workflow-template.zip')
    )
    if (-not [IO.File]::Exists($archivePath)) {
        throw "Workflow template was not found beside '$ScriptRoot'."
    }

    [void](Add-Type -AssemblyName System.IO.Compression.FileSystem)
    $temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) `
        "maw-template-$([Guid]::NewGuid().ToString('N'))"
    $temporaryRoot = [IO.Path]::GetFullPath($temporaryRoot)
    $rootPrefix = $temporaryRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    [void][IO.Directory]::CreateDirectory($temporaryRoot)
    $archive = $null

    try {
        $archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
        foreach ($entry in $archive.Entries) {
            $entryName = [string]$entry.FullName
            $isDirectory = $entryName.EndsWith('/')
            $pathName = if ($isDirectory) {
                $entryName.Substring(0, $entryName.Length - 1)
            }
            else {
                $entryName
            }
            $segments = @($pathName -split '/')
            if ([string]::IsNullOrWhiteSpace($entryName) -or
                [IO.Path]::IsPathRooted($pathName) -or
                @($segments | Where-Object {
                    $_ -in @('', '.', '..') -or $_.Contains(':')
                }).Count -gt 0) {
                throw "Unsafe path in workflow template archive: '$entryName'."
            }

            $relativePath = $pathName.Replace('/', [IO.Path]::DirectorySeparatorChar)
            $destination = [IO.Path]::GetFullPath(
                (Join-Path $temporaryRoot $relativePath)
            )
            if (-not $destination.StartsWith(
                    $rootPrefix,
                    [StringComparison]::OrdinalIgnoreCase
                )) {
                throw "Workflow template entry escapes its extraction directory: '$entryName'."
            }

            if ($isDirectory) {
                [void][IO.Directory]::CreateDirectory($destination)
                continue
            }

            $parent = [IO.Path]::GetDirectoryName($destination)
            [void][IO.Directory]::CreateDirectory($parent)
            $inputStream = $null
            $outputStream = $null
            try {
                $inputStream = $entry.Open()
                $outputStream = [IO.File]::Open(
                    $destination,
                    [IO.FileMode]::CreateNew,
                    [IO.FileAccess]::Write,
                    [IO.FileShare]::None
                )
                $inputStream.CopyTo($outputStream)
            }
            finally {
                if ($null -ne $outputStream) { $outputStream.Dispose() }
                if ($null -ne $inputStream) { $inputStream.Dispose() }
            }
        }

        if (-not [IO.File]::Exists(
                (Join-Path $temporaryRoot 'Workflow\Scripts\WorkingAgent.ps1')
            )) {
            throw 'Workflow template archive is missing Workflow/Scripts/WorkingAgent.ps1.'
        }

        [pscustomobject]@{
            AssetRoot = $temporaryRoot
            TemporaryRoot = $temporaryRoot
        }
    }
    catch {
        if ([IO.Directory]::Exists($temporaryRoot)) {
            Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
        }
        throw
    }
    finally {
        if ($null -ne $archive) {
            $archive.Dispose()
        }
    }
}
