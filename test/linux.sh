#!/bin/sh

apt-get update
apt-get install -y expect python3 python3-pip

cd /gneiss
git submodule update --init --recursive
pip3 install -e tool/RecordFlux

set -e

./cement prove test/message_client.gpr . lib test -u message_client-component
./cement prove test/message_server.gpr . lib test -u message_server-component
./cement prove test/hello_world.gpr . lib test -u hello_world-component
./cement prove test/log_proxy.gpr . lib test -u log_proxy-component
./cement prove test/rom.gpr . lib test -u rom-component
./cement prove test/memory_client.gpr . lib test -u memory_client-component
./cement prove test/memory_server.gpr . lib test -u memory_server-component
./cement prove test/timer.gpr . lib test -u timer-component
./cement prove test/packet_client.gpr . lib test -u packet_client-component
./cement prove test/packet_server.gpr . lib test -u packet_server-component
./cement prove test/stream_client.gpr . lib test -u stream_client-component
./cement prove test/stream_server.gpr . lib test -u stream_server-component

./cement build test/message_client/message_client.xml . lib test
./cement build test/hello_world/hello_world.xml . lib test
./cement build test/log_proxy/log_proxy.xml . lib test
./cement build test/rom/rom.xml . lib test
./cement build test/memory_client/memory_client.xml . lib test
./cement build test/timer/timer.xml . lib test
./cement build test/packet_client/packet_client.xml . lib test
./cement build test/stream_client/stream_client.xml . lib test

export LD_LIBRARY_PATH=build/lib
expect test/message_client/message_client.expect
expect test/hello_world/hello_world.expect
expect test/log_proxy/log_proxy.expect
expect test/rom/rom.expect
expect test/memory_client/memory_client.expect
expect test/timer/timer.expect
expect test/packet_client/packet_client.expect
expect test/stream_client/stream_client.expect
