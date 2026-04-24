function Get-HabitStore {
    <#
    .SYNOPSIS
    Internal helper: read the habit store file and return entries as objects.

    .DESCRIPTION
    Reads a JSON file containing an array of habit entries and returns them
    as PowerShell objects. A missing or empty file is treated as "no entries"
    so first-run callers don't have to special-case it.

    This function is intentionally PRIVATE so that Public functions never
    touch the JSON file directly. When we migrate to Azure Table Storage,
    only this function and Save-HabitStore change.
    #>

    # [CmdletBinding()] turns a plain function into an "advanced function":
    # it automatically gets -Verbose, -Debug, -ErrorAction, etc. It's the
    # idiomatic choice for any function worth writing.
    [CmdletBinding()]
    param(
        # [Parameter(Mandatory)] means "the caller MUST supply this".
        # PowerShell will prompt or error if it's missing.
        [Parameter(Mandatory)]
        [string]$Path
    )

    # Test-Path returns $true if something exists at the given path.
    # On first run the file doesn't exist — behave like an empty store.
    if (-not (Test-Path -Path $Path)) {
        return @()
    }

    # Get-Content reads a file. -Raw returns the WHOLE file as one string
    # (otherwise you get an array of lines, which ConvertFrom-Json can't
    # consume directly).
    $json = Get-Content -Path $Path -Raw

    # [string]::IsNullOrWhiteSpace is a .NET method we can call directly.
    # Guards against an empty/whitespace file which would make ConvertFrom-Json
    # throw.
    if ([string]::IsNullOrWhiteSpace($json)) {
        return @()
    }

    # ConvertFrom-Json turns a JSON string into PowerShell objects
    # (PSCustomObjects for JSON objects, arrays for JSON arrays).
    $entries = $json | ConvertFrom-Json

    # This is the "comma operator" trick. PowerShell normally UNWRAPS a
    # single-element array when you `return` it — callers would receive
    # one object instead of an array of one. Prefixing with `,` wraps the
    # value in an outer array, which return then unwraps, leaving the
    # inner array (even if it has 0 or 1 items) intact.
    return ,@($entries)
}
