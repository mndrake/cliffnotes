# $1: flag. 1: install git, 2: install R, 3: install both git and R.
# $2: git installer .pkg file path
# $3: R installer .pkg file path
if [ $1 -eq "1" ] || [ $1 -eq "3" ]; then
  echo "Installing git."
  /usr/sbin/installer -pkg $2 -target /
fi
if [ $1 -eq "2" ] || [ $1 -eq "3" ]; then
  echo "Installing R."
  /usr/sbin/installer -pkg $3 -target /
fi
