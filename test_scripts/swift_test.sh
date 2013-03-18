#!/bin/bash
#
# script to build a two node environment and test.
#

echo "testing pull request ${pull_request} from repo: swift"

set -e
build_dir="$WORKSPACE/$BUILD_ID"
mkdir -p $build_dir
cd $build_dir
git clone git://github.com/puppetlabs/puppetlabs-openstack_dev_env
cd $build_dir/puppetlabs-openstack_dev_env
echo $build_dir/puppetlabs-openstack_dev_env

# use operatingsystem matrix param to set the os to use for testing
echo "operatingsystem: ${operatingsystem}" > config.yaml

# I really want to get this password out of here
# but this user doesnt do anything, its just to get around being rate limited by github
# I really want jenkins to do all of the parts that require auth...
echo 'password: Pupp3tR0cks' > .github_auth
echo 'login: puppet-openstack-ci-user' >> .github_auth
echo 'admins: bodepd' >> .github_auth

git config --global user.name puppet-openstack-ci-user
git config --global user.email puppet.openstack.ci@gmail.com

mkdir .vendor
export GEM_HOME=`pwd`/.vendor
# install gem dependencies
bundle install
# install required modules
git clone https://github.com/applicationsonline/librarian
export RUBYLIB=librarian/lib

bundle exec librarian-puppet install

# retrieve the pull request

bundle exec rake github:checkout_pull_request[swift,$pull_request] --trace

# install a controller and compute instance
for i in puppetmaster swift_storage_1 swift_storage_2 swift_storage_3 swift_proxy swift_keystone; do
  
  # cleanup running swift instances
  if VBoxManage list vms | grep ${i}.puppetlabs.lan; then
    VBoxManage controlvm ${i}.puppetlabs.lan  poweroff || true
    VBoxManage unregistervm ${i}.puppetlabs.lan  --delete
  fi

done

# build out a puppetmaster
bundle exec vagrant up puppetmaster

# deploy swift
bundle exec rake openstack:deploy_swift

# run basic swift tests
bundle exec vagrant ssh -c 'sudo ruby /tmp/swift_test_file.rb;exit $?' swift_proxy
