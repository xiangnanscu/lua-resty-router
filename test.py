#!/usr/bin/env python3
import requests
import sys
from typing import Optional, Union

# Set test server address
HOST = "http://localhost:8080"

# ANSI color codes
GREEN = '\033[0;32m'
RED = '\033[0;31m'
NC = '\033[0m'

# Add test statistics variables
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
    expected_substring: Optional[str] = None,
) -> None:
    """
    Test a single endpoint

    Args:
        url: Request path
        method: HTTP method
        expected_code: Expected status code
        expected_response: Expected response content. Can be:
            - string: for substring matching
            - dict/list: for complete JSON matching
        expected_substring: Expected substring in response content (optional)
        expected_content_type: Expected Content-Type (optional)
    """
    test_stats['total'] += 1
    print(f"Testing {method} {url}")

    try:
        response = requests.request(method, f"{HOST}{url}")
        code = response.status_code
        content_type = response.headers.get('content-type', '')

        # Check status code
        if code != expected_code:
            print(f"{RED}✗ Status code mismatch{NC}")
            print(f"Expected: {expected_code}")
            print(f"Got: {code}")
            test_stats['failed'] += 1
            print()
            return

        # Check Content-Type
        if expected_content_type is not None:
            if expected_content_type not in content_type:
                print(f"{RED}✗ Content-Type mismatch{NC}")
                print(f"Expected: {expected_content_type}")
                print(f"Got: {content_type}")
                test_stats['failed'] += 1
                print()
                return

        # If no expected response content, test passes
        if expected_response is None:
            print(f"{GREEN}✓ Test passed{NC}")
            test_stats['passed'] += 1
            print()
            return

        # Handle JSON response
        if 'application/json' in content_type:
            try:
                actual_json = response.json()
                if actual_json == expected_response:
                    print(f"{GREEN}✓ Test passed{NC}")
                    test_stats['passed'] += 1
                else:
                    print(f"{RED}✗ JSON response mismatch{NC}")
                    print(f"Expected: {expected_response}")
                    print(f"Got: {actual_json}")
                    test_stats['failed'] += 1
            except ValueError:
                print(f"{RED}✗ Response is not valid JSON{NC}")
                print(f"Got: {response.text}")
                test_stats['failed'] += 1
        # Handle text response
        else:
            actual_text = response.text
            if isinstance(expected_response, str):
                if expected_response == actual_text:
                    print(f"{GREEN}✓ Test passed{NC}")
                    test_stats['passed'] += 1
                else:
                    print(f"{RED}✗ Response content mismatch{NC}")
                    print(f"Expected: {repr(expected_response)}")
                    print(f"Got: {repr(actual_text)}")
                    test_stats['failed'] += 1
            else:
                print(f"{RED}✗ Response type mismatch{NC}")
                print(f"Expected JSON but got text: {actual_text}")
                test_stats['failed'] += 1

    except requests.RequestException as e:
        print(f"{RED}✗ Request failed: {e}{NC}")
        test_stats['failed'] += 1

    print()

def run_tests():
    """Run all test cases"""

    # 1. Test static path
    test_endpoint("/hello", expected_response="Hello World", expected_content_type="text/plain")
    test_endpoint("/hello-201", expected_code=201, expected_response="Hello World", expected_content_type="text/plain")

    # 2. Test JSON response
    test_endpoint("/json",
                 expected_response={"message": "success", "code": 0},
                 expected_content_type="application/json")

    # 3. Test dynamic path parameters
    test_endpoint("/users/123",
                 expected_response={"id": 123, "type": "number"},
                 expected_content_type="application/json")
    test_endpoint("/users/john",
                 expected_response={"name": "john", "type": "string"},
                 expected_content_type="application/json")

    # 4. Test regex path
    test_endpoint("/version/1.0",
                 expected_response={"version": "1.0"},
                 expected_content_type="application/json")
    test_endpoint("/version/abc",
                 expected_code=404,
                 expected_response="match route failed")

    # 5. Test wildcard
    test_endpoint("/files/path/to/file.txt",
                 expected_response="/path/to/file.txt")

    # 6. Test HTTP methods
    test_endpoint("/accounts",
                 method="POST",
                 expected_response={"method": "POST"},
                 expected_content_type="application/json")
    test_endpoint("/accounts/123",
                 method="PUT",
                 expected_response={"method": "PUT", "id": 123},
                 expected_content_type="application/json")
    test_endpoint("/accounts", method="DELETE", expected_code=405)

    # 7. Test error handling
    test_endpoint("/error",
                 expected_code=500,
                 expected_substring="Test Error")
    test_endpoint("/custom-error",
                 expected_code=500,
                 expected_response={"code": 400, "message": "Custom Error"},
                 expected_content_type="application/json")
    test_endpoint("/return-error",
                 expected_code=402,
                 expected_response="Parameter Error")
    test_endpoint("/handled-error",
                 expected_code=500,
                 expected_content_type="text/plain",
                 expected_response="handled error")

    # 8. Test status code
    test_endpoint("/404", expected_code=404, expected_response="Not Found")

    # 9. Test HTML response
    test_endpoint("/html",
                 expected_response="<h1>Hello HTML</h1>",
                 expected_content_type="text/html")
    test_endpoint("/html-error",
                 expected_code=501,
                 expected_content_type="text/html",
                 expected_response="<h1>Hello HTML error</h1>")

    # 10. Test function return
    test_endpoint("/func", expected_response="function called")

    # 11. Test events
    test_endpoint("/add", expected_response=1)
    test_endpoint("/events", expected_response=1)

    # 12. Test ctx.response.body
    test_endpoint("/response-body", expected_response="response body")

if __name__ == "__main__":
    try:
        run_tests()
        # Print test statistics
        print("Test Statistics:")
        print(f"Total: {test_stats['total']} tests")
        print(f"{GREEN}Passed: {test_stats['passed']}{NC}")
        if test_stats['failed'] > 0:
            print(f"{RED}Failed: {test_stats['failed']}{NC}")
        print(f"Pass rate: {(test_stats['passed'] / test_stats['total'] * 100):.1f}%")

        # Set exit code based on whether there were any failed tests
        sys.exit(1 if test_stats['failed'] > 0 else 0)
    except KeyboardInterrupt:
        print("\nTests interrupted")
        sys.exit(1)
