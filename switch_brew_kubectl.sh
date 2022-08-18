#!/bin/bash -e

# Reference: https://gist.github.com/talal/1b8d0c11338dc9ab79b2386309828894
# Reference: https://github.com/Homebrew/homebrew-bundle/issues/1062

if [ $# -eq 0 ]; then
    echo "Usage: $0 [version of kubernetes-cli to install - e.g. '1.20.4_1']"
    kill -INT $$
fi

# show what is installed currently via brew
brew list

# this does not work any more...
#  brew install https://raw.githubusercontent.com/Homebrew/homebrew-core/d1f410dcd8426cf7ce1afb7614319c127d821ed8/Formula/kubernetes-cli.rb
# Note: look into this more: brew install kubectx && brew install asdf
#    See: https://faun.pub/switch-easily-between-multiple-kubernetes-version-on-macos-9d61b9bc8287

# show the path to the kubectl command currently executed by default
which kubectl

# see what version of kubernetes-cli is currently linked/installed
# Note: || true just ignores errors if the default server config can't connect or something like that.
kubectl version --short || true

# see what versions of kubernetes-cli _can_ be installed using brew
# Note: when this script was written only one previous version (1.22) was available as a Formula
# and it wasn't "previous enough" to fall within the +/- 1 version required by k8s for use with
# the cluster version (1.20)
brew search kubernetes-cli

pushd $(brew --repo homebrew/core)

echo "Target kubernetes-cli version number: $1"
# Assuming the only regex-special characters in the version number will be ".", just escape those using sed
VERSION_ARG_AS_REGEX=$(echo $1 | sed "s/\./\\\./g")
echo "VERSION_ARG_AS_REGEX: $VERSION_ARG_AS_REGEX"

# Extract the commit id matching the specified version from the git commit logs.
COMMIT_ID_FOR_VERSION=$(git --no-pager log --max-count=1 --grep="$VERSION_ARG_AS_REGEX bottle" Formula/kubernetes-cli.rb |grep ^commit | cut -d ' ' -f2)
echo "COMMIT_ID_FOR_VERSION: $COMMIT_ID_FOR_VERSION"

# In case this was already done for a different version of the tool... unpin it first.
brew unpin kubernetes-cli

# Switching versions requires a full delete/uninstall or the brew install command
# will skip over download/install and just say to brew link instead, which doesn't
# have the desired result of switching to a totally different binary.
# TODO: Find a combination of unlink, link, etc. that will avoid re-downloading.
brew uninstall --ignore-dependencies kubernetes-cli

git checkout -b kubernetes-cli-$1 $COMMIT_ID_FOR_VERSION

export HOMEBREW_NO_AUTO_UPDATE=1

brew install kubernetes-cli

unset HOMEBREW_NO_AUTO_UPDATE

# tell bash to clear its cache of executable files
# See: https://unix.stackexchange.com/questions/5609/how-do-i-clear-bashs-cache-of-paths-to-executables
# ATTENTION: This is something you might not know bash does, but it's worth being aware of it.
hash -r

brew pin kubernetes-cli

brew info kubernetes-cli

# verify that the new version of kubernetes-cli is linked/installed
kubectl version --short || true

# Restore brew's git local clone status to master branch so it functions normally for other stuff again
git checkout master
git branch -d kubernetes-cli-$1

# Clean up cached files related to installing the specific version of kubernetes-cli
brew cleanup kubernetes-cli

popd