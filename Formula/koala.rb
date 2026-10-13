class Koala < Formula
  desc "Linux VMs for development and CI on Apple silicon (preview)"
  homepage "https://github.com/kunalkushwaha/homebrew-koala"
  url "https://github.com/kunalkushwaha/homebrew-koala/releases/download/v0.1.0-preview.5/koala-0.1.0-preview.5-darwin-arm64.tar.gz"
  version "0.1.0-preview.5"
  sha256 "c137b7168b60f85e8aa769be901dbc73854b7ff0d15581331649c62bf81fa51b"
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
      Koala 0.1.0-preview.5 is a preview: its security proofs are not complete.
      Finish the installation for your user (no sudo):
        koala system install
      Before `brew uninstall koala`, run:
        koala system uninstall
      It keeps your VMs, volumes and images; add --purge --yes to delete them.
    EOS
  end

  test do
    assert_match "koala 0.1.0-preview.5", shell_output("#{bin}/koala --version")
  end
end
