#!/usr/bin/env ruby
# frozen_string_literal: true

# SaneMaster standalone — minimal build tool for external contributors.
# The full SaneMaster lives in SaneProcess infra (internal development).

require "open3"
require "fileutils"
require "shellwords"

PROJECT_ROOT = File.expand_path("..", __dir__)
XCODEPROJ = File.join(PROJECT_ROOT, "SaneClip.xcodeproj")
SCHEME = "SaneClip"

def headless_unsigned_build?
  ENV["SANEMASTER_HEADLESS"] == "1" || ENV["GITHUB_ACTIONS"] == "true" || ENV["CI"] == "true" || ENV["CI"] == "1"
end

def unsigned_signing_args
  [
    "CODE_SIGNING_ALLOWED=NO",
    "CODE_SIGNING_REQUIRED=NO",
    "CODE_SIGN_IDENTITY=",
    "DEVELOPMENT_TEAM=",
    "PROVISIONING_PROFILE_SPECIFIER=",
    "PROVISIONING_PROFILE="
  ]
end

def run(cmd, label = nil)
  printable = cmd.is_a?(Array) ? cmd.map { |part| Shellwords.escape(part) }.join(" ") : cmd
  warn "=> #{label || printable}"
  stdout, stderr, status = if cmd.is_a?(Array)
                             Open3.capture3(*cmd, chdir: PROJECT_ROOT)
                           else
                             Open3.capture3(cmd, chdir: PROJECT_ROOT)
                           end
  unless status.success?
    warn stderr unless stderr.empty?
    warn stdout unless stdout.empty?
    abort "FAILED: #{label || cmd}"
  end
  warn stdout unless stdout.empty?
  stdout
end

def build(config = "Debug")
  cmd = [
    "xcodebuild",
    "-project", XCODEPROJ,
    "-scheme", SCHEME,
    "-configuration", config,
    "-destination", "platform=macOS,arch=arm64",
    "build"
  ]
  if headless_unsigned_build?
    warn "   unsigned headless build mode active"
    cmd.concat(unsigned_signing_args)
  end
  run(cmd, "Build (#{config})")
end

def test
  cmd = [
    "xcodebuild",
    "-project", XCODEPROJ,
    "-scheme", SCHEME,
    "-configuration", "Debug",
    "-destination", "platform=macOS,arch=arm64",
    "test"
  ]
  if headless_unsigned_build?
    warn "   unsigned headless test mode active"
    cmd.concat(unsigned_signing_args)
  end
  run(cmd, "Test")
end

def verify
  build
  test
  warn "\nAll good."
end

def test_mode
  build
  app = Dir.glob(File.join(PROJECT_ROOT, "build/**/SaneClip.app")).first
  app ||= Dir.glob(File.expand_path("~/Library/Developer/Xcode/DerivedData/**/Build/Products/Debug/SaneClip.app")).first
  abort "Could not find built SaneClip.app" unless app
  system("killall SaneClip 2>/dev/null")
  sleep 0.5
  system("open '#{app}'")
  warn "Launched #{app}"
end

def usage
  warn <<~HELP
    SaneMaster standalone (external contributor mode)

    Usage: ./scripts/SaneMaster.rb <command>

    Commands:
      build       Build Debug configuration
      test        Run unit tests
      verify      Build + test
      test_mode   Build, kill existing, launch app
      help        Show this message
  HELP
end

case ARGV[0]
when "build"      then build
when "test"       then test
when "verify"     then verify
when "test_mode"  then test_mode
when "help", nil  then usage
else
  warn "Unknown command: #{ARGV[0]}"
  usage
  exit 1
end
