#!/bin/sh
sed -i 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T//' $1
sed -i '/\*\*\*/d' $1