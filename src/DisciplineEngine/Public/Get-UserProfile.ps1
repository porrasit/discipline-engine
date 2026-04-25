function Get-UserProfile {
    <#
    .SYNOPSIS
    Load a user's profile.json as a PowerShell object.

    .DESCRIPTION
    Reads data/users/<UserId>/profile.json and returns it as a parsed
    object. The profile carries occupation, demographics, habit targets,
    interests, side-income context, and scheduling preferences — downstream
    callers (tip generation, news selection, coaching prompts) consume it
    to personalize Claude output.

    .PARAMETER UserId
    Which user's profile to load. Falls back to
    $env:DISCIPLINE_ENGINE_DEFAULT_USER if not supplied. Throws if neither
    is set. Throws a distinct error if the profile file does not exist.

    .EXAMPLE
    Get-UserProfile

    .EXAMPLE
    Get-UserProfile -UserId poom

    .EXAMPLE
    # Peek at a single nested field:
    (Get-UserProfile).occupation.techStack
    #>
    [CmdletBinding()]
    param(
        # Optional at the parameter level; Resolve-UserId applies the
        # fallback / error rule, keeping behavior consistent with
        # Add-HabitEntry and Get-HabitSummary.
        [string]$UserId
    )

    # Apply the standard UserId resolution rules.
    $UserId = Resolve-UserId -UserId $UserId

    # Build the per-user profile path under the module's $script:DataRoot
    # (set once at import time in DisciplineEngine.psm1). Using the same
    # root variable as the habit helpers means one env-var override
    # (DISCIPLINE_ENGINE_DATA_ROOT) moves ALL storage together.
    $path = Join-Path $script:DataRoot "users/$UserId/profile.json"

    if (-not (Test-Path -Path $path)) {
        # Terminating error so callers don't silently get $null and then
        # try to index into it. The message names the missing file so it's
        # obvious what to create.
        throw "Profile not found for user '$UserId' at: $path"
    }

    # Get-Content -Raw returns the whole file as one string (default is an
    # array of lines, which ConvertFrom-Json can't consume directly).
    $json = Get-Content -Path $path -Raw

    # ConvertFrom-Json turns the JSON text into PSCustomObjects, with
    # nested objects navigable via dot notation (e.g. $profile.occupation.role).
    return $json | ConvertFrom-Json
}
