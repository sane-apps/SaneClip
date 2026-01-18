cask "saneclip" do
  version "1.0.1"
  sha256 "05e07c84babfa01c8d9068cb882cd02edacb99a407d8a85f6612e03669f571ed"

  url "https://github.com/stephanjoseph/SaneClip/releases/download/v#{version}/SaneClip-#{version}.dmg"
  name "SaneClip"
  desc "Beautiful clipboard manager for macOS with Touch ID protection"
  homepage "https://saneclip.com"

  depends_on macos: ">= :sonoma"

  app "SaneClip.app"

  zap trash: [
    "~/Library/Preferences/com.saneclip.app.plist",
    "~/Library/Application Support/SaneClip",
  ]
end
