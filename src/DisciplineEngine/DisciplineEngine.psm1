# DisciplineEngine.psm1 — the ROOT MODULE.
#
# Import-Module reads the manifest, sees RootModule = this file, and runs it
# once. Its only job is to load every function defined under Public/ and
# Private/, then declare which ones callers are allowed to see.
#
# The Public/Private folder split is a common convention: Public/ holds
# user-facing functions (one per file, named to match the function), and
# Private/ holds internal helpers that the public functions call.

# $PSScriptRoot is an AUTOMATIC VARIABLE — PowerShell sets it to the folder
# this script lives in, no matter where the caller ran the import from.
# Using it for paths makes the module relocatable.
$publicPath  = Join-Path $PSScriptRoot 'Public'
$privatePath = Join-Path $PSScriptRoot 'Private'

# --- Data root resolution --------------------------------------------------
# The module ships at  <repo>/src/DisciplineEngine/  and data lives at
# <repo>/data/ — so two levels up from $PSScriptRoot. Resolve once at import
# time and stash in a module-scoped variable so every helper uses the same
# path, and we have a single seam to swap for Azure Table Storage later.
#
# $script:Foo  is a SCOPE MODIFIER — the variable lives at module scope and
# is visible to every function defined in this module, but NOT to callers.
# That's what we want for internal state.
#
# $env:DISCIPLINE_ENGINE_DATA_ROOT lets Azure Automation or tests point the
# module at a different folder without code changes.
if ($env:DISCIPLINE_ENGINE_DATA_ROOT) {
    $script:DataRoot = $env:DISCIPLINE_ENGINE_DATA_ROOT
}
else {
    # Join-Path with '..' segments works, but Resolve-Path (or the .NET
    # [System.IO.Path]::GetFullPath) collapses them into a clean absolute
    # path. We use GetFullPath because it doesn't error if the folder is
    # missing — first-run friendliness.
    $script:DataRoot = [System.IO.Path]::GetFullPath(
        (Join-Path $PSScriptRoot '..' '..' 'data')
    )
}

# Get-ChildItem is the equivalent of `ls`. -Filter '*.ps1' narrows to our
# script files. -ErrorAction SilentlyContinue prevents a crash if a folder
# happens to be empty or missing.
# The @( ... ) wrapper forces the result to an array even when there's only
# one file — otherwise `$publicScripts.BaseName` could fail on a scalar.
$publicScripts  = @(Get-ChildItem -Path $publicPath  -Filter '*.ps1' -ErrorAction SilentlyContinue)
$privateScripts = @(Get-ChildItem -Path $privatePath -Filter '*.ps1' -ErrorAction SilentlyContinue)

# "Dot-sourcing" (the leading `.` followed by a path) runs a script IN THE
# CURRENT SCOPE rather than a child scope. That means any `function` keyword
# inside the script defines the function here, in the module's scope —
# which is exactly what we need to "load" a function from a file.
foreach ($script in @($publicScripts + $privateScripts)) {
    try {
        . $script.FullName
    }
    catch {
        # Surface syntax errors clearly instead of silently failing.
        # Inside a catch block, $_ is the error record.
        Write-Error "Failed to load $($script.Name): $_"
    }
}

# Export-ModuleMember tells PowerShell which definitions callers can see.
# We export every file name (without extension) under Public/. This must
# match the FunctionsToExport list in the .psd1 manifest.
if ($publicScripts) {
    Export-ModuleMember -Function $publicScripts.BaseName
}
