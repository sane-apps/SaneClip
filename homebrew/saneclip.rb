cask "saneclip" do
  version "1.1"
  sha256 "35dac44556e600cbf7bcdb418ab78484cf948fef51f16609388aed34a346fe95"

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
