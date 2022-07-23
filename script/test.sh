#!/usr/bin/env bash

curl -X POST -H "Accept: application/json" -H "Content-type: application/json"  -d '{
    "html": "<b>hello world <img src=\"https://www.placebear.com/400/300\"/></b>"
}' 'http://localhost:2305/1/pdf' --output test.pdf

curl -X POST -H "Accept: application/json" -H "Content-type: application/json"  -d '{
    "html": "PGI+aGVsbG8gd29ybGQgPGltZyBzcmM9Imh0dHBzOi8vd3d3LnBsYWNlYmVhci5jb20vNDAwLzMwMCIgLz48L2I+",
    "base64": true
}' 'http://localhost:2305/1/pdf' --output test_base64.pdf

curl -X POST -H "Accept: application/json" -H "Content-type: application/json"  -d '{
    "html": "<b>hello world <img src=\"https://www.placebear.com/400/300\"/></b>"
}' 'http://localhost:2305/1/screenshot' --output test.png