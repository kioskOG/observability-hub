#!/bin/bash

asg_names=$(aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[? Tags[? (Key=='eks:cluster-name') && Value=='solanteq-dev']]".AutoScalingGroupName)

list_asg() {
    echo "$asg_names" | sed "s/\[//; s/]//; s/','/,/g; s/, /\n/g" > /tmp/asg.txt
    cat /tmp/asg.txt | tr -d "[:space:]" | tr ',' '\n' | tr -d '"' > /tmp/asg-2.txt
    echo >> /tmp/asg-2.txt
}

attach_sns() {
    while read -r line;
    do
        aws autoscaling put-notification-configuration --auto-scaling-group-name $line --topic-arn $topic_arn --notification-types "autoscaling:EC2_INSTANCE_LAUNCH_ERROR"
    done < /tmp/asg-2.txt
}

list_asg
attach_sns