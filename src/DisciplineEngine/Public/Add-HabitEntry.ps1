function Add-HabitEntry {
    <#
    .SYNOPSIS
    Log one habit completion for a given date.

    .DESCRIPTION
    Appends a new entry to the habit store. The entry records which habit
    was performed (exercise | sleep | development), whether it was
    completed, the date, and optional free-text notes.

    .PARAMETER Habit
    Which habit this entry is for. Must be one of: exercise, sleep, development.

    .PARAMETER Date
    The calendar date the habit applies to. Defaults to today.

    .PARAMETER Completed
    Whether the habit was completed on that date. Defaults to $true.

    .PARAMETER Notes
    Optional free-text notes (e.g. "30 min run", "asleep at 22:15").

    .PARAMETER Path
    Path to the JSON store. Defaults to the DISCIPLINE_ENGINE_STORE
    environment variable if set, otherwise ./data/habits.json.

    .EXAMPLE
    Add-HabitEntry -Habit exercise -Notes '30 min run'

    .EXAMPLE
    Add-HabitEntry -Habit sleep -Date 2026-04-24 -Completed $false -Notes 'bed at 23:40'
    #>
    [CmdletBinding()]
    param(
        # [ValidateSet(...)] is an input-validation attribute: PowerShell
        # rejects any value that isn't in this list BEFORE the function runs,
        # and tab-completion offers these three strings to callers.
        [Parameter(Mandatory)]
        [ValidateSet('exercise', 'sleep', 'development')]
        [string]$Habit,

        # [datetime] lets callers pass a string like '2026-04-24' and
        # PowerShell parses it automatically. .Date (applied in the default)
        # strips any time-of-day component so the stored value is just a day.
        [datetime]$Date = (Get-Date).Date,

        [bool]$Completed = $true,

        [string]$Notes = '',

        # The default uses a subexpression $( ... ) to pick an env var if
        # set, otherwise fall back to a relative path. This makes it easy
        # to override in Azure Automation without changing code.
        [string]$Path = $(if ($env:DISCIPLINE_ENGINE_STORE) {
            $env:DISCIPLINE_ENGINE_STORE
        } else {
            './data/habits.json'
        })
    )

    # Build the new entry. [pscustomobject]@{...} creates an object from a
    # hashtable while preserving key order — important for predictable JSON
    # output. PSCustomObject is PowerShell's go-to "record" type.
    $entry = [pscustomobject]@{
        Date      = $Date.ToString('yyyy-MM-dd')   # ISO date string
        Habit     = $Habit
        Completed = $Completed
        Notes     = $Notes
    }

    # Load existing entries through the private helper. Public code only
    # ever goes through Get-/Save-HabitStore — that's the seam that lets
    # us swap storage backends later.
    $store = Get-HabitStore -Path $Path

    # `+=` on an array builds a NEW array with the extra element.
    # (PowerShell arrays are fixed-size under the hood — fine for our
    # small, human-scale dataset; for thousands of entries you'd switch
    # to System.Collections.Generic.List[object].)
    $store += $entry

    # Persist the updated list.
    Save-HabitStore -Path $Path -Entries $store

    # Return the entry we just saved so callers/scripts can log it or
    # pipe it into another cmdlet.
    return $entry
}
