class Koala < Formula
  desc "Linux VMs for development and CI on Apple silicon (preview)"
  homepage "https://kunalkushwaha.github.io/homebrew-koala/"
  url "https://github.com/kunalkushwaha/homebrew-koala/releases/download/v0.1.0-preview.16/koala-0.1.0-preview.16-darwin-arm64.tar.gz"
  version "0.1.0-preview.16"
  sha256 "f54bca49da602317a353c7a0a6abb8654a61905016dee6ea60d1810030c9fe54"
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
      Koala 0.1.0-preview.16 is a preview: commands and formats may change between previews.
      Finish the installation for your user (no sudo):
        koala system install
      Before `brew uninstall koala`, run:
        koala system uninstall
      It keeps your VMs, volumes and images; add --purge --yes to delete them.
    EOS
  end

  test do
    assert_match "koala 0.1.0-preview.16", shell_output("#{bin}/koala --version")
  end
end
