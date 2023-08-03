#!/bin/bash

# Start the robot
docker run -d --name "hans_controller" \
    --tty \
    --privileged \
    --restart "always" \
    --network "host" \
    --mount type=bind,source=/dev/,target=/dev/ \
    robotic_base:latest \
    bash -c "source /opt/ros/noetic/setup.bash && source /hans_ws/devel/setup.bash && \
             sleep 15 && \
             roslaunch hans_cute_bringup hans_cute_bringup.launch"