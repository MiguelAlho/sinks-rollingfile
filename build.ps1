param(
    [parameter(Position=0)][string] $PreReleaseSuffix = ''
)

$autoGeneratedVersion = $false

# Generate version number if not set
if ($env:build_number -eq $null) {
    $autoVersion = [math]::floor((New-TimeSpan $(Get-Date) $(Get-Date -month 1 -day 1 -year 2016 -hour 0 -minute 0 -second 0)).TotalMinutes * -1).ToString() + "-" + (Get-Date).ToString("ss")
    $env:build_number = "rc1-" + $autoVersion
    $autoGeneratedVersion = $true
    
    Write-Host "Set version to $autoVersion"
}

ls */*/project.json | foreach { echo $_.FullName} |
foreach {
    $content = get-content "$_"
    $content = $content.Replace("2.0.0-*", "2.0.0-$env:build_number")
    set-content "$_" $content -encoding UTF8
}

# Restore packages and build product
& dotnet restore # Restore all packages
if ($LASTEXITCODE -ne 0)
{
    throw "dotnet restore failed with exit code $LASTEXITCODE"
}

# Build all
dir "src/*" | where {$_.PsIsContainer} |
foreach {
    if ($PreReleaseSuffix) {
        & dotnet build "$_" --version-suffix "$PreReleaseSuffix"
    } else {
        & dotnet build "$_"
    }
}
# Run tests
dir "test/*" | where {$_.PsIsContainer} |
foreach {
    & dotnet test "$_"
}
# Package all
dir "src/*" | where {$_.PsIsContainer} |
foreach {
    if ($PreReleaseSuffix) {
        & dotnet pack "$_" -c Release -o .\.nupkg\ --version-suffix "$PreReleaseSuffix"   
    } else {
        & dotnet pack "$_" -c Release -o .\.nupkg\
    }
}

ls */*/project.json | foreach { echo $_.FullName} |
foreach {
    $content = get-content "$_"
    $content = $content.Replace("2.0.0-$env:build_number", "2.0.0-*")
    set-content "$_" $content -encoding UTF8
}

if ($autoGeneratedVersion){
    $env:build_number = $null
}