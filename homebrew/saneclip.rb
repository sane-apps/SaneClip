cask "saneclip" do
  version "1.1"
  sha256 "c86f4c9aa3a2fecdf4e69973846a651a583a27e5ab0ae14401b2e43bd371a5b5"

  url "https://github.com/stephanjoseph/SaneClip/releases/download/v#{version}/SaneClip-#{version}.dmg"
  name "SaneClip"
  desc "Beautiful clipboard manager for macOS with Touch ID protection"
  homepage "https://saneclip.com"

  depends_on macos: ">= :sequoia"

  app "SaneClip.app"

  zap trash: [
    "~/Library/Preferences/com.saneclip.app.plist",
    "~/Library/Application Support/SaneClip",
  ]
end
