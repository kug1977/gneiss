#!/bin/sh

apt-get update
apt-get install -y expect python3 python3-pip

cd /gneiss
git submodule update --init --recursive
pip3 install -e tool/RecordFlux
make -C ada-runtime

set -e

./cement build test/message_client/message_client.xml . lib test
./cement build test/hello_world/hello_world.xml . lib test
./cement build test/log_proxy/log_proxy.xml . lib test
./cement build test/rom/rom.xml . lib test
./cement build test/memory_client/memory_client.xml . lib test
./cement build test/timer/timer.xml . lib test

export LD_LIBRARY_PATH=build/lib
expect test/message_client/message_client.expect
expect test/hello_world/hello_world.expect
expect test/log_proxy/log_proxy.expect
expect test/rom/rom.expect
expect test/memory_client/memory_client.expect
expect test/timer/timer.expect
