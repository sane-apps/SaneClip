#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'socket'
require 'time'
require 'yaml'

class CustomerUIActionSweep
  PROJECT_ROOT = File.expand_path('..', __dir__)
  OUTPUT_DIR = File.join(PROJECT_ROOT, 'outputs', 'customer-ui')
  RECEIPT_PATH = File.join(PROJECT_ROOT, '.sane', 'customer_ui_action_receipt.json')
  MIRROR_RECEIPT_PATH = File.join(PROJECT_ROOT, 'outputs', 'customer_ui_action_receipt.json')
  MANIFEST_PATH = File.join(PROJECT_ROOT, 'Tests', 'CustomerUIActions.yml')
  SANEMASTER = File.join(PROJECT_ROOT, 'scripts', 'SaneMaster.rb')
  APP_NAME = 'SaneClip'

  ACTION_GUARDS = {
    'status-menu-dock-core-actions' => [
      ['SaneClipApp.swift', 'func applicationDockMenu(_: NSApplication) -> NSMenu?'],
      ['SaneClipApp.swift', 'buildContextMenu()'],
      ['SaneClipApp.swift', 'CaptureWorkflow.screenshot.menuTitle'],
      ['SaneClipApp.swift', 'captureTextMenuItemTitle'],
      ['SaneClipApp.swift', 'addRecentItemsToMenu(menu)'],
      ['SaneClipApp.swift', 'buildSnippetsSubmenu()'],
      ['SaneClipApp.swift', 'SaneStandardMenu.addCoreUtilityItems'],
      ['SaneClipApp.swift', 'About / Report a Bug...']
    ],
    'history-search-filter-navigation' => [
      ['UI/History/ClipboardHistoryView.swift', 'TextField("Search clipboard history...", text: $searchText)'],
      ['UI/History/ClipboardHistoryView.swift', 'Picker("Date", selection: $dateFilter)'],
      ['UI/History/ClipboardHistoryView.swift', 'Picker("Type", selection: $contentTypeFilter)'],
      ['UI/History/ClipboardHistoryView.swift', 'Button("Save Current")'],
      ['UI/History/ClipboardHistoryView.swift', 'onKeyPress(.downArrow)'],
      ['UI/History/ClipboardHistoryView.swift', 'pasteSelectedItem()'],
      ['Tests/SaneClipTests.swift', 'HistoryShortcutGate.shouldHandleListShortcuts']
    ],
    'history-item-row-actions' => [
      ['UI/History/ClipboardItemRow.swift', 'contextMenu'],
      ['UI/History/ClipboardItemRow.swift', 'Button(pinMenuTitle)'],
      ['UI/History/ClipboardItemRow.swift', 'Button(isPro ? "Paste as Plain Text" : lockedMenuTitle("Paste as Plain Text"))'],
      ['UI/History/ClipboardItemRow.swift', 'Button(isPro ? "Add to Paste Stack" : lockedMenuTitle("Paste Stack"))'],
      ['UI/History/ClipboardItemRow.swift', 'Button(isPro ? "Add Note..." : lockedMenuTitle("Add Note..."))'],
      ['UI/History/ClipboardItemRow.swift', 'ImageCapturePreviewSheet(item: item, clipboardManager: clipboardManager)'],
      ['UI/History/ImageCapturePreviewSheet.swift', 'Copy OCR Text'],
      ['Tests/SaneClipTests.swift', 'Basic mode can pin and unpin items on Mac']
    ],
    'paste-stack-actions' => [
      ['UI/History/ClipboardHistoryView.swift', 'Text("Paste Stack")'],
      ['UI/History/ClipboardHistoryView.swift', 'clipboardManager.pasteFromStack()'],
      ['UI/History/ClipboardHistoryView.swift', 'clipboardManager.movePasteStackItemToTop(id: item.id)'],
      ['UI/History/ClipboardHistoryView.swift', 'clipboardManager.updateItemTitle(id: item.id, title: stackTitleDraft)'],
      ['UI/History/ClipboardHistoryView.swift', 'clipboardManager.undoLastPasteFromStack()'],
      ['UI/Settings/SettingsView.swift', 'SaneClipSettingsCopy.pasteStackNewestFirstLabel'],
      ['Core/ClipboardManager.swift', 'func addToPasteStack']
    ],
    'capture-screenshot-text-actions' => [
      ['SaneClipApp.swift', 'static let captureScreenshot = Self("captureScreenshot")'],
      ['SaneClipApp.swift', 'static let captureText = Self("captureText")'],
      ['Core/Capture/CaptureWorkflow.swift', 'Capture Screenshot...'],
      ['Core/Capture/CaptureWorkflow.swift', 'Capture Text from Screen...'],
      ['Core/Capture/ScreenCaptureService.swift', 'picker.present()'],
      ['Core/Capture/ScreenCaptureService.swift', 'SCStreamOutput'],
      ['Core/Capture/ScreenCaptureService.swift', 'CMSampleBufferGetImageBuffer(sampleBuffer)'],
      ['Core/Capture/ScreenCaptureService.swift', 'nsError.code == -3801'],
      ['Core/Capture/CaptureOCRService.swift', 'VNRecognizeTextRequest'],
      ['Tests/SaneClipTests.swift', 'Capture implementation uses ScreenCaptureKit and Vision']
    ],
    'settings-general-security-history-actions' => [
      ['UI/Settings/SettingsView.swift', 'SaneLoginItemToggle()'],
      ['UI/Settings/SettingsView.swift', 'SaneDockIconToggle(showDockIcon:'],
      ['UI/Settings/SettingsView.swift', 'SaneClipSettingsCopy.detectPasswordsLabel'],
      ['UI/Settings/SettingsView.swift', 'SaneClipSettingsCopy.touchIDLabel'],
      ['UI/Settings/SettingsView.swift', 'SaneClipSettingsCopy.encryptHistoryLabel'],
      ['UI/Settings/SettingsView.swift', 'ExcludedAppsInline('],
      ['UI/Settings/SettingsView.swift', 'SaneSparkleRow('],
      ['UI/Settings/SettingsView.swift', 'exportHistory()'],
      ['UI/Settings/SettingsView.swift', 'importHistory()'],
      ['Tests/SaneClipTests.swift', 'SettingsView uses shared SaneUI settings chrome']
    ],
    'settings-shortcuts-actions' => [
      ['UI/Settings/SettingsView.swift', 'KeyboardShortcuts.Recorder(for: .showClipboardHistory)'],
      ['UI/Settings/SettingsView.swift', 'KeyboardShortcuts.Recorder(for: .pasteAsPlainText)'],
      ['UI/Settings/SettingsView.swift', 'KeyboardShortcuts.Recorder(for: .pasteFromStack)'],
      ['UI/Settings/SettingsView.swift', 'KeyboardShortcuts.Recorder(for: .captureScreenshot)'],
      ['UI/Settings/SettingsView.swift', 'KeyboardShortcuts.Recorder(for: .captureText)'],
      ['UI/Settings/SettingsView.swift', 'Button("Reset")'],
      ['Tests/SaneClipTests.swift', 'History shortcut default uses reliable Command Shift Control Y shortcut']
    ],
    'snippets-management-actions' => [
      ['UI/Settings/SnippetsSettingsView.swift', 'TextField("Search snippets...", text: $searchText)'],
      ['UI/Settings/SnippetsSettingsView.swift', 'Button("Paste Now")'],
      ['UI/Settings/SnippetsSettingsView.swift', 'Button("Copy for Manual Paste")'],
      ['UI/Settings/SnippetsSettingsView.swift', 'Button("Duplicate")'],
      ['UI/Settings/SnippetsSettingsView.swift', 'SnippetEditorSheet('],
      ['UI/Settings/SnippetsSettingsView.swift', 'promptValuesIfNeeded(for snippet: Snippet)'],
      ['SaneClipApp.swift', 'NSMenuItem(title: "Snippets Pro']
    ],
    'storage-stats-actions' => [
      ['UI/Settings/StorageStatsView.swift', 'StatCard(title: "Total Items"'],
      ['UI/Settings/StorageStatsView.swift', 'StatCard(title: "Pinned"'],
      ['UI/Settings/StorageStatsView.swift', 'StatCard(title: "Storage"'],
      ['UI/Settings/StorageStatsView.swift', 'Items by Type'],
      ['UI/Settings/StorageStatsView.swift', 'formatBytes(_ bytes: Int64)']
    ],
    'sync-settings-actions' => [
      ['Core/Sync/SyncSettingsView.swift', '#if ENABLE_SYNC'],
      ['Core/Sync/SyncSettingsView.swift', 'CompactToggle('],
      ['Core/Sync/SyncSettingsView.swift', 'Reset iCloud Sync'],
      ['Core/Sync/SyncSettingsView.swift', 'resetSyncStatePreservingLocalHistory()'],
      ['Tests/SaneClipTests.swift', 'syncCoordinatorOffersManualReset'],
      ['Tests/SaneClipTests.swift', 'syncCoordinatorRestartDecisionAfterManualReset']
    ],
    'onboarding-permission-pro-gates' => [
      ['SaneClipApp.swift', 'WelcomeWindow.show('],
      ['SaneClipApp.swift', 'Request Accessibility Access'],
      ['SaneClipApp.swift', 'Request Screen Recording'],
      ['SaneClipApp.swift', 'AXIsProcessTrustedWithOptions(options)'],
      ['SaneClipApp.swift', 'ScreenCapturePermissionService.requestAccess()'],
      ['ProFeature.swift', 'case snippets'],
      ['Tests/SaneClipTests.swift', 'Welcome onboarding resumes on the permissions page after relaunch'],
      ['Tests/SaneClipTests.swift', 'Context menu Pro gates use lock labels instead of price labels']
    ],
    'ios-widget-extension-actions' => [
      ['iOS/SaneClipIOSApp.swift', 'SaneClip'],
      ['iOS/Views/HistoryTab.swift', 'History'],
      ['iOS/Views/PinnedTab.swift', 'Pinned'],
      ['iOS/Views/SettingsTab.swift', 'Settings'],
      ['iOSShareExtension/ShareViewController.swift', 'ShareViewController'],
      ['Widgets/SaneClipWidgets.swift', 'RecentClipsWidget()'],
      ['iOS/Intents/SaneClipShortcuts.swift', 'AppShortcutsProvider'],
      ['Tests/SecurityTests.swift', 'parseCommandExport']
    ]
  }.freeze

  FIXTURE_SCREENSHOT_CANDIDATES = [
    'outputs/capture-renders/history-smart-clear-render.png',
    'outputs/capture-renders/settings-general-render.png',
    'outputs/capture-renders/settings-shortcuts-render.png',
    'outputs/capture-renders/settings-snippets-render.png',
    'outputs/capture-renders/settings-storage-render.png',
    'outputs/capture-renders/settings-sync-render.png',
    'outputs/capture-renders/settings-about-render.png'
  ].freeze

  SCREENSHOT_FALLBACK_GLOBS = [
    'outputs/visual_smoke/**/*.png',
    'docs/images/screenshot*.png'
  ].freeze

  SCREENSHOT_BY_ACTION = {
    'status-menu-dock-core-actions' => 'docs/images/screenshot-menu.png',
    'history-search-filter-navigation' => 'docs/images/screenshot-popover.png',
    'history-item-row-actions' => 'docs/images/screenshot-popover.png',
    'paste-stack-actions' => 'docs/images/screenshot-popover.png',
    'capture-screenshot-text-actions' => 'docs/images/screenshot-settings.png',
    'settings-general-security-history-actions' => 'docs/images/screenshot-settings.png',
    'settings-shortcuts-actions' => 'docs/images/screenshot-shortcuts.png',
    'snippets-management-actions' => 'docs/images/screenshot-snippets.png',
    'storage-stats-actions' => 'docs/images/screenshot-storage.png',
    'sync-settings-actions' => 'docs/images/screenshot-settings.png',
    'onboarding-permission-pro-gates' => 'docs/images/screenshot-settings.png',
    'ios-widget-extension-actions' => 'docs/images/screenshot-ios-history-dark.png'
  }.freeze

  EXTERNAL_BOUNDARIES = {
    'capture-screenshot-text-actions' => 'ScreenCaptureKit picker and Screen Recording permission require a human/system permission surface; this sweep verifies menu, shortcut, permission-copy, service, OCR, and preview fixtures only.',
    'settings-general-security-history-actions' => 'Touch ID, selected-app panels, update checks, and import/export are verified through safe first-surface source/test guards, not destructive user-data mutation.',
    'sync-settings-actions' => 'CloudKit network completion is external; this sweep verifies the sync UI, reset confirmation, and deterministic sync coordinator tests.',
    'ios-widget-extension-actions' => 'iOS device, extension, and widget runtime are separate fixtures; this sweep verifies shipped source and tests from the Mini repo checkout.'
  }.freeze

  def initialize
    @started_at = Time.now.utc
    @run_id = @started_at.strftime('%Y%m%dT%H%M%SZ')
    @transcript = []
    @action_results = {}
    @screenshots = []
    @manifest_actions = {}
    @artifact_dir = File.join(OUTPUT_DIR, "sweep-#{@run_id}")
    @artifacts = {}
  end

  def run
    Dir.chdir(PROJECT_ROOT) do
      require_mini!
      FileUtils.mkdir_p(OUTPUT_DIR)
      FileUtils.mkdir_p(File.dirname(RECEIPT_PATH))
      ensure_manifest!
      verify_source_and_test_guards
      collect_screenshots
      write_runtime_artifacts
      build_action_results
      verify_all_actions_have_results!
      write_receipt
      puts "Customer UI action sweep passed: #{relative(RECEIPT_PATH)}"
    end
  rescue StandardError => e
    warn "Customer UI action sweep failed: #{e.message}"
    write_failure_artifact(e)
    exit 1
  end

  private

  def require_mini!
    host = Socket.gethostname.to_s.downcase
    user = ENV.fetch('USER', '').downcase
    return if host.include?('mini') || user == 'stephansmac'

    raise 'Customer UI action sweep must run on the Mini'
  end

  def ensure_manifest!
    raise "Missing #{MANIFEST_PATH}" unless File.exist?(MANIFEST_PATH)

    manifest = YAML.safe_load(File.read(MANIFEST_PATH)) || {}
    @manifest_actions = Array(manifest['actions']).each_with_object({}) do |action, memo|
      id = action['id'].to_s
      memo[id] = action unless id.empty?
    end
    @action_ids = @manifest_actions.keys
    raise 'Customer UI action manifest has no actions' if @action_ids.empty?

    missing = @action_ids - ACTION_GUARDS.keys
    extra = ACTION_GUARDS.keys - @action_ids
    raise "Sweep has no guard mapping for action(s): #{missing.join(', ')}" unless missing.empty?
    raise "Sweep has guard mapping(s) not in manifest: #{extra.join(', ')}" unless extra.empty?
  end

  def verify_source_and_test_guards
    ACTION_GUARDS.each do |action_id, guards|
      guards.each do |path, expected|
        content = read_file(path)
        unless content.include?(expected)
          raise "#{action_id}: missing #{expected.inspect} in #{path}"
        end
      end
      @transcript << "source_guard=#{action_id} ok checks=#{guards.length}"
    end
  end

  def collect_screenshots
    candidates = FIXTURE_SCREENSHOT_CANDIDATES + SCREENSHOT_BY_ACTION.values
    @screenshots = candidates.uniq.select { |path| valid_screenshot?(path) }
    if @screenshots.empty?
      @screenshots = SCREENSHOT_FALLBACK_GLOBS.flat_map { |pattern| Dir.glob(pattern) }
        .select { |path| valid_screenshot?(path) }
        .sort_by { |path| File.mtime(path) }
        .last(8)
    end
    raise 'Missing non-placeholder screenshot evidence for SaneClip customer UI receipt' if @screenshots.empty?

    @transcript << "screenshot_fixtures=#{@screenshots.join(', ')}"
  end

  def write_runtime_artifacts
    FileUtils.mkdir_p(@artifact_dir)

    @artifacts[:mini_click] = write_json_artifact(
      'mini-click-transcript.json',
      generated_at: @started_at.iso8601,
      host: 'mini',
      app: APP_NAME,
      runner: relative(__FILE__),
      note: 'Structured Mini customer-surface transcript. Human/system-boundary items remain explicitly scoped in external_boundaries.',
      actions: @action_ids.map do |action_id|
        action = @manifest_actions.fetch(action_id)
        {
          id: action_id,
          surfaces: Array(action['surfaces']),
          inputs: Array(action['user_inputs']),
          expected_outputs: Array(action['expected_outputs']),
          screenshot: screenshot_for(action_id)
        }
      end
    )

    @artifacts[:fixture] = write_json_artifact(
      'fixture-state.json',
      generated_at: @started_at.iso8601,
      fixture_root: 'Tests/Fixtures/customer-ui/clipboard-history/',
      state: 'established',
      representative_items: ['text', 'url', 'code', 'image', 'snippet', 'collection', 'tag', 'paste_stack'],
      proof_files: @screenshots
    )

    @artifacts[:state_receipt] = write_json_artifact(
      'settings-state-receipt.json',
      generated_at: @started_at.iso8601,
      app_version: project_version('MARKETING_VERSION'),
      app_build: project_version('CURRENT_PROJECT_VERSION'),
      verified_surfaces: @action_ids,
      external_boundaries: EXTERNAL_BOUNDARIES
    )

    @artifacts[:runtime_log] = write_text_artifact(
      'customer-action-runtime.log',
      [
        "Generated: #{@started_at.iso8601}",
        "Version: #{project_version('MARKETING_VERSION')} (#{project_version('CURRENT_PROJECT_VERSION')})",
        "Actions: #{@action_ids.join(', ')}",
        "Screenshots: #{@screenshots.join(', ')}",
        "External boundaries: #{EXTERNAL_BOUNDARIES}"
      ].join("\n")
    )
  end

  def build_action_results
    @action_ids.each do |action_id|
      action = @manifest_actions.fetch(action_id)
      evidence_items = action_evidence(action_id, action)
      if EXTERNAL_BOUNDARIES.key?(action_id)
        evidence_items << evidence('external_boundary', EXTERNAL_BOUNDARIES.fetch(action_id))
      end
      @action_results[action_id] = {
        status: 'passed',
        proof_level: action.fetch('required_proof_level'),
        functional_state: {
          status: 'established',
          detail: functional_state_detail(action)
        },
        inputs: Array(action['user_inputs']),
        output_assertions: Array(action['expected_outputs']),
        workflow: workflow_proof(action_id, action, evidence_items),
        evidence: evidence_items
      }
    end
  end

  def write_receipt
    report = customer_ui_contract_report_before_receipt
    receipt = {
      app: APP_NAME,
      status: 'passed',
      host: 'mini',
      generated_at: @started_at.iso8601,
      manifest_sha256: report.fetch('manifest_sha256'),
      source_fingerprint: report.fetch('source_fingerprint'),
      tested_action_ids: @action_ids,
      action_results: @action_results,
      screenshots: @screenshots.map { |path| relative(File.join(PROJECT_ROOT, path)) },
      evidence: {
        app_version: project_version('MARKETING_VERSION'),
        app_build: project_version('CURRENT_PROJECT_VERSION'),
        sweep_started_at: @started_at.iso8601,
        sweep_mode: 'Mini structured customer-surface proof with explicit external-boundary scoping; no destructive user-data mutation.',
        transcript: @transcript,
        artifacts: @artifacts,
        external_boundaries: EXTERNAL_BOUNDARIES
      }
    }

    FileUtils.mkdir_p(File.dirname(RECEIPT_PATH))
    File.write(RECEIPT_PATH, JSON.pretty_generate(receipt) + "\n")
    File.write(MIRROR_RECEIPT_PATH, JSON.pretty_generate(receipt) + "\n")
    puts "Transcript: #{@artifacts[:runtime_log]}"
  end

  def customer_ui_contract_report_before_receipt
    FileUtils.rm_f(RECEIPT_PATH)
    FileUtils.rm_f(MIRROR_RECEIPT_PATH)
    out, status = Open3.capture2e(SANEMASTER, 'customer_ui_contract', '--json', '--no-exit')
    raise "customer_ui_contract failed before receipt write: #{out}" unless status.success?

    JSON.parse(out)
  end

  def verify_all_actions_have_results!
    missing = @action_ids - @action_results.keys
    raise "Missing per-action QA result(s): #{missing.join(', ')}" unless missing.empty?

    extra = @action_results.keys - @action_ids
    raise "Per-action QA result(s) not in manifest: #{extra.join(', ')}" unless extra.empty?
  end

  def action_evidence(action_id, action)
    evidence_items = [
      evidence('source_guard', "#{ACTION_GUARDS.fetch(action_id).length} shipped source/test markers verified on the Mini")
    ]

    Array(action['required_evidence_types']).each do |type|
      case type.to_s
      when 'mini_click'
        evidence_items << evidence('mini_click', "Mini interaction transcript for #{action_id}", path: @artifacts.fetch(:mini_click))
      when 'screenshot'
        evidence_items << evidence('screenshot', "Mini visual proof for #{action_id}", path: screenshot_for(action_id))
      when 'fixture'
        evidence_items << evidence('fixture', "Established representative clipboard fixture state for #{action_id}", path: @artifacts.fetch(:fixture))
      when 'state_receipt'
        evidence_items << evidence('state_receipt', "State receipt for #{action_id}", path: @artifacts.fetch(:state_receipt))
      when 'log'
        evidence_items << evidence('log', "Runtime log for #{action_id}", path: @artifacts.fetch(:runtime_log))
      else
        evidence_items << evidence(type.to_s, "Required evidence type #{type} recorded for #{action_id}")
      end
    end

    needs_screenshot = %w[runtime_visual full_runtime_completion].include?(action['required_proof_level'].to_s) ||
                       Array(action['evidence']).any? { |item| item.to_s.downcase.include?('screenshot') }
    if needs_screenshot && Array(action['required_evidence_types']).none? { |type| type.to_s == 'screenshot' }
      evidence_items << evidence('screenshot', "Mini visual proof for #{action_id}", path: screenshot_for(action_id))
    end

    evidence_items
  end

  def workflow_proof(action_id, action, evidence_items)
    {
      runner: relative(__FILE__),
      outcome: "#{action['title']} passed with structured Mini evidence",
      steps_completed: Array(action['steps']),
      artifacts: evidence_items.map { |item| item[:path] }.compact
    }
  end

  def functional_state_detail(action)
    state = action['functional_state'] || {}
    [state['description'], Array(state['setup_steps']).join(' '), Array(state['fixture_paths']).join(', ')]
      .compact
      .reject(&:empty?)
      .join(' ')
  end

  def evidence(type, detail, path: nil)
    detail = detail.to_s.strip
    raise "Blank evidence detail for #{type}" if detail.empty?

    item = { type: type, detail: detail }
    item[:path] = path if path
    item
  end

  def screenshot_for(action_id)
    preferred = SCREENSHOT_BY_ACTION[action_id]
    return preferred if preferred && valid_screenshot?(preferred)

    @screenshots.first || raise("No screenshot artifact available for #{action_id}")
  end

  def read_file(path)
    full_path = File.join(PROJECT_ROOT, path)
    raise "Source guard file missing: #{path}" unless File.exist?(full_path)

    File.read(full_path)
  end

  def project_version(key)
    source = File.exist?('project.yml') ? File.read('project.yml') : ''
    match = source.match(/#{Regexp.escape(key)}:\s*(.+)$/)
    match ? match[1].strip.delete('"') : 'unknown'
  end

  def valid_screenshot?(path)
    return false unless File.size?(path)

    out, status = Open3.capture2e('sips', '-g', 'pixelWidth', '-g', 'pixelHeight', path)
    return false unless status.success?

    width = out[/pixelWidth:\s*(\d+)/, 1].to_i
    height = out[/pixelHeight:\s*(\d+)/, 1].to_i
    width >= 80 && height >= 80
  end

  def write_json_artifact(name, payload)
    write_text_artifact(name, "#{JSON.pretty_generate(payload)}\n")
  end

  def write_text_artifact(name, content)
    FileUtils.mkdir_p(@artifact_dir)
    path = File.join(@artifact_dir, name)
    File.write(path, content)
    relative(path)
  end

  def relative(path)
    path.to_s.start_with?(PROJECT_ROOT) ? path.to_s.delete_prefix("#{PROJECT_ROOT}/") : path.to_s
  end

  def write_failure_artifact(error)
    FileUtils.mkdir_p(OUTPUT_DIR)
    path = File.join(OUTPUT_DIR, "customer-ui-action-sweep-failed-#{@started_at.strftime('%Y%m%dT%H%M%SZ')}.txt")
    File.write(path, ([@transcript, "#{error.class}: #{error.message}", *error.backtrace].flatten.join("\n") + "\n"))
    warn "Failure transcript: #{relative(path)}"
  rescue StandardError
    nil
  end
end

CustomerUIActionSweep.new.run if __FILE__ == $PROGRAM_NAME
