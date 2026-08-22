param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

$failures = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

function Read-Utf8Text {
    param([string]$RelativePath)

    $path = Join-Path $RepoRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $failures.Add("missing file: $RelativePath")
        return ""
    }
    return [System.IO.File]::ReadAllText($path, [System.Text.UTF8Encoding]::new($false))
}

function Get-Utf8ByteCount {
    param([string]$Text)
    return [System.Text.UTF8Encoding]::new($false).GetByteCount($Text)
}

function Get-Utf8Sha256 {
    param([string]$Text)

    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($Text)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString($sha256.ComputeHash($bytes))).Replace("-", "")
    }
    finally {
        $sha256.Dispose()
    }
}

function Add-CountFailure {
    param(
        [string]$Label,
        [int]$Actual,
        [int]$Expected
    )
    if ($Actual -ne $Expected) {
        $failures.Add("${Label}: expected $Expected, got $Actual")
    }
}

$agentsText = Read-Utf8Text "AGENTS.md"
$claudeText = Read-Utf8Text "CLAUDE.md"
$trapsText = Read-Utf8Text "docs/godot_runtime_traps.md"
$trapManifestText = Read-Utf8Text "docs/godot_runtime_traps_manifest.tsv"
$trapRulesText = Read-Utf8Text ".claude/rules/godot-runtime-traps.md"
$projectText = Read-Utf8Text "godot/project.godot"
$workflowText = Read-Utf8Text ".github/workflows/godot-ci.yml"
$harnessWorkflowText = Read-Utf8Text ".github/workflows/agent-harness-ci.yml"
$secretWorkflowText = Read-Utf8Text ".github/workflows/project-secret-scan.yml"
$prePushText = Read-Utf8Text "godot/tools/run_pre_push_checks.ps1"
$smokeRunnerText = Read-Utf8Text "godot/tools/run_smoke_tests.ps1"
$smokeClassifierText = Read-Utf8Text "godot/tools/verify_smoke_runner_classifier.ps1"
$outputClassifierText = Read-Utf8Text "godot/tools/godot_output_classifier.ps1"
$headlessRunnerText = Read-Utf8Text "godot/tools/run_headless_load_check.ps1"
$warningScanText = Read-Utf8Text "godot/tools/run_warning_scan.ps1"
$warningScannerText = Read-Utf8Text "godot/tools/gd_warning_scan.gd"
$interactivePlayGuardText = Read-Utf8Text "godot/tools/assert_no_interactive_godot_game.ps1"
$interactivePlayGuardVerifierText = Read-Utf8Text "godot/tools/verify_interactive_play_validation_guard.ps1"
$stage7QaText = Read-Utf8Text "godot/tools/run_stage7_akamu_video_qa.ps1"
$victoryReplayQaText = Read-Utf8Text "godot/tools/run_victory_highlight_replay_clip_pixel_qa.ps1"
$plazaR3dVulkanQaText = Read-Utf8Text "godot/tools/run_plaza_r3d_production_vulkan_qa.ps1"
$victoryGpuQaPath = Join-Path $RepoRoot "godot/tools/run_victory_highlight_gpu_capture_probe_qa.ps1"
$victoryGpuQaText = if (Test-Path -LiteralPath $victoryGpuQaPath -PathType Leaf) {
    [System.IO.File]::ReadAllText($victoryGpuQaPath, [System.Text.UTF8Encoding]::new($false))
} else {
    ""
}
$secretScannerText = Read-Utf8Text "tools/verify_no_project_secrets.ps1"
$secretScannerVerifierText = Read-Utf8Text "tools/verify_project_secret_scanner.ps1"
$nightlySmokeText = Read-Utf8Text "godot/tools/run_nightly_smoke.ps1"
$nightlyStatusPolicyText = Read-Utf8Text "godot/tools/nightly_smoke_result_policy.ps1"
$nightlyStatusVerifierText = Read-Utf8Text "godot/tools/verify_nightly_smoke_status.ps1"
$spriteSkillText = Read-Utf8Text ".claude/skills/sprite-generation/SKILL.md"
$spriteReferencesText = Read-Utf8Text ".claude/skills/sprite-generation/references.md"
$activeSpritePromptTexts = @{}
foreach ($activeSpritePromptPath in @(
    ".claude/skills/sprite-generation/prompts/walk.md",
    ".claude/skills/sprite-generation/prompts/attack.md",
    ".claude/skills/sprite-generation/prompts/dash.md",
    ".claude/skills/sprite-generation/prompts/turn.md"
)) {
    $activeSpritePromptTexts[$activeSpritePromptPath] = Read-Utf8Text $activeSpritePromptPath
}
$itemSkillText = Read-Utf8Text ".claude/skills/item-generation/SKILL.md"
$characterChecklistText = Read-Utf8Text "docs/character_skill_perk_checklist.md"
$perfPlaybookText = Read-Utf8Text "docs/godot_perf_optimization_playbook.md"
$frameBudgetHandoffText = Read-Utf8Text "docs/frame_budget_optimization_session_handoff.md"
$harnessMaintenanceText = Read-Utf8Text "docs/agent_harness_maintenance.md"
$architectureText = Read-Utf8Text "docs/godot_port_architecture.md"
$ownershipLedgerText = Read-Utf8Text "docs/godot_module_ownership_ledger.md"
$warningFixtureText = Read-Utf8Text "godot/tests/fixtures/runner_warning_backtrace_fixture.gd"
$errorFixtureText = Read-Utf8Text "godot/tests/fixtures/runner_error_backtrace_fixture.gd"
$benignFixtureText = Read-Utf8Text "godot/tests/fixtures/runner_benign_diagnostic_text_fixture.gd"
$scriptErrorFixtureText = Read-Utf8Text "godot/tests/fixtures/runner_script_error_line_fixture.gd"
$fatalFixtureText = Read-Utf8Text "godot/tests/fixtures/runner_fatal_line_fixture.gd"
$certificateSubstringFixtureText = Read-Utf8Text "godot/tests/fixtures/runner_certificate_substring_error_fixture.gd"
$exactCertificateFixtureText = Read-Utf8Text "godot/tests/fixtures/runner_exact_certificate_error_fixture.gd"
$agentsArchiveText = Read-Utf8Text "docs/agent_harness_archive/AGENTS.full.md"
$claudeArchiveText = Read-Utf8Text "docs/agent_harness_archive/CLAUDE.full.md"
$currentBrand = [string]::Concat([char]0xD658, [char]0xACA9, [char]0xC804)
$legacyKoreanBrand = -join @(
    [char]0xB514, [char]0xC2A4, [char]0xD06C, [char]0xD558, [char]0xCE20,
    " - ",
    [char]0xB9C1, [char]0xD53C, [char]0xC544
)
$koreanCurrentPrefix = -join @(
    [char]0xD604, [char]0xC7AC, " ", [char]0xC2E4, [char]0xAC1C,
    [char]0xBC1C, " ", [char]0xB300, [char]0xC0C1
)
$koreanCurrentTargetLabel = -join @(
    [char]0xD604, [char]0xC7AC, " ", [char]0xB300, [char]0xC0C1
)

$agentsBytes = Get-Utf8ByteCount $agentsText
if ($agentsBytes -gt 32768) {
    $failures.Add("AGENTS.md exceeds Codex default project_doc_max_bytes: ${agentsBytes}B > 32768B")
}

