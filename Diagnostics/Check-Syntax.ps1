# Toolkit self-check 1/2: PowerShell syntax check of every script in the toolkit.
# Also flags PowerShell 7-only syntax (the toolkit targets Windows PowerShell 5.1)
# and non-ASCII characters in files without a BOM (5.1 reads those as ANSI).
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
$A = 'Toolkit syntax check'
Write-Header $A

$sep = [System.IO.Path]::DirectorySeparatorChar
$skipParts = @("${sep}Config${sep}backup${sep}", "${sep}Reports${sep}", "${sep}Logs${sep}")
$files = @(Get-ChildItem -LiteralPath $root -Filter '*.ps1' -File -Recurse -ErrorAction SilentlyContinue | Where-Object {
    $p = $_.FullName
    $skip = $false
    foreach ($s in $skipParts) { if ($p.Contains($s)) { $skip = $true } }
    -not $skip
} | Sort-Object FullName)

$ps7Only = @('AndAnd', 'OrOr', 'QuestionQuestion', 'QuestionQuestionEquals', 'QuestionDot', 'QuestionLBracket', 'QuestionMark')
$errors = 0
$warnings = 0
$checked = 0
foreach ($f in $files) {
    $checked++
    $rel = $f.FullName.Substring($root.Length).TrimStart('\', '/')
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$parseErrors)
    $fileBad = $false
    foreach ($e in @($parseErrors)) {
        Write-Fail ("{0} line {1}: {2}" -f $rel, $e.Extent.StartLineNumber, $e.Message)
        $errors++
        $fileBad = $true
    }
    foreach ($t in @($tokens)) {
        $k = $t.Kind.ToString()
        if ($ps7Only -contains $k) {
            Write-Fail ("{0} line {1}: PowerShell 7-only operator '{2}' (not valid in Windows PowerShell 5.1)" -f $rel, $t.Extent.StartLineNumber, $t.Text)
            $errors++
            $fileBad = $true
        }
    }
    try {
        $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
        $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        if (-not $hasBom) {
            foreach ($b in $bytes) {
                if ($b -gt 127) {
                    Write-Warn "$rel : contains non-ASCII characters but has no UTF-8 BOM (Windows PowerShell 5.1 may misread it)"
                    $warnings++
                    break
                }
            }
        }
    } catch { }
}
Write-Host ''
Write-Info "$checked script(s) checked"
if ($errors -eq 0) { Write-Ok 'No syntax errors found' } else { Write-Fail "$errors problem(s) found" }
if ($warnings -gt 0) { Write-Warn "$warnings encoding warning(s)" }
Complete-Action -Action $A -Success ($errors -eq 0) -Detail "$checked scripts, $errors errors, $warnings warnings"
