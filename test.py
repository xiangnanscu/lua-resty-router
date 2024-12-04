#!/usr/bin/env python3
import requests
import sys
from typing import Optional, Union

# 设置测试服务器地址
HOST = "http://localhost:8080"

# ANSI颜色代码
GREEN = '\033[0;32m'
RED = '\033[0;31m'
NC = '\033[0m'

# 添加测试统计变量
test_stats = {
    'total': 0,
    'passed': 0,
    'failed': 0
}

def test_endpoint(
    url: str,
    *,
    method: str = "GET",
    expected_code: int = 200,
    expected_response: Optional[Union[str, dict, list]] = None,
    expected_content_type: Optional[str] = None,
) -> None:
    """
    测试单个端点

    Args:
        url: 请求路径
        method: HTTP方法
        expected_code: 预期状态码
        expected_response: 预期的响应内容。可以是:
            - 字符串: 进行子串匹配
            - 字典/列表: 进行JSON完整匹配
        expected_content_type: 预期的Content-Type (可选)
    """
    test_stats['total'] += 1
    print(f"Testing {method} {url}")

    try:
        response = requests.request(method, f"{HOST}{url}")
        code = response.status_code
        content_type = response.headers.get('content-type', '')

        # 检查状态码
        if code != expected_code:
            print(f"{RED}✗ 状态码不匹配{NC}")
            print(f"Expected: {expected_code}")
            print(f"Got: {code}")
            test_stats['failed'] += 1
            print()
            return

        # 检查Content-Type
        if expected_content_type is not None:
            if expected_content_type not in content_type:
                print(f"{RED}✗ Content-Type不匹配{NC}")
                print(f"Expected: {expected_content_type}")
                print(f"Got: {content_type}")
                test_stats['failed'] += 1
                print()
                return

        # 如果没有期望的响应内容，则测试通过
        if expected_response is None:
            print(f"{GREEN}✓ 测试通过{NC}")
            test_stats['passed'] += 1
            print()
            return

        # 处理JSON响应
        if 'application/json' in content_type:
            try:
                actual_json = response.json()
                if actual_json == expected_response:
                    print(f"{GREEN}✓ 测试通过{NC}")
                    test_stats['passed'] += 1
                else:
                    print(f"{RED}✗ JSON响应不匹配{NC}")
                    print(f"Expected: {expected_response}")
                    print(f"Got: {actual_json}")
                    test_stats['failed'] += 1
            except ValueError:
                print(f"{RED}✗ 响应不是有效的JSON{NC}")
                print(f"Got: {response.text}")
                test_stats['failed'] += 1
        # 处理文本响应
        else:
            actual_text = response.text
            if isinstance(expected_response, str):
                if expected_response in actual_text:
                    print(f"{GREEN}✓ 测试通过{NC}")
                    test_stats['passed'] += 1
                else:
                    print(f"{RED}✗ 响应内容不匹配{NC}")
                    print(f"Expected: {expected_response}")
                    print(f"Got: {actual_text}")
                    test_stats['failed'] += 1
            else:
                print(f"{RED}✗ 响应类型不匹配{NC}")
                print(f"Expected JSON but got text: {actual_text}")
                test_stats['failed'] += 1

    except requests.RequestException as e:
        print(f"{RED}✗ 请求失败: {e}{NC}")
        test_stats['failed'] += 1

    print()

def run_tests():
    """运行所有测试用例"""

    # 1. 测试静态路径
    test_endpoint("/hello", expected_response="Hello World", expected_content_type="text/plain")
    test_endpoint("/hello-201", expected_code=201, expected_response="Hello World", expected_content_type="text/plain")

    # 2. 测试JSON响应
    test_endpoint("/json",
                 expected_response={"message": "success", "code": 0},
                 expected_content_type="application/json")

    # 3. 测试动态路径参数
    test_endpoint("/users/123",
                 expected_response={"id": 123, "type": "number"},
                 expected_content_type="application/json")
    test_endpoint("/users/john",
                 expected_response={"name": "john", "type": "string"},
                 expected_content_type="application/json")

    # 4. 测试正则路径
    test_endpoint("/version/1.0",
                 expected_response={"version": "1.0"},
                 expected_content_type="application/json")
    test_endpoint("/version/abc",
                 expected_code=404,
                 expected_response="match route failed")

    # 5. 测试通配符
    test_endpoint("/files/path/to/file.txt",
                 expected_response="/path/to/file.txt")

    # 6. 测试HTTP方法
    test_endpoint("/accounts",
                 method="POST",
                 expected_response={"method": "POST"},
                 expected_content_type="application/json")
    test_endpoint("/accounts/123",
                 method="PUT",
                 expected_response={"method": "PUT", "id": 123},
                 expected_content_type="application/json")
    test_endpoint("/accounts", method="DELETE", expected_code=405)

    # 7. 测试错误处理
    test_endpoint("/error",
                 expected_code=500,
                 expected_response="测试错误")
    test_endpoint("/custom-error",
                 expected_code=500,
                 expected_response={"code": 400, "message": "自定义错误"},
                 expected_content_type="application/json")
    test_endpoint("/return-error",
                 expected_code=402,
                 expected_response="参数错误")
    test_endpoint("/handled-error",
                 expected_code=500,
                 expected_content_type="text/plain",
                 expected_response="handled error")

    # 8. 测试状态码
    test_endpoint("/404", expected_code=404, expected_response="Not Found")

    # 9. 测试HTML响应
    test_endpoint("/html",
                 expected_response="<h1>Hello HTML</h1>",
                 expected_content_type="text/html")
    test_endpoint("/html-error",
                 expected_code=501,
                 expected_content_type="text/html",
                 expected_response="<h1>Hello HTML error</h1>")

    # 10. 测试函数返回
    test_endpoint("/func", expected_response="function called")

    # 11. 测试events
    test_endpoint("/events", expected_response={"success_cnt": 11, "error_cnt": 8})

if __name__ == "__main__":
    try:
        run_tests()
        # 添加测试统计信息的输出
        print("测试统计:")
        print(f"总计: {test_stats['total']} 个测试")
        print(f"{GREEN}通过: {test_stats['passed']} 个{NC}")
        if test_stats['failed'] > 0:
            print(f"{RED}失败: {test_stats['failed']} 个{NC}")
        print(f"通过率: {(test_stats['passed'] / test_stats['total'] * 100):.1f}%")

        # 根据是否有失败的测试来设置退出码
        sys.exit(1 if test_stats['failed'] > 0 else 0)
    except KeyboardInterrupt:
        print("\n测试被中断")
        sys.exit(1)
