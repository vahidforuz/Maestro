"""Exercise local Auth and REST as each seeded user; never contacts a remote URL."""

from __future__ import annotations

import base64
import json
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PASSWORD = "LocalMaestro123!"
EXPECTED = {
    "ada.teacher@maestro.example": ({11, 12, 15}, {201}),
    "ben.teacher@maestro.example": ({13, 14, 15}, {202}),
    "aria.student@maestro.example": (set(), set()),
    "nora.student@maestro.example": (set(), set()),
    "pat.parent@maestro.example": ({11, 12}, {201}),
    "ren.parent@maestro.example": ({13, 14}, set()),
}


def local_configuration() -> tuple[str, str]:
    result = subprocess.run(
        ["npx", "--yes", "supabase", "status", "-o", "env"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=True,
    )
    values = dict(
        line.split("=", 1)
        for line in result.stdout.splitlines()
        if "=" in line and not line.startswith("#")
    )
    url = values["API_URL"].strip('"')
    key = values["PUBLISHABLE_KEY"].strip('"')
    parsed = urllib.parse.urlparse(url)
    if parsed.hostname not in {"localhost", "127.0.0.1"} or parsed.port != 54321:
        raise RuntimeError("Refusing to test anything except local Supabase on port 54321")
    return url, key


def request(url: str, key: str, path: str, token: str | None = None,
            body: dict | None = None, raw: bytes | None = None,
            method: str | None = None) -> object:
    headers = {"apikey": key}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    data = None
    if body is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(body).encode()
    if raw is not None:
        headers["Content-Type"] = "image/png"
        data = raw
    req = urllib.request.Request(url + path, headers=headers, data=data,
                                 method=method)
    try:
        with urllib.request.urlopen(req, timeout=15) as response:
            payload = response.read()
            if response.headers.get_content_type() == "application/json":
                return json.loads(payload)
            return payload
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors="replace")[:500]
        raise RuntimeError(f"{path}: HTTP {error.code}: {detail}") from error


def expect_denied(url: str, key: str, path: str, token: str,
                  body: dict | None = None,
                  allowed_statuses: tuple[int, ...] | None = None) -> None:
    try:
        request(url, key, path, token, body=body)
    except RuntimeError as error:
        statuses = allowed_statuses or tuple(range(400, 500))
        if any(f"HTTP {status}:" in str(error) for status in statuses):
            return
        raise
    raise AssertionError(f"Unexpected access to {path}")


def main() -> int:
    url, key = local_configuration()
    tokens = {}
    for email, (expected_students, expected_payments) in EXPECTED.items():
        session = request(url, key, "/auth/v1/token?grant_type=password",
                          body={"email": email, "password": PASSWORD})
        token = session["access_token"]
        tokens[email] = token
        students = request(url, key,
                           "/rest/v1/students?select=app_id,name&order=app_id", token)
        payments = request(url, key,
                           "/rest/v1/payments?select=app_id&order=app_id", token)
        actual_students = {row["app_id"] for row in students}
        actual_payments = {row["app_id"] for row in payments}
        if (actual_students, actual_payments) != (expected_students, expected_payments):
            raise AssertionError(
                f"{email}: students={sorted(actual_students)}, "
                f"payments={sorted(actual_payments)}"
            )
        print(f"PASS {email}: {len(students)} students, {len(payments)} payments")
    finance_path = "/rest/v1/rpc/get_student_finances"
    aria_id = "30000000-0000-0000-0000-000000000011"
    nora_id = "30000000-0000-0000-0000-000000000013"
    for email in ("ada.teacher@maestro.example", "pat.parent@maestro.example"):
        values = request(url, key, finance_path, tokens[email],
                         body={"p_student_id": aria_id})
        if float(values["coursePrice"]) != 20:
            raise AssertionError(f"{email} received wrong finance values")
    expect_denied(url, key, finance_path, tokens["ben.teacher@maestro.example"],
                  body={"p_student_id": aria_id})
    expect_denied(url, key, finance_path, tokens["aria.student@maestro.example"],
                  body={"p_student_id": aria_id})
    expect_denied(url, key, finance_path, tokens["ren.parent@maestro.example"],
                  body={"p_student_id": nora_id})
    expect_denied(url, key, "/rest/v1/students?select=app_id,course_price",
                  tokens["ren.parent@maestro.example"])
    expect_denied(url, key, "/rest/v1/projects?select=paid_course_count",
                  tokens["ren.parent@maestro.example"])
    print("PASS finance access: authorized RPC only; private columns hidden")
    for email in ("aria.student@maestro.example", "pat.parent@maestro.example"):
        expect_denied(url, key, "/rest/v1/rpc/register_teacher", tokens[email],
                      body={"p_first_name": "Wrong", "p_last_name": "Role"},
                      allowed_statuses=(403,))
        role = "student" if email.startswith("aria") else "parent"
        if request(url, key, "/rest/v1/profiles?select=role", tokens[email]) != [
                {"role": role}]:
            raise AssertionError(f"{email} changed role after denied registration")
    print("PASS existing student and parent roles cannot register as teachers")
    # A real private Storage upload checks the same relationship boundaries.
    student_id = "30000000-0000-0000-0000-000000000011"
    teacher_uid = "10000000-0000-0000-0000-000000000001"
    object_path = f"{student_id}/{teacher_uid}/{uuid.uuid4()}.png"
    storage_path = f"/storage/v1/object/maestro-private/{object_path}"
    image = base64.b64decode(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/"
        "mS8AAAAASUVORK5CYII="
    )
    ada = tokens["ada.teacher@maestro.example"]
    request(url, key, storage_path, ada, raw=image, method="POST")
    try:
        read_path = f"/storage/v1/object/authenticated/maestro-private/{object_path}"
        for email in ("ada.teacher@maestro.example", "pat.parent@maestro.example"):
            if request(url, key, read_path, tokens[email]) != image:
                raise AssertionError(f"{email} could not read authorized media")
        for email in ("ben.teacher@maestro.example", "aria.student@maestro.example",
                      "nora.student@maestro.example", "ren.parent@maestro.example"):
            expect_denied(url, key, read_path, tokens[email])
        print("PASS private Storage: authorized readers only")
    finally:
        request(url, key, storage_path, ada, method="DELETE")
    print("All local Auth, REST, and Storage isolation checks passed.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (subprocess.CalledProcessError, urllib.error.URLError, KeyError,
            AssertionError, RuntimeError) as error:
        print(f"Local access test failed: {error}", file=sys.stderr)
        sys.exit(1)
