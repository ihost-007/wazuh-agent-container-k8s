#!/bin/bash
############
# 
############
if [ -f "/application/package.json" ]; then
    cd /application
    npm start  
else
    wget https://github.com/juice-shop/juice-shop/releases/download/v17.1.1/juice-shop-17.1.1_node20_linux_x64.tgz
    tar -xzvf juice-shop-17.1.1_node20_linux_x64.tgz -C /application/ --strip-components=1
    cd /application
    npm install --omit=dev --ignore-scripts
    npm start    
fi
