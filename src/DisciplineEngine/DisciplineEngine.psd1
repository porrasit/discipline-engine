# DisciplineEngine.psd1 — the module MANIFEST.
#
# A manifest is a plain .ps1-style file that evaluates to a hashtable.
# PowerShell reads it when you run `Import-Module DisciplineEngine` and uses
# the keys below to decide how to load the module. You could generate this
# file with `New-ModuleManifest`, but hand-editing is standard once you
# know what the keys mean.

@{
    # The .psm1 file that actually contains (or loads) the module code.
    # When the manifest is imported, PowerShell runs this script.
    RootModule = 'DisciplineEngine.psm1'

    # Semantic version. Bump this when you ship a new version.
    ModuleVersion = '0.1.0'

    # A unique ID for the module. Generate a fresh one with: [guid]::NewGuid()
    GUID = 'b3c4d5e6-f7a8-4b9c-ad1e-2f3a4b5c6d7e'

    Author      = 'Poom_R'
    Description = 'Personal habit-tracking core module (exercise, sleep, self-development).'

    # Minimum PowerShell version. 7.2 = current LTS and the baseline
    # supported by Azure Automation runbooks.
    PowerShellVersion = '7.2'

    # Only the functions listed here are visible to callers after import.
    # Anything in Private/ stays internal to the module. Keep this list in
    # sync with the file names under Public/.
    FunctionsToExport = @(
        'Add-HabitEntry'
        'Get-HabitSummary'
    )

    # Explicitly export nothing else. Empty arrays make the intent clear
    # and help catch accidentally-leaked cmdlets/aliases/variables.
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