$claudeBytes = Get-Utf8ByteCount $claudeText
if ($claudeBytes -gt 102400) {
    $failures.Add("CLAUDE.md exceeds repository soft ceiling: ${claudeBytes}B > 102400B")
}
$claudeLineCount = @($claudeText -split "\r?\n").Count
if ($claudeLineCount -gt 200) {
    $warnings.Add("CLAUDE.md remains above the 200-line target: $claudeLineCount lines")
}

$agentsRequiredHeadings = @(
    "Boss Sprite Workflow",
    "Runtime Performance Rules",
    "Atlas sheet grid authority",
    "Stage Integration Checklist",
    "Testing Guidelines",
    "Credential safety"
)
foreach ($heading in $agentsRequiredHeadings) {
    if ($agentsText -notmatch "(?m)^## $([regex]::Escape($heading))\r?$") {
        $failures.Add("AGENTS.md is missing a referenced compact heading: $heading")
    }
}

foreach ($interactivePlayInstructionSignal in @(
    "Interactive (windowed, non-editor) play does not block routine validation.",
    "-AllowDuringPlay",
    "BelowNormal priority",
    "PID/timestamp-unique"
)) {
    if (-not $agentsText.Contains($interactivePlayInstructionSignal)) {
        $failures.Add("AGENTS.md is missing interactive-play validation policy: $interactivePlayInstructionSignal")
    }
}
if ($interactivePlayGuardText.Contains("GODOT_ALLOW_VALIDATION_DURING_PLAY")) {
    $failures.Add("interactive-play guard still exposes the retired process-wide environment bypass")
}
foreach ($guardSignal in @(
    '[switch]$AllowDuringPlay',
    "function Restore-GodotValidationPriority",
    "OriginalPriorityClass",
    "Refusing to run validation"
)) {
    if (-not $interactivePlayGuardText.Contains($guardSignal)) {
        $failures.Add("interactive-play guard is missing fail-closed signal: $guardSignal")
    }
}
$interactivePlayRunners = @{
    "headless load" = $headlessRunnerText
    "warning scan" = $warningScanText
    "smoke tests" = $smokeRunnerText
    "victory replay Vulkan QA" = $victoryReplayQaText
    "plaza R3-D Vulkan QA" = $plazaR3dVulkanQaText
}
foreach ($runnerName in $interactivePlayRunners.Keys) {
    $runnerText = $interactivePlayRunners[$runnerName]
    foreach ($runnerSignal in @("-AllowDuringPlay", "finally", "Restore-GodotValidationPriority", "--log-file")) {
        if (-not $runnerText.Contains($runnerSignal)) {
            $failures.Add("$runnerName wrapper is missing interactive-play contract: $runnerSignal")
        }
    }
}
foreach ($guardVerifierSignal in @(
    "did not fail closed without -AllowDuringPlay",
    "did not report priority demotion",
    "failed to restore priority",
    "interactive-play validation guard verification: ok"
)) {
    if (-not $interactivePlayGuardVerifierText.Contains($guardVerifierSignal)) {
        $failures.Add("interactive-play guard verifier is missing a RED/GREEN signal: $guardVerifierSignal")
    }
}
if (-not $prePushText.Contains("verify_interactive_play_validation_guard.ps1")) {
    $failures.Add("pre-push does not execute the interactive-play validation guard regression")
}
if (-not $warningScanText.Contains('[string[]]$Paths = @()') -or
    -not $warningScanText.Contains('--include-path=') -or
    -not $warningScannerText.Contains('func _get_string_args(prefix: String) -> Array[String]:')) {
    $failures.Add("warning scan is missing touched-file -Paths support")
}

$claudeRequiredHeadings = @(
    "Direct Draw Request Routing",
    "Ringpet Visual Terminology",
    "Character Live2D Source Art Backgrounds",
    "Character Live2D Idle / Click Dialogue Continuity",
    "Runtime Skill-Effect Sprite Sheets"
)
foreach ($heading in $claudeRequiredHeadings) {
    if ($claudeText -notmatch "(?m)^## $([regex]::Escape($heading))\r?$") {
        $failures.Add("CLAUDE.md is missing a referenced compact heading: $heading")
    }
}

$agentsImports = [regex]::Matches($claudeText, '(?m)^@AGENTS\.md\r?$')
Add-CountFailure "CLAUDE.md AGENTS import count" $agentsImports.Count 1

