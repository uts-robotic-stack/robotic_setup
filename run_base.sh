#!/bin/bash

if grep -q 'BCM' /proc/cpuinfo && grep -q 'Raspberry Pi' /sys/firmware/devicetree/base/model; then
    echo "This is a Raspberry Pi. Proceeding with the command."
    # Configure RPI Wifi access point
    # Prerequisites
    echo 'denyinterfaces wlan0' >> /etc/dhcpcd.conf
    cd rpi_wifi_ap/

    # Build docker image
    docker build . --tag rpi3-wifiap

    # Start the access point
    docker run -d --name "rpi3-wifiap" \
        --restart "always" \
        --tty \
        --privileged \
        --cap-add=NET_ADMIN \
        --network=host  \
        --volume "$(pwd)"/confs/hostapd_confs/robotics.conf:/etc/hostapd/hostapd.conf \
        --label=com.centurylinklabs.watchtower.enable=false \
        rpi3-wifiap
else
    echo "This is not a Raspberry Pi. Aborting the command."
fi

# Enable NetworkManager
sudo cp config/NetworkManager.conf /etc/NetworkManager/NetworkManager.conf
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager

docker volume create robotic_data
# Redis db server
docker run -d --name redis \
    -p 6379:6379 \
    -v robotic_data:/data \
    --restart unless-stopped \
    redis:latest

# Rosbridge server
docker run -d --name "rosbridge" \
    --tty \
    --privileged \
    --restart "always" \
    --network "host" \
    -e ROS_MASTER_URI="http://localhost:11311" \
    -e ROS_IP="192.168.27.1" \
    dkhoanguyen/robotic_base:latest \
    bash -c "source /opt/ros/noetic/setup.bash && source /ur_ws/devel/setup.bash && \
             roslaunch rosbridge_server rosbridge_websocket.launch"

# Supervisor
docker run -d --name "robotic_supervisor" \
    --tty \
    --privileged \
    --restart "always" \
    -e WATCHTOWER_CLEANUP=true \
    -e WATCHTOWER_INCLUDE_STOPPED=true \
    -e WATCHTOWER_INCLUDE_RESTARTING=true \
    -e WATCHTOWER_HTTP_API_TOKEN=robotics \
    -e WATCHTOWER_HTTP_API_PERIODIC_POLLS=true \
    -e DEVICE_NAME=robotic_default \
    -p 8080:8080 \
    -v /var/run/dbus/system_bus_socket:/var/run/dbus/system_bus_socket \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /proc:/proc \
    -v /dev:/dev \
    --label=com.centurylinklabs.watchtower.enable=false \
    dkhoanguyen/robotic_supervisor:latest --interval 300 --http-api-update --port 8080 --update-on-startup

# Dashboard
docker run -d \
    -p 80:80 \
    --restart "always" \
    --name robotic_dashboard \
    dkhoanguyen/robotic_dashboard:latest