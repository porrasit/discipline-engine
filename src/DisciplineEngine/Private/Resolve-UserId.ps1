function Resolve-UserId {
    <#
    .SYNOPSIS
    Internal helper: resolve the effective UserId for a Public function.

    .DESCRIPTION
    Applies the precedence rules every Public function shares:
        1. If -UserId is supplied (non-empty), use it.
        2. Otherwise, fall back to $env:DISCIPLINE_ENGINE_DEFAULT_USER.
        3. If neither is set, throw a clear error.

    Centralizing this means the fallback rule and the error message live in
    ONE place — when we tighten onboarding in Phase 3, we change it here.

    .PARAMETER UserId
    What the caller passed for -UserId (may be empty / $null).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # AllowEmptyString + AllowNull lets callers forward whatever they
        # received from their own -UserId parameter without pre-checking.
        [Parameter()]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$UserId
    )

    # [string]::IsNullOrWhiteSpace handles $null, '', and '   ' in one check.
    $resolved =
        if (-not [string]::IsNullOrWhiteSpace($UserId)) {
            $UserId
        }
        elseif (-not [string]::IsNullOrWhiteSpace($env:DISCIPLINE_ENGINE_DEFAULT_USER)) {
            $env:DISCIPLINE_ENGINE_DEFAULT_USER
        }
        else {
            # `throw` raises a terminating error. The string becomes the
            # error message; callers can catch it with try/catch. We phrase
            # the message so the user knows both ways to fix it.
            throw 'UserId required. Set -UserId or $env:DISCIPLINE_ENGINE_DEFAULT_USER.'
        }

    # Users are created by onboarding — writing habits for a user who has
    # no profile.json means either a typo or a skipped onboarding. Either
    # way it's a bug, not something to silently paper over by creating a
    # new folder. Check that the user exists (represented by the presence
    # of profile.json) and fail with a distinct, actionable message.
    $profilePath = Join-Path $script:DataRoot "users/$resolved/profile.json"
    if (-not (Test-Path -Path $profilePath)) {
        throw "User '$resolved' does not exist (no profile.json at $profilePath). Run onboarding first."
    }

    return $resolved
}
