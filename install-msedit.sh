sudo apt update
sudo apt install -y ca-certificates curl wget tar zstd

MSEDIT_URL=$(
  curl -fsSL "https://api.github.com/repos/microsoft/edit/releases/latest" \
  | grep -o '"browser_download_url": "[^"]*x86_64-linux-gnu.tar.zst"' \
  | cut -d'"' -f4
)

echo "Downloading from: $MSEDIT_URL"
wget -qO /tmp/msedit.tar.zst "$MSEDIT_URL"

sudo tar --zstd -xf /tmp/msedit.tar.zst -C /usr/local/bin edit
sudo mv /usr/local/bin/edit /usr/local/bin/msedit
sudo chmod 0755 /usr/local/bin/msedit

msedit --version