[CmdletBinding()]
param(
    [string] $SptPath,

    [switch] $NoRestore
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$projectRoot = Join-Path $repositoryRoot 'src\SPT.MultiplyWeightLimits'
$projectPath = Join-Path $projectRoot 'SPT.MultiplyWeightLimits.csproj'
$localPropsPath = Join-Path $repositoryRoot 'Directory.Build.props.user'
$nugetConfigPath = Join-Path $repositoryRoot 'NuGet.Config'

if ([string]::IsNullOrWhiteSpace($SptPath) -and (Test-Path -LiteralPath $localPropsPath -PathType Leaf)) {
    [xml] $localProps = Get-Content -LiteralPath $localPropsPath -Raw
    $configuredPath = @($localProps.Project.PropertyGroup | ForEach-Object { $_.SptPath } | Where-Object { $_ })
    if ($configuredPath.Count -gt 0) {
        $SptPath = [string] $configuredPath[0]
    }
}

if ([string]::IsNullOrWhiteSpace($SptPath)) {
    throw 'SPT path is not configured. Pass -SptPath or create Directory.Build.props.user.'
}

$resolvedSptPath = (Resolve-Path -LiteralPath $SptPath).Path
$sptRuntimePath = Join-Path $resolvedSptPath 'SPT_Runtime'
if (-not (Test-Path -LiteralPath (Join-Path $sptRuntimePath 'SPTarkov.Server.Core.dll') -PathType Leaf)) {
    throw "SPT 4.1 runtime assemblies were not found under: $sptRuntimePath"
}

$msbuildProperty = "-p:SptPath=$resolvedSptPath"
if (-not $NoRestore) {
    & dotnet restore $projectPath --configfile $nugetConfigPath $msbuildProperty
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet restore failed with exit code $LASTEXITCODE."
    }
}

& dotnet build $projectPath --configuration Release --no-restore $msbuildProperty '-p:ContinuousIntegrationBuild=true'
if ($LASTEXITCODE -ne 0) {
    throw "dotnet build failed with exit code $LASTEXITCODE."
}

$buildOutputRoot = Join-Path $projectRoot 'bin\Release\SPT-MultiplyWeightLimits'
$modDll = Join-Path $buildOutputRoot 'SPT-MultiplyWeightLimits.dll'
$configFile = Join-Path $buildOutputRoot 'config\config.json'

foreach ($requiredFile in @($modDll, $configFile)) {
    if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
        throw "Expected build output not found: $requiredFile"
    }
}

$artifactsRoot = Join-Path $repositoryRoot 'artifacts'
$packageRoot = Join-Path $artifactsRoot 'package'
$modPackageRoot = Join-Path $packageRoot 'SPT_Runtime\user\mods\SPT-MultiplyWeightLimits'
$configPackageRoot = Join-Path $modPackageRoot 'config'
$distRoot = Join-Path $repositoryRoot 'dist'
$zipPath = Join-Path $distRoot 'SPT-MultiplyWeightLimits-4.1.0.zip'

foreach ($safePath in @($artifactsRoot, $distRoot)) {
    $fullPath = [System.IO.Path]::GetFullPath($safePath)
    if (-not $fullPath.StartsWith($repositoryRoot + [System.IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to modify a path outside the repository: $fullPath"
    }
}

if (Test-Path -LiteralPath $packageRoot) {
    Remove-Item -LiteralPath $packageRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $configPackageRoot -Force | Out-Null
New-Item -ItemType Directory -Path $distRoot -Force | Out-Null

Copy-Item -LiteralPath $modDll -Destination $modPackageRoot
Copy-Item -LiteralPath $configFile -Destination $configPackageRoot

$packagedFiles = @(Get-ChildItem -LiteralPath $packageRoot -Recurse -File)
if ($packagedFiles.Count -ne 2) {
    throw "Expected exactly two packaged files, found $($packagedFiles.Count)."
}

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}
Compress-Archive -Path (Join-Path $packageRoot '*') -DestinationPath $zipPath -CompressionLevel Optimal

$hash = Get-FileHash -LiteralPath $zipPath -Algorithm SHA256
Write-Host "Release created: $zipPath"
Write-Host "SHA256: $($hash.Hash)"
