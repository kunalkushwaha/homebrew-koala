class Koala < Formula
  desc "Run AI agents and other Linux workloads in VMs on Apple silicon"
  homepage "https://kunalkushwaha.github.io/homebrew-koala/"
  url "https://github.com/kunalkushwaha/homebrew-koala/releases/download/v0.1.0-rc.2/koala-0.1.0-rc.2-darwin-arm64.tar.gz"
  version "0.1.0-rc.2"
  sha256 "1843d36c95652b23f707ad5ad4b8a8e7b5f59368554de5adc7e54162687ad006"
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
    assert_match "koala 0.1.0-rc.2", shell_output("#{bin}/koala --version")
  end
end
