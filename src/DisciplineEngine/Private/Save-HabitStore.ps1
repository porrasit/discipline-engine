function Save-HabitStore {
    <#
    .SYNOPSIS
    Internal helper: serialize entries to JSON and write them to disk.

    .DESCRIPTION
    Overwrites the file at -Path with a JSON array representing -Entries.
    Creates the parent folder if it does not exist.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        # [AllowEmptyCollection()] permits an empty array to be passed —
        # "no entries" is a valid state we need to be able to save.
        # [object[]] declares the parameter as an array of arbitrary objects.
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Entries
    )

    # Make sure the folder exists before writing.
    # Split-Path -Parent takes a file path and returns the folder part,
    # e.g. 'data/habits.json' -> 'data'.
    $folder = Split-Path -Path $Path -Parent
    if ($folder -and -not (Test-Path -Path $folder -PathType Container)) {
        # New-Item creates a file system item. -ItemType Directory makes it
        # a folder. -Force creates intermediate folders and suppresses the
        # "already exists" error. | Out-Null discards the "created" message.
        New-Item -Path $folder -ItemType Directory -Force | Out-Null
    }

    # ConvertTo-Json has several awkward edge cases around arrays:
    #   - `$arr | ConvertTo-Json` with one item produces a scalar, not [x].
    #   - `-InputObject $arr -AsArray` on an ACTUAL array double-wraps
    #     to [[...]] — -AsArray is designed to wrap a single object.
    # Handle the three cases explicitly so the on-disk shape is always
    # a proper JSON array. @($Entries) normalizes $null / scalar to array.
    $arr = @($Entries)
    $json = switch ($arr.Count) {
        0       { '[]' }
        1       { '[' + (ConvertTo-Json -InputObject $arr[0] -Depth 10) + ']' }
        default { ConvertTo-Json -InputObject $arr -Depth 10 }
    }

    # Set-Content writes the string to a file, creating or overwriting it.
    # -Encoding utf8 keeps the file portable across macOS / Linux / Windows
    # runbooks (the Windows default is UTF-16 with BOM, which can surprise
    # tools that expect plain UTF-8).
    Set-Content -Path $Path -Value $json -Encoding utf8
}
