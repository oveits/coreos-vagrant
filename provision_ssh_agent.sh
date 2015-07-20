#!/bin/bash

eval `ssh-agent -s`
chmod 600 .ssh/insecure_private_key
ssh-add .ssh/insecure_private_key

echo dshgiads > dshgiads

