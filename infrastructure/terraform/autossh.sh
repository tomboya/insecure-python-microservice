set -e

# Determines the operating system.
OS="$(uname)"

if [ "${OS}" = "Darwin" ] ; then
  # use brew for macOS
  brew install autossh
elif [ "${OS}" = "Linux" ] ; then
  if [ -f /etc/debian_version ] ; then
    # use apt for Debian-based Linux
    apt-get update
    apt-get install -y autossh
  elif [ -f /etc/redhat-release ] ; then
    # use yum for Red Hat-based Linux
    yum install -y autossh
  fi
else
  echo "This operating system is not supported."
  exit 1
fi

