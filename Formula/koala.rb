class Koala < Formula
  desc "Run AI agents and other Linux workloads in VMs on Apple silicon"
  homepage "https://kunalkushwaha.github.io/homebrew-koala/"
  url "https://github.com/kunalkushwaha/homebrew-koala/releases/download/v0.1.0-rc.1/koala-0.1.0-rc.1-darwin-arm64.tar.gz"
  version "0.1.0-rc.1"
  sha256 "4b447458eca5c455cd80b1386b35a53f8cc00ac255a239e8f8b170664fcbf400"
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
    assert_match "koala 0.1.0-rc.1", shell_output("#{bin}/koala --version")
  end
end
