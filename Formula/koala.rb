class Koala < Formula
  desc "Linux VMs for development and CI on Apple silicon (preview)"
  homepage "https://github.com/kunalkushwaha/homebrew-koala"
  url "https://github.com/kunalkushwaha/homebrew-koala/releases/download/v0.1.0-preview.3/koala-0.1.0-preview.3-darwin-arm64.tar.gz"
  version "0.1.0-preview.3"
  sha256 "5070e08a20a84896f4c141fddc9f00c8951e7f9c46d895eeaa15eabbfa088fe0"
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
      Koala 0.1.0-preview.3 is a preview: its security proofs are not complete.
      Finish the installation for your user (no sudo):
        koala system install
      Before `brew uninstall koala`, run:
        koala system uninstall
      It keeps your VMs, volumes and images; add --purge --yes to delete them.
    EOS
  end

  test do
    assert_match "koala 0.1.0-preview.3", shell_output("#{bin}/koala --version")
  end
end
