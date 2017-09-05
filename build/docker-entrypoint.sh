#!/bin/bash

#Start mongodb
numactl --interleave=all mongod

yarn install
yarn start

