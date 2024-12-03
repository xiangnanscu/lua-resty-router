#!/bin/bash

# 设置测试服务器地址
HOST="http://localhost:8080"

# 用不同的颜色输出测试结果
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# 测试函数
test_endpoint() {
    local url=$1
    local method=${2:-GET}
    local expected_code=${3:-200}
    local expected_body=$4

    echo "Testing $method $url"

    response=$(curl -s -w "\n%{http_code}" -X $method $HOST$url)
    body=$(echo "$response" | head -n 1)
    code=$(echo "$response" | tail -n 1)

    if [ "$code" = "$expected_code" ]; then
        if [ -z "$expected_body" ] || echo "$body" | grep -q "$expected_body"; then
            echo -e "${GREEN}✓ 测试通过${NC}"
        else
            echo -e "${RED}✗ 响应内容不匹配${NC}"
            echo "Expected: $expected_body"
            echo "Got: $body"
        fi
    else
        echo -e "${RED}✗ 状态码不匹配${NC}"
        echo "Expected: $expected_code"
        echo "Got: $code"
    fi
    echo
}

# 1. 测试静态路径
test_endpoint "/hello" "GET" 200 "Hello World"

# 2. 测试JSON响应
test_endpoint "/json" "GET" 200 '"message":"success"'

# 3. 测试动态路径参数
test_endpoint "/users/123" "GET" 200 '"id":123'
test_endpoint "/users/john" "GET" 200 '"name":"john"'

# 4. 测试正则路径
test_endpoint "/version/1.0" "GET" 200 '"version":"1.0"'
test_endpoint "/version/abc" "GET" 404

# 5. 测试通配符
test_endpoint "/files/path/to/file.txt" "GET" 200 '"path":"path/to/file.txt"'

# 6. 测试HTTP方法
test_endpoint "/users" "POST" 200 '"method":"POST"'
test_endpoint "/users/123" "PUT" 200 '"method":"PUT"'
test_endpoint "/users" "DELETE" 405

# 7. 测试错误处理
test_endpoint "/error" "GET" 500 "测试错误"

# 8. 测试状态码
test_endpoint "/404" "GET" 404 "Not Found"

# 9. 测试HTML响应
test_endpoint "/html" "GET" 200 "<h1>Hello HTML</h1>"

# 10. 测试函数返回
test_endpoint "/func" "GET" 200 "function called"

echo "所有测试完成!"