$normalizedTrapRulesText = $trapRulesText -replace "`r`n", "`n"
$expectedTrapRuleFrontmatter = "---`npaths:`n  - `"godot/**`"`n---`n"
if (-not $normalizedTrapRulesText.StartsWith($expectedTrapRuleFrontmatter, [System.StringComparison]::Ordinal)) {
    $failures.Add('path-scoped trap rule must start with exact paths frontmatter for "godot/**"')
}

foreach ($trapContractSignal in @(
    "docs/godot_runtime_traps_manifest.tsv",
    ".claude/rules/godot-runtime-traps.md",
    "one-line discovery registry"
)) {
    if (-not $trapsText.Contains($trapContractSignal)) {
        $failures.Add("runtime-trap ledger is missing the current four-surface contract: $trapContractSignal")
    }
}
foreach ($retiredTrapContract in @(
    'CLAUDE.md keeps a 3-8 line stub',
    'stub in `CLAUDE.md`',
    ([string]::Concat('CLAUDE.md ', [char]0x00A7, '0'))
)) {
    if ($trapsText.Contains($retiredTrapContract)) {
        $failures.Add("runtime-trap ledger still declares a retired root-stub contract: $retiredTrapContract")
    }
}

$rootLineReferenceFiles = @(
    Get-ChildItem -LiteralPath (Join-Path $RepoRoot "docs") -Recurse -File -Filter "*.md" |
        Where-Object { $_.FullName -notlike "*\docs\agent_harness_archive\*" };
    Get-ChildItem -LiteralPath (Join-Path $RepoRoot ".claude/skills") -Recurse -File -Filter "*.md";
    Get-ChildItem -LiteralPath $RepoRoot -File -Filter "*.md" |
        Where-Object { $_.Name -notin @("AGENTS.md", "CLAUDE.md") }
)
$sectionSignPattern = [regex]::Escape([string][char]0x00A7)
$rootReferencePattern =
    '(?:(?:AGENTS|CLAUDE)\.md(?:#L|:)\d+(?:-\d+)?|(?:`?(?:AGENTS|CLAUDE)\.md`?)\s*' +
    $sectionSignPattern + '\s*\d+(?:\.\d+)*)'
foreach ($rootLineReferenceFile in $rootLineReferenceFiles) {
    $rootLineReferenceText = [System.IO.File]::ReadAllText(
        $rootLineReferenceFile.FullName,
        [System.Text.UTF8Encoding]::new($false)
    )
    $relativePath = $rootLineReferenceFile.FullName.Substring($RepoRoot.Length + 1)
    $normalizedRelativePath = $relativePath.Replace("\", "/")
    $expectedLegacyBrandMentions = if ($normalizedRelativePath -in @(
        "docs/documentation_diet_20260514.md",
        "docs/sprites/legacy_accepted_sheet_archive.md"
    )) { 1 } else { 0 }
    $actualLegacyBrandMentions = [regex]::Matches(
        $rootLineReferenceText,
        [regex]::Escape($legacyKoreanBrand)
    ).Count
    if ($actualLegacyBrandMentions -ne $expectedLegacyBrandMentions) {
        $failures.Add(
            "legacy Korean brand mention count changed: $relativePath expected $expectedLegacyBrandMentions, got $actualLegacyBrandMentions"
        )
    }
    foreach ($legacyCurrentDeclaration in @(
        "Current target: Godot **$legacyKoreanBrand**.",
        "Current implementation target: Godot **$legacyKoreanBrand**.",
        "Current development target: Godot **$legacyKoreanBrand**.",
        "${koreanCurrentTargetLabel}: Godot **$legacyKoreanBrand**."
    )) {
        if ($rootLineReferenceText.Contains($legacyCurrentDeclaration)) {
            $failures.Add("active doc still declares the legacy brand as current: $relativePath")
        }
    }
    foreach ($rootLineReference in [regex]::Matches(
        $rootLineReferenceText,
        $rootReferencePattern
    )) {
        $failures.Add("active doc uses a drift-prone root line reference: $relativePath -> $($rootLineReference.Value)")
    }
    if ($rootLineReferenceText -match '`?CLAUDE\.md`?\s+"Legacy Stage Order Reference') {
        $failures.Add("active doc points to the removed root stage-order section: $relativePath")
    }
    foreach ($removedRootRulePattern in @(
        'S15\.[^\r\n]{0,60}\(CLAUDE\.md',
        'CLAUDE\.md[^\r\n]{0,100}end-to-end',
        'CLAUDE\.md[^\r\n]{0,100}OUTCOME',
        'Gemini, AutoSprite[^\r\n]{0,100}CLAUDE\.md',
        'CLAUDE\.md[^\r\n]{0,100}boss-skill cleanup invariant',
        'CLAUDE\.md[^\r\n]{0,30}"HUD',
        'skill gold double-pay guard',
        'Radial CC hit geometry must name its primitive',
        'N-plication',
        'Settings screens can have multiple live entry points',
        'unicode tofu',
        'accepted-sheet notes elsewhere in this skill and in `CLAUDE.md`',
        'generation history still lives in `CLAUDE.md`'
    )) {
        if ($rootLineReferenceText -match $removedRootRulePattern) {
            $failures.Add("active doc points to a removed root rule: $relativePath -> $removedRootRulePattern")
        }
    }
}

if ($agentsArchiveText -notmatch '(?m)^# Exact Pre-Compaction AGENTS Snapshot\r?$') {
    $failures.Add("AGENTS archive is missing its exact-snapshot marker")
}
$agentsPayloadMarker = "# Repository Guidelines"
$agentsPayloadHeading = [regex]::Match($agentsArchiveText, '(?m)^# Repository Guidelines\r?$')
if (-not $agentsPayloadHeading.Success) {
    $failures.Add("AGENTS archive is missing its payload marker")
}
else {
    $agentsPayloadIndex = $agentsPayloadHeading.Index
    $agentsArchivePayload = $agentsArchiveText.Substring($agentsPayloadIndex)
    $expectedAgentsPayloadBytes = 116246
    $actualAgentsPayloadBytes = Get-Utf8ByteCount $agentsArchivePayload
    if ($actualAgentsPayloadBytes -ne $expectedAgentsPayloadBytes) {
        $failures.Add("AGENTS exact snapshot payload size changed: $actualAgentsPayloadBytes")
    }
    $expectedAgentsPayloadSha256 = "A2D60DD460FB30A2EDC9496C9BB3CD6C28DA8F5A294A13013B5A13BDFD1092D5"
    $actualAgentsPayloadSha256 = Get-Utf8Sha256 $agentsArchivePayload
    if ($actualAgentsPayloadSha256 -cne $expectedAgentsPayloadSha256) {
        $failures.Add("AGENTS exact snapshot payload hash changed: $actualAgentsPayloadSha256")
    }
}
if ($claudeArchiveText -notmatch '(?m)^# Exact Pre-Compaction CLAUDE Snapshot\r?$') {
    $failures.Add("CLAUDE archive is missing its exact-snapshot marker")
}
$claudePayloadMarker = "# CLAUDE.md"
$claudePayloadHeading = [regex]::Match($claudeArchiveText, '(?m)^# CLAUDE\.md\r?$')
if (-not $claudePayloadHeading.Success) {
    $failures.Add("CLAUDE archive is missing its payload marker")
}
else {
    $claudePayloadIndex = $claudePayloadHeading.Index
    $claudeArchivePayload = $claudeArchiveText.Substring($claudePayloadIndex)
    $expectedClaudePayloadBytes = 190711
    $actualClaudePayloadBytes = Get-Utf8ByteCount $claudeArchivePayload
    if ($actualClaudePayloadBytes -ne $expectedClaudePayloadBytes) {
        $failures.Add("CLAUDE exact snapshot payload size changed: $actualClaudePayloadBytes")
    }
    $expectedClaudePayloadSha256 = "DCB8DBAC686E791D11C92DDD0C2147E9A800428709D4C070432A38C00089BE53"
    $actualClaudePayloadSha256 = Get-Utf8Sha256 $claudeArchivePayload
    if ($actualClaudePayloadSha256 -cne $expectedClaudePayloadSha256) {
        $failures.Add("CLAUDE exact snapshot payload hash changed: $actualClaudePayloadSha256")
    }
    $archiveRootRelativeTrapLinks = [regex]::Matches(
        $claudeArchivePayload,
        '\]\(docs/godot_runtime_traps\.md#grt-\d{3}\)'
    )
    Add-CountFailure "CLAUDE exact snapshot root-relative trap-link count" $archiveRootRelativeTrapLinks.Count 59
}

$manifestEntries = [regex]::Matches(
    $trapManifestText,
    '(?m)^(?<id>grt-\d{3})\t(?<title>.+)\r?$'
)
$manifestNonBlankLines = @($trapManifestText -split '\r?\n' | Where-Object { $_.Trim().Length -gt 0 })
$expectedManifestHeaderLines = @(
    "# Immutable GRT identity manifest. Existing ID/title rows are append-only.",
    "# Format: id<TAB>exact heading shared by CLAUDE registry, rule, and ledger."
)
if ($manifestNonBlankLines.Count -lt 2 -or
    $manifestNonBlankLines[0] -cne $expectedManifestHeaderLines[0] -or
    $manifestNonBlankLines[1] -cne $expectedManifestHeaderLines[1]) {
    $failures.Add("immutable GRT identity manifest header changed")
}
$manifestDataLines = @($manifestNonBlankLines | Select-Object -Skip 2)
foreach ($manifestDataLine in $manifestDataLines) {
    if ($manifestDataLine -notmatch '^grt-\d{3}\t.+$') {
        $failures.Add("immutable GRT identity manifest contains an unparsed nonblank row")
    }
}
if ($manifestDataLines.Count -ne $manifestEntries.Count) {
    $failures.Add("immutable GRT identity manifest contains rows outside the canonical parser")
}
$expectedTrapCount = $manifestEntries.Count
if ($expectedTrapCount -lt 1) {
    $failures.Add("immutable GRT identity manifest has no entries")
}
$manifestIds = [System.Collections.Generic.List[string]]::new()
$manifestTitlesById = @{}
foreach ($entry in $manifestEntries) {
    $id = $entry.Groups["id"].Value
    $manifestIds.Add($id)
    if (-not $manifestTitlesById.ContainsKey($id)) {
        $manifestTitlesById[$id] = $entry.Groups["title"].Value.Trim()
    }
}
$canonicalManifestIdentity = (($manifestEntries | ForEach-Object {
    $_.Groups["id"].Value + "`t" + $_.Groups["title"].Value.Trim()
}) -join "`n") + "`n"
$expectedTrapManifestSha256 = "B1EAB1F5A356CC5BC466BB68F620B0ADAE1DD57AE7E2CF417760007390671023"
$actualTrapManifestSha256 = Get-Utf8Sha256 $canonicalManifestIdentity
if ($actualTrapManifestSha256 -cne $expectedTrapManifestSha256) {
    $failures.Add("immutable GRT identity manifest hash changed: $actualTrapManifestSha256")
}

foreach ($activeDoc in @(
    "README.md",
    "MANUS_PROMPT_PREFIX.md",
    "AGENTS.md",
    "CLAUDE.md",
    "docs/current_development_boundary.md",
    "docs/agent_harness_maintenance.md",
    "docs/documentation_diet_20260514.md",
    "docs/godot_perf_optimization_playbook.md",
    "docs/godot_port_architecture.md",
    "docs/godot_module_ownership_ledger.md",
    "docs/godot_port_checklist.md",
    "docs/item_runtime_checklist.md",
    "docs/character_skill_perk_checklist.md",
    "docs/sprites/boss_sprite_runtime_contract.md",
    "docs/sprites/stage1_dalji.md",
    ".claude/skills/item-generation/SKILL.md",
    ".claude/skills/sprite-generation/SKILL.md",
    ".claude/skills/ui-hud-generation/SKILL.md",
    ".claude/skills/README.md",
    "docs/sprites/stage1_gaksital.md",
    "docs/sprites/legacy_accepted_sheet_archive.md",
    ".github/copilot-instructions.md"
)) {
    $text = Read-Utf8Text $activeDoc
    if ($text -notmatch [regex]::Escape($currentBrand)) {
        $failures.Add("active doc does not declare the current Hwangyeokjeon brand: $activeDoc")
    }

    $staleCurrentDeclarations = @(
        "implementation target for $legacyKoreanBrand",
        "For current $legacyKoreanBrand work",
        "Current development target: Godot **$legacyKoreanBrand**",
        "Current implementation target: Godot **$legacyKoreanBrand**",
        "officially titled $legacyKoreanBrand",
        "current Godot project, DiskHearts - Lingpia",
        "in DiskHearts - Lingpia"
    )
    foreach ($staleDeclaration in $staleCurrentDeclarations) {
        if ($text.Contains($staleDeclaration)) {
            $failures.Add("active doc still declares a stale current brand: $activeDoc")
            break
        }
    }

    $koreanStaleDeclaration = "**$legacyKoreanBrand**"
    if ($text.Contains($koreanStaleDeclaration) -and $text -match [regex]::Escape($koreanCurrentPrefix)) {
        $failures.Add("active doc still declares a stale Korean current brand: $activeDoc")
    }
}

foreach ($perfOwnerMarker in @(
    "## Event-Boundary Owner Sync",
    "bounded threaded prewarm",
    "batching yield",
    "GRT-032",
    "GRT-005"
)) {
    if (-not $perfPlaybookText.Contains($perfOwnerMarker)) {
        $failures.Add("performance playbook is missing a compacted standing rule: $perfOwnerMarker")
    }
}
foreach ($maintenanceMarker in @(
    "## Routing contract",
    "## Backfill and graduation",
    "## Compaction and archive recovery",
    "omitted untracked dependency",
    "aborts on the first genuine failing test"
)) {
    if (-not $harnessMaintenanceText.Contains($maintenanceMarker)) {
        $failures.Add("harness maintenance doc is missing a standing section: $maintenanceMarker")
    }
}
if (-not $architectureText.Contains("line-start severity markers") -or
    $architectureText.Contains("Parse Error | Compile Error | Failed to load script | Invalid call")) {
    $failures.Add("architecture guide still documents the retired smoke-error classifier")
}
if (-not $architectureText.Contains("godot/tools/godot_output_classifier.ps1") -or
    -not $architectureText.Contains("Leak-sensitive QA remains a separate")) {
    $failures.Add("architecture guide does not document the shared error/leak classifier boundary")
}
if ($architectureText -notmatch 'sole\s+ignored severity line' -or
    -not $architectureText.Contains("ERROR: Failed to read the root certificate store.")) {
    $failures.Add("architecture guide does not document the exact certificate-error exception")
}
if (-not $agentsText.Contains("docs/agent_harness_maintenance.md")) {
    $failures.Add("AGENTS.md does not route harness changes to the maintenance contract")
}
foreach ($rootDetailOwner in @(
    @{ Name = "architecture"; Text = $architectureText },
    @{ Name = "ownership ledger"; Text = $ownershipLedgerText }
)) {
    if ($rootDetailOwner.Text -notmatch 'Root files keep only concise\s+routing') {
        $failures.Add("$($rootDetailOwner.Name) does not preserve the compact-root ownership boundary")
    }
}
if (-not $agentsText.Contains("Exact pre-compaction payloads are preserved")) {
    $failures.Add("AGENTS.md does not declare the exact inactive archive contract")
}
if (-not $claudeText.Contains("exact, hash-pinned") -or
    -not $claudeText.Contains("pre-compaction payload")) {
    $failures.Add("CLAUDE.md does not declare the exact inactive archive contract")
}

$hudSkillText = Read-Utf8Text ".claude/skills/ui-hud-generation/SKILL.md"
foreach ($retiredHudDefault in @(
    "designed for PingFighter first",
    "PingFighter sci-fi arcade HUD frame",
    "takes place inside a full-immersion virtual reality",
    "shared cyberpunk / parallel-universe signal"
)) {
    if ($hudSkillText.Contains($retiredHudDefault)) {
        $failures.Add("HUD skill still declares a retired current visual default: $retiredHudDefault")
    }
}
foreach ($currentHudSignal in @("Korean-fantasy", "hanji", "aged brass", "jade", "cinnabar")) {
    if (-not $hudSkillText.Contains($currentHudSignal)) {
        $failures.Add("HUD skill is missing a current Hwangyeokjeon visual signal: $currentHudSignal")
    }
}

$spriteSkillRoot = Join-Path $RepoRoot ".claude/skills/sprite-generation"
$spriteSkillCorpus = @(
    Get-ChildItem -LiteralPath $spriteSkillRoot -Recurse -File -Filter "*.md" |
        ForEach-Object {
            [System.IO.File]::ReadAllText($_.FullName, [System.Text.UTF8Encoding]::new($false))
        }
) -join "`n"
foreach ($retiredStageMapping in @(
    'code `current_stage == 5` is real Stage 6',
    'code `current_stage == 5` is Stage 6',
    'code `current_stage == 6` is real Stage 5',
    'code `current_stage == 6` is Stage 5',
    '| `5` | 6 | Honglyeon',
    '| `6` | 5 | Nemesis',
    '"Stage Order Reference"',
    'Full mapping lives in `CLAUDE.md`'
)) {
    if ($spriteSkillCorpus.Contains($retiredStageMapping)) {
        $failures.Add("sprite skill subtree still contains a retired stage mapping: $retiredStageMapping")
    }
}
if ($spriteSkillCorpus -match '(?m)^\| Gemini MCP .*\| Sheet generation \|\r?$') {
    $failures.Add("sprite skill subtree still routes final sheet generation to Gemini")
}
foreach ($currentStageMarker in @(
    'Godot `current_stage == 5` is current Stage 5',
    'Godot `current_stage == 6` is current Stage 6 Tetriser',
    'Original Python Stage 6 Nemesis is excluded'
)) {
    if (-not $spriteSkillText.Contains($currentStageMarker) -and
        -not $spriteReferencesText.Contains($currentStageMarker)) {
        $failures.Add("sprite skill is missing a current stage guard: $currentStageMarker")
    }
}

foreach ($danglingCharacterUiReference in @(
    'CLAUDE.md §"5-orb active-skill tooltip standard format"',
    '`CLAUDE.md` "Perk Icon Rendering"',
    'Run the full `CLAUDE.md` text audit',
    '`docs/character_skill_perk_checklist.md` + `CLAUDE.md`'
)) {
    if ($characterChecklistText.Contains($danglingCharacterUiReference) -or
        $itemSkillText.Contains($danglingCharacterUiReference)) {
        $failures.Add("character UI contract still points to a removed CLAUDE section: $danglingCharacterUiReference")
    }
}
foreach ($ownedCharacterUiSection in @(
    "### 4.1. Generic perk icon rendering",
    "### 4.3. Orb tooltip rendering",
    "### 4.4. Perk / skill UI text audit",
    "### 5.1. Cooldown-display rule"
)) {
    if (-not $characterChecklistText.Contains($ownedCharacterUiSection)) {
        $failures.Add("character checklist is missing an absorbed UI contract: $ownedCharacterUiSection")
    }
}

if ($projectText -notmatch '(?m)^config/name="pingfighter"\r?$') {
    $failures.Add('compatibility guard changed: project.godot config/name must remain "pingfighter"')
}
if ($projectText -match '(?m)^config/use_custom_user_dir\s*=\s*true\r?$') {
    $failures.Add("compatibility guard changed: use_custom_user_dir=true requires a save migration")
}

$registryEntries = [regex]::Matches(
    $claudeText,
    '(?m)^- \[GRT-(?<number>\d{3})\]\(docs/godot_runtime_traps\.md#(?<id>grt-\d{3})\) \u2014 (?<title>.+)\r?$'
)
Add-CountFailure "CLAUDE.md trap registry count" $registryEntries.Count $expectedTrapCount

$registryIds = [System.Collections.Generic.List[string]]::new()
$registryTitlesById = @{}
foreach ($entry in $registryEntries) {
    $number = $entry.Groups["number"].Value
    $id = $entry.Groups["id"].Value
    if ($id -ne "grt-$number") {
        $failures.Add("trap registry label/anchor mismatch: GRT-$number -> $id")
    }
    $registryIds.Add($id)
    if (-not $registryTitlesById.ContainsKey($id)) {
        $registryTitlesById[$id] = $entry.Groups["title"].Value.Trim()
    }
}

$ruleSections = [regex]::Matches(
    $trapRulesText,
    '(?ms)^## GRT-(?<number>\d{3}) \u2014 (?<title>.+?)\r?\n(?<body>.*?)(?=^## GRT-|\z)'
)
Add-CountFailure "path-scoped trap essence count" $ruleSections.Count $expectedTrapCount

$ruleIds = [System.Collections.Generic.List[string]]::new()
$ruleTitlesById = @{}
foreach ($section in $ruleSections) {
    $number = $section.Groups["number"].Value
    $id = "grt-$number"
    $title = $section.Groups["title"].Value.Trim()
    $body = $section.Groups["body"].Value
    $ledgerLinks = [regex]::Matches(
        $body,
        '\[Full ledger\]\(\.\./\.\./docs/godot_runtime_traps\.md#(?<id>grt-\d{3})\)'
    )
    if ($ledgerLinks.Count -ne 1 -or $ledgerLinks[0].Groups["id"].Value -ne $id) {
        $failures.Add("path-scoped essence must contain one matching ledger link: GRT-$number")
    }
    $ruleIds.Add($id)
    if (-not $ruleTitlesById.ContainsKey($id)) {
        $ruleTitlesById[$id] = $title
    }

    $essenceLines = @(
        $body -split "\r?\n" |
            Where-Object {
                $trimmed = $_.Trim()
                $trimmed -ne "" -and $trimmed -notmatch '^\[Full ledger\]\('
            }
    ).Count
    if ($essenceLines -lt 3 -or $essenceLines -gt 8) {
        $failures.Add("path-scoped trap essence must be 3-8 non-empty lines (got $essenceLines): GRT-$number")
    }
}

$ledgerAnchors = [regex]::Matches(
    $trapsText,
    '(?m)^<a id="(?<id>grt-\d{3})"></a>\r?\n## (?<title>.+)$'
)
Add-CountFailure "runtime trap ledger anchor count" $ledgerAnchors.Count $expectedTrapCount

$rawLedgerAnchors = [regex]::Matches(
    $trapsText,
    '(?m)^<a id="(?<id>grt-\d{3})"></a>\r?$'
)
Add-CountFailure "runtime trap raw anchor count" $rawLedgerAnchors.Count $expectedTrapCount
$rawLedgerAnchorIds = [System.Collections.Generic.List[string]]::new()
foreach ($anchor in $rawLedgerAnchors) {
    $rawLedgerAnchorIds.Add($anchor.Groups["id"].Value)
}

$ledgerIds = [System.Collections.Generic.List[string]]::new()
$ledgerTitlesById = @{}
foreach ($anchor in $ledgerAnchors) {
    $id = $anchor.Groups["id"].Value
    $ledgerIds.Add($id)
    if (-not $ledgerTitlesById.ContainsKey($id)) {
        $ledgerTitlesById[$id] = $anchor.Groups["title"].Value.Trim()
    }
}

foreach ($surface in @(
    @{ Name = "manifest"; Ids = $manifestIds },
    @{ Name = "registry"; Ids = $registryIds },
    @{ Name = "rule"; Ids = $ruleIds },
    @{ Name = "ledger"; Ids = $ledgerIds },
    @{ Name = "raw ledger anchor"; Ids = $rawLedgerAnchorIds }
)) {
    foreach ($duplicate in @($surface.Ids | Group-Object | Where-Object Count -ne 1)) {
        $failures.Add("$($surface.Name) GRT id is not unique: $($duplicate.Name) x$($duplicate.Count)")
    }
}

$expectedIds = if ($expectedTrapCount -gt 0) {
    @(1..$expectedTrapCount | ForEach-Object { "grt-{0:D3}" -f $_ })
}
else {
    @()
}
foreach ($id in $expectedIds) {
    if ($id -notin $manifestIds) {
        $failures.Add("append-only GRT manifest is missing immutable id: $id")
    }
    if ($id -notin $registryIds) {
        $failures.Add("append-only GRT manifest is missing registry id: $id")
    }
    if ($id -notin $ruleIds) {
        $failures.Add("append-only GRT manifest is missing rule id: $id")
    }
    if ($id -notin $ledgerIds) {
        $failures.Add("append-only GRT manifest is missing ledger id: $id")
    }
    if ($registryTitlesById.ContainsKey($id) -and $ruleTitlesById.ContainsKey($id) -and
        $registryTitlesById[$id] -cne $ruleTitlesById[$id]) {
        $failures.Add("GRT registry/rule heading mismatch for $id")
    }
    if ($ruleTitlesById.ContainsKey($id) -and $ledgerTitlesById.ContainsKey($id) -and
        $ruleTitlesById[$id] -cne $ledgerTitlesById[$id]) {
        $failures.Add("GRT rule/ledger heading mismatch for $id")
    }
    if ($manifestTitlesById.ContainsKey($id)) {
        foreach ($surfaceTitle in @(
            @{ Name = "registry"; Titles = $registryTitlesById },
            @{ Name = "rule"; Titles = $ruleTitlesById },
            @{ Name = "ledger"; Titles = $ledgerTitlesById }
        )) {
            if ($surfaceTitle.Titles.ContainsKey($id) -and
                $surfaceTitle.Titles[$id] -cne $manifestTitlesById[$id]) {
                $failures.Add("GRT $($surfaceTitle.Name) retargeted immutable identity: $id")
            }
        }
    }
}

foreach ($id in @($manifestIds + $registryIds + $ruleIds + $ledgerIds + $rawLedgerAnchorIds | Sort-Object -Unique)) {
    if ($id -notin $expectedIds) {
        $failures.Add("unexpected GRT id outside append-only manifest: $id")
    }
}

if ($workflowText -match '(?ms)^  push:\r?\n    branches:') {
    $failures.Add("godot-ci push trigger is branch-filtered and can skip the active development branch")
}
$workflowClassifierPattern = '(?m)^[ \t]*\.\\tools\\verify_smoke_runner_classifier\.ps1[ \t]+-GodotExe[ \t]+"\$\{\{[ \t]*steps\.godot\.outputs\.godot_console[ \t]*\}\}"[ \t]*\r?$'
$workflowClassifierMatches = [regex]::Matches($workflowText, $workflowClassifierPattern)
if ($workflowClassifierMatches.Count -ne 1) {
    $failures.Add("godot-ci workflow does not execute the smoke classifier regression")
}
$workflowFocusedBlock = [regex]::Match(
    $workflowText,
    '(?ms)^  FOCUSED_SMOKE_TESTS: >-\r?\n(?<body>(?:    res://tests/[^\r\n]+\r?\n)+)'
)
$prePushFocusedBlock = [regex]::Match(
    $prePushText,
    '(?ms)^\$focusedSmoke = @\(\r?\n(?<body>.*?)^\)\r?$'
)
if (-not $workflowFocusedBlock.Success) {
    $failures.Add("godot-ci focused smoke block could not be parsed")
}
if (-not $prePushFocusedBlock.Success) {
    $failures.Add("pre-push focused smoke block could not be parsed")
}
if ($workflowFocusedBlock.Success -and $prePushFocusedBlock.Success) {
    $workflowFocusedTests = @(
        [regex]::Matches(
            $workflowFocusedBlock.Groups["body"].Value,
            '(?m)^    (?<path>res://tests/[^\r\n]+_smoke\.gd)\r?$'
        ) | ForEach-Object { $_.Groups["path"].Value }
    )
    $prePushFocusedTests = @(
        [regex]::Matches(
            $prePushFocusedBlock.Groups["body"].Value,
            '(?m)^\s*"(?<path>res://tests/[^"\r\n]+_smoke\.gd",?)"?\s*$'
        ) | ForEach-Object {
            $_.Groups["path"].Value.TrimEnd(',').TrimEnd('"')
        }
    )
    if ($workflowFocusedTests.Count -ne $prePushFocusedTests.Count) {
        $failures.Add(
            "focused smoke lockstep count mismatch: CI=$($workflowFocusedTests.Count), pre-push=$($prePushFocusedTests.Count)"
        )
    }
    $focusedCompareCount = [Math]::Min($workflowFocusedTests.Count, $prePushFocusedTests.Count)
    for ($focusedIndex = 0; $focusedIndex -lt $focusedCompareCount; $focusedIndex++) {
        if ($workflowFocusedTests[$focusedIndex] -cne $prePushFocusedTests[$focusedIndex]) {
            $failures.Add(
                "focused smoke lockstep order mismatch at $focusedIndex`: CI=$($workflowFocusedTests[$focusedIndex]), pre-push=$($prePushFocusedTests[$focusedIndex])"
            )
            break
        }
    }
    foreach ($focusedSurface in @(
        @{ Name = "CI"; Tests = $workflowFocusedTests },
        @{ Name = "pre-push"; Tests = $prePushFocusedTests }
    )) {
        foreach ($duplicate in @($focusedSurface.Tests | Group-Object | Where-Object Count -ne 1)) {
            $failures.Add("$($focusedSurface.Name) focused smoke is duplicated: $($duplicate.Name)")
        }
    }
}
$workflowNightlyPattern = '(?m)^[ \t]*\.\\tools\\verify_nightly_smoke_status\.ps1[ \t]*\r?$'
$workflowSmokePattern = '(?m)^[ \t]*\.\\tools\\run_smoke_tests\.ps1[ \t]+-GodotExe[^\r\n]*\r?$'
$workflowNightlyMatches = [regex]::Matches($workflowText, $workflowNightlyPattern)
$workflowSmokeMatches = [regex]::Matches($workflowText, $workflowSmokePattern)
if ($workflowNightlyMatches.Count -ne 1) {
    $failures.Add("godot-ci workflow does not execute the nightly status regression")
}
if ($workflowSmokeMatches.Count -lt 1) {
    $failures.Add("godot-ci workflow does not execute product smokes")
}
elseif ($workflowClassifierMatches.Count -eq 1 -and $workflowNightlyMatches.Count -eq 1 -and
    ($workflowClassifierMatches[0].Index -gt $workflowNightlyMatches[0].Index -or
        $workflowNightlyMatches[0].Index -gt $workflowSmokeMatches[0].Index)) {
    $failures.Add("godot-ci must execute classifier and nightly regressions before product smokes")
}

$prePushClassifierPattern = '(?m)^[ \t]*&[ \t]+\(Join-Path[ \t]+\$tools[ \t]+"verify_smoke_runner_classifier\.ps1"\)[ \t]+-GodotExe[ \t]+\$godot[ \t]*\r?$'
$prePushNightlyPattern = '(?m)^[ \t]*&[ \t]+\(Join-Path[ \t]+\$tools[ \t]+"verify_nightly_smoke_status\.ps1"\)[ \t]*\r?$'
$prePushSmokePattern = '(?m)^[ \t]*&[ \t]+\(Join-Path[ \t]+\$tools[ \t]+"run_smoke_tests\.ps1"\)[ \t]+-GodotExe[ \t]+\$godot(?:[ \t]+-Tests[ \t]+\$focusedSmoke)?[ \t]*\r?$'
$prePushClassifierMatches = [regex]::Matches($prePushText, $prePushClassifierPattern)
$prePushNightlyMatches = [regex]::Matches($prePushText, $prePushNightlyPattern)
$prePushSmokeMatches = [regex]::Matches($prePushText, $prePushSmokePattern)
if ($prePushClassifierMatches.Count -ne 1) {
    $failures.Add("pre-push does not execute the smoke classifier regression")
}
if ($prePushNightlyMatches.Count -ne 1) {
    $failures.Add("pre-push does not execute the nightly status regression")
}
if ($prePushSmokeMatches.Count -lt 1) {
    $failures.Add("pre-push does not execute product smokes")
}
elseif ($prePushClassifierMatches.Count -eq 1 -and $prePushNightlyMatches.Count -eq 1 -and
    ($prePushClassifierMatches[0].Index -gt $prePushNightlyMatches[0].Index -or
        $prePushNightlyMatches[0].Index -gt $prePushSmokeMatches[0].Index)) {
    $failures.Add("pre-push must execute classifier and nightly regressions before product smokes")
}
if (-not $nightlySmokeText.Contains('. (Join-Path $tools "nightly_smoke_result_policy.ps1")') -or
    -not $nightlySmokeText.Contains('Get-NightlyCombinedExitCode')) {
    $failures.Add("nightly runner does not use the shared aggregate-status policy")
}
if (-not $nightlyStatusPolicyText.Contains('function Get-NightlyCombinedExitCode')) {
    $failures.Add("nightly aggregate-status policy is missing its public function")
}
if (-not $nightlyStatusVerifierText.Contains('Get-NightlyCombinedExitCode') -or
    -not $nightlyStatusVerifierText.Contains('nightly smoke status policy: ok')) {
    $failures.Add("nightly aggregate-status regression is missing its policy route or terminal marker")
}
foreach ($classifierFunction in @(
    "function Test-GodotBenignCertificateErrorLine",
    "function Test-GodotSeriousErrorLine",
    "function Test-GodotLeakDiagnosticLine"
)) {
    $classifierFunctionPattern = '(?m)^' + [regex]::Escape($classifierFunction) + '\s*\{\s*$'
    if ($outputClassifierText -notmatch $classifierFunctionPattern) {
        $failures.Add("shared Godot output classifier is missing: $classifierFunction")
    }
}
if (-not $outputClassifierText.Contains("^\s*ERROR: Failed to read the root certificate store\.\s*$")) {
    $failures.Add("shared Godot output classifier certificate exception is not exact-line anchored")
}
if (-not $outputClassifierText.Contains("^\s*(SCRIPT ERROR|ERROR:|FATAL:)")) {
    $failures.Add("shared Godot output classifier severity predicate is not line-start anchored")
}
$sharedClassifierImportPattern = '(?m)^\s*\.\s+\(Join-Path\s+\$PSScriptRoot\s+"godot_output_classifier\.ps1"\)\s*$'
$sharedSeriousCallPattern = '(?m)^\s*\(?Test-GodotSeriousErrorLine\s+-Line\s+\$line\)?'
$sharedLeakCallPattern = '(?m)^\s*\(?Test-GodotLeakDiagnosticLine\s+-Line\s+\$line\)?'
foreach ($classifierConsumer in @(
    @{ Name = "smoke runner"; Text = $smokeRunnerText; NeedsLeak = $false },
    @{ Name = "headless runner"; Text = $headlessRunnerText; NeedsLeak = $false },
    @{ Name = "warning scan"; Text = $warningScanText; NeedsLeak = $false },
    @{ Name = "Stage 7 QA"; Text = $stage7QaText; NeedsLeak = $true },
    @{ Name = "victory replay QA"; Text = $victoryReplayQaText; NeedsLeak = $false }
)) {
    if ($classifierConsumer.Text -notmatch $sharedClassifierImportPattern -or
        $classifierConsumer.Text -notmatch $sharedSeriousCallPattern) {
        $failures.Add("$($classifierConsumer.Name) does not use the shared Godot output classifier")
    }
    if ($classifierConsumer.NeedsLeak -and
        $classifierConsumer.Text -notmatch $sharedLeakCallPattern) {
        $failures.Add("$($classifierConsumer.Name) does not preserve the leak diagnostic gate")
    }
}
if (-not [string]::IsNullOrEmpty($victoryGpuQaText)) {
    if ($victoryGpuQaText -notmatch $sharedClassifierImportPattern -or
        $victoryGpuQaText -notmatch $sharedSeriousCallPattern -or
        $victoryGpuQaText -notmatch $sharedLeakCallPattern) {
        $failures.Add("victory GPU QA does not use the shared error and leak classifiers")
    }
}
if (-not $smokeRunnerText.Contains("Smoke summary: PASS={0} FAIL={1} TOTAL={2}") -or
    -not $smokeRunnerText.Contains("Godot smoke suite failed: {0} of {1} tests failed")) {
    $failures.Add("smoke runner is missing continue-and-aggregate terminal reporting")
}
if ($smokeClassifierText -notmatch '(?m)^Assert-SmokeRunnerContinuesAfterFailure\s*$') {
    $failures.Add("smoke classifier verifier is missing the active continue-after-failure regression")
}
foreach ($secretRuleId in @("context7", "autosprite", "google_ai", "literal_bearer", "signed_url")) {
    if ($secretScannerText -notmatch ('(?m)^\s*' + [regex]::Escape($secretRuleId) + '\s*=')) {
        $failures.Add("project secret scanner is missing rule: $secretRuleId")
    }
}
if ($secretScannerText -notmatch '(?m)^\s*\$startInfo\.Arguments\s*=\s*''-c core\.quotepath=false ls-files --cached -z''\s*$' -or
    $secretScannerText -notmatch '(?m)^\s*\$startInfo\.StandardOutputEncoding\s*=\s*\[System\.Text\.UTF8Encoding\]::new\(\$false\)\s*$') {
    $failures.Add("project secret scanner does not use NUL-delimited UTF-8 tracked-path enumeration")
}
if ($secretScannerVerifierText -notmatch '(?m)^\s*\[Console\]::OutputEncoding\s*=\s*\[System\.Text\.Encoding\]::GetEncoding\(437\)\s*$' -or
    $secretScannerVerifierText -notmatch '(?m)^\s*-EnumerationProbePath\s+\$utf8TrackedPathProbe\s*$') {
    $failures.Add("project secret scanner regression does not exercise UTF-8 paths under a non-UTF-8 console")
}
if ($secretScannerVerifierText -notmatch '(?m)^Write-Host "project secret scanner regression: ok"\s*$') {
    $failures.Add("project secret scanner regression is missing its terminal marker")
}
$prePushSecretVerifierPattern = '(?m)^\s*&\s+\(Join-Path\s+\$repoRoot\s+"tools\\verify_project_secret_scanner\.ps1"\)\s*$'
$prePushSecretScanPattern = '(?m)^\s*&\s+\(Join-Path\s+\$repoRoot\s+"tools\\verify_no_project_secrets\.ps1"\)\s+-RepoRoot\s+\$repoRoot\s*$'
if ($prePushText -notmatch $prePushSecretVerifierPattern -or
    $prePushText -notmatch $prePushSecretScanPattern) {
    $failures.Add("pre-push does not execute the project secret regression and local scan")
}
if ($secretWorkflowText -match '(?m)^\s+paths:\s*$') {
    $failures.Add("project secret workflow is path-filtered and can miss credentials")
}
foreach ($secretWorkflowCall in @(
    'run: .\tools\verify_project_secret_scanner.ps1',
    'run: .\tools\verify_no_project_secrets.ps1 -TrackedOnly'
)) {
    $secretWorkflowCallPattern = '(?m)^\s*' + [regex]::Escape($secretWorkflowCall) + '\s*$'
    if ($secretWorkflowText -notmatch $secretWorkflowCallPattern) {
        $failures.Add("project secret workflow is missing active call: $secretWorkflowCall")
    }
}
if ($spriteSkillText.Contains('turn sheet, or item icon')) {
    $failures.Add("sprite skill still claims the item-icon trigger owned by item-generation")
}
if (-not $spriteSkillText.Contains('`prompts/menhera_*.md` are inactive historical experiment records')) {
    $failures.Add("sprite skill does not quarantine the legacy Menhera experiment prompts")
}
foreach ($activeSpritePromptPath in $activeSpritePromptTexts.Keys) {
    if ($activeSpritePromptTexts[$activeSpritePromptPath] -match '(?i)(gemini-generate-image|FLUX Kontext|Gemini MCP)') {
        $failures.Add("active sprite prompt contains a retired generator route: $activeSpritePromptPath")
    }
}
foreach ($classifierFixture in @(
    "res://tests/fixtures/runner_warning_backtrace_fixture.gd",
    "res://tests/fixtures/runner_error_backtrace_fixture.gd",
    "res://tests/fixtures/runner_benign_diagnostic_text_fixture.gd",
    "res://tests/fixtures/runner_script_error_line_fixture.gd",
    "res://tests/fixtures/runner_fatal_line_fixture.gd",
    "res://tests/fixtures/runner_certificate_substring_error_fixture.gd",
    "res://tests/fixtures/runner_exact_certificate_error_fixture.gd"
)) {
    if (-not $smokeClassifierText.Contains($classifierFixture)) {
        $failures.Add("smoke classifier verifier is missing fixture route: $classifierFixture")
    }
}
foreach ($requiredClassifierAcceptanceCall in @(
    '& $runnerPath -GodotExe $godotPath -ProjectPath $ProjectPath -Tests @($warningFixture)',
    '& $runnerPath -GodotExe $godotPath -ProjectPath $ProjectPath -Tests @($benignTextFixture)',
    '& $runnerPath -GodotExe $godotPath -ProjectPath $ProjectPath -Tests @($exactCertificateFixture)'
)) {
    $activeAcceptancePattern = '(?m)^\s*' + [regex]::Escape($requiredClassifierAcceptanceCall) + '\s*$'
    if ($smokeClassifierText -notmatch $activeAcceptancePattern) {
        $failures.Add("smoke classifier verifier is missing an acceptance call: $requiredClassifierAcceptanceCall")
    }
}
foreach ($requiredClassifierCall in @(
    'Assert-RejectedBySmokeRunner -Fixture $errorFixture -Label "error-backtrace"',
    'Assert-RejectedBySmokeRunner -Fixture $scriptErrorFixture -Label "SCRIPT ERROR"',
    'Assert-RejectedBySmokeRunner -Fixture $fatalFixture -Label "FATAL"',
    'Assert-RejectedBySmokeRunner -Fixture $certificateSubstringFixture -Label "certificate-substring ERROR"'
)) {
    $activeCallPattern = '(?m)^\s*' + [regex]::Escape($requiredClassifierCall) + '\s*$'
    if ($smokeClassifierText -notmatch $activeCallPattern) {
        $failures.Add("smoke classifier verifier is missing a rejection call: $requiredClassifierCall")
    }
}
foreach ($fixtureContract in @(
    @{ Name = "warning"; Text = $warningFixtureText; Pattern = '(?m)^\s*push_warning\(' },
    @{ Name = "error"; Text = $errorFixtureText; Pattern = '(?m)^\s*push_error\(' },
    @{ Name = "benign diagnostic"; Text = $benignFixtureText; Pattern = '(?m)^\s*print\("Documentation tokens: Parse Error' },
    @{ Name = "SCRIPT ERROR"; Text = $scriptErrorFixtureText; Pattern = '(?m)^\s*assert\(false,' },
    @{ Name = "FATAL"; Text = $fatalFixtureText; Pattern = '(?m)^\s*printerr\("FATAL:' },
    @{ Name = "certificate substring"; Text = $certificateSubstringFixtureText; Pattern = '(?m)^\s*printerr\("ERROR: runner real failure includes Failed to read the root certificate store' },
    @{ Name = "exact certificate"; Text = $exactCertificateFixtureText; Pattern = '(?m)^\s*printerr\("ERROR: Failed to read the root certificate store\."\)\s*$' }
)) {
    if ($fixtureContract.Text -notmatch $fixtureContract.Pattern) {
        $failures.Add("smoke classifier fixture lost its core behavior: $($fixtureContract.Name)")
    }
}
if ($harnessWorkflowText -match '(?ms)^  push:\r?\n    branches:') {
    $failures.Add("agent-harness push trigger is branch-filtered and can skip the active development branch")
}
foreach ($requiredHarnessPath in @(
    '"*.md"',
    '"README.md"',
    '"MANUS_PROMPT_PREFIX.md"',
    '"AGENTS.md"',
    '"CLAUDE.md"',
    '".github/copilot-instructions.md"',
    '".github/workflows/project-secret-scan.yml"',
    '".claude/rules/**"',
    '".claude/skills/**"',
    '".agents/skills/**"',
    '"docs/**"',
    '"godot/tools/run_pre_push_checks.ps1"',
    '"godot/tools/run_nightly_smoke.ps1"',
    '"godot/tools/nightly_smoke_result_policy.ps1"',
    '"godot/tools/run_smoke_tests.ps1"',
    '"godot/tools/assert_no_interactive_godot_game.ps1"',
    '"godot/tools/run_headless_load_check.ps1"',
    '"godot/tools/run_warning_scan.ps1"',
    '"godot/tools/gd_warning_scan.gd"',
    '"godot/tools/run_victory_highlight_replay_clip_pixel_qa.ps1"',
    '"godot/tools/run_plaza_r3d_production_vulkan_qa.ps1"',
    '"godot/tools/verify_interactive_play_validation_guard.ps1"',
    '"godot/tools/godot_output_classifier.ps1"',
    '"godot/tools/verify_nightly_smoke_status.ps1"',
    '"godot/tools/verify_smoke_runner_classifier.ps1"',
    '"godot/tests/fixtures/**"',
    '"tools/verify_agent_harness.ps1"',
    '"tools/verify_no_project_secrets.ps1"',
    '"tools/verify_project_secret_scanner.ps1"'
)) {
    if (-not $harnessWorkflowText.Contains($requiredHarnessPath)) {
        $failures.Add("agent-harness workflow is missing trigger input: $requiredHarnessPath")
    }
}
if ($harnessWorkflowText -notmatch '\\tools\\verify_agent_harness\.ps1') {
    $failures.Add("agent-harness workflow does not execute the verifier")
}

try {
    & (Join-Path $RepoRoot "godot/tools/verify_interactive_play_validation_guard.ps1") `
        -ProjectPath (Join-Path $RepoRoot "godot")
}
catch {
    $failures.Add("interactive-play validation guard regression failed: $($_.Exception.Message)")
}

foreach ($warning in $warnings) {
    Write-Warning $warning
}

if ($failures.Count -gt 0) {
    foreach ($failure in $failures) {
        Write-Error $failure -ErrorAction Continue
    }
    throw "Agent harness verification failed with $($failures.Count) issue(s)"
}

Write-Host "agent harness verification: ok"
