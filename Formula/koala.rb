class Koala < Formula
  desc "Run AI agents and other Linux workloads in VMs on Apple silicon"
  homepage "https://kunalkushwaha.github.io/homebrew-koala/"
  url "https://github.com/kunalkushwaha/homebrew-koala/releases/download/v0.1.0-rc.4/koala-0.1.0-rc.4-darwin-arm64.tar.gz"
  version "0.1.0-rc.4"
  sha256 "b723eb93d98d809938169108f1111116858de183a3b8765a0c98c05b77ef8276"
  license "Apache-2.0"

  depends_on arch: :arm64
  depends_on macos: :tahoe

  def install
    # The keg is the release payload that `koala system install` checks.
    bin.install "bin/koala", "bin/koala-transfer"
    (libexec/"koala").install Dir["libexec/koala/*"]
    (share/"koala").install Dir["share/koala/*"]
    prefix.install "LICENSE", "NOTICE"
  end

  def caveats
    <<~EOS
      Finish the installation for your user (no sudo):
        koala system install
      Before `brew uninstall koala`, run:
        koala system uninstall
      It keeps your VMs, volumes and images; add --purge --yes to delete them.
    EOS
  end

  test do
    assert_match "koala 0.1.0-rc.4", shell_output("#{bin}/koala --version")
  end
end
