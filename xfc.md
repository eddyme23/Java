# Install
wget -qO- https://raw.githubusercontent.com/eddyme23/Java/refs/heads/main/xfc.sh | bash

wget -qO xfc.sh https://raw.githubusercontent.com/eddyme23/Java/refs/heads/main/xfc.sh && bash xfc.sh

bash <(curl -sL https://raw.githubusercontent.com/eddyme23/Java/master/xfc.sh)


# Check wrap status
warp-cli --accept-tos status

# Activate wrap if offline
warp-cli --accept-tos connect
