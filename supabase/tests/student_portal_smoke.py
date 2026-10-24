"""Local REST/Auth test for student invitations and row-level isolation."""

from __future__ import annotations

import sys
import traceback

from local_access_smoke import PASSWORD, expect_denied, local_configuration, request


def session(url: str, key: str, email: str) -> str:
    return request(url, key, "/auth/v1/token?grant_type=password",
                   body={"email": email, "password": PASSWORD})["access_token"]


def rpc(url: str, key: str, token: str, name: str, **params):
    return request(url, key, f"/rest/v1/rpc/{name}", token, body=params)


def main() -> int:
    url, key = local_configuration()
    ada = session(url, key, "ada.teacher@maestro.example")
    ben = session(url, key, "ben.teacher@maestro.example")
    aria = session(url, key, "aria.student@maestro.example")
    nora = session(url, key, "nora.student@maestro.example")
    student_id = 11

    # Disable any access left by a prior interrupted run.
    rpc(url, key, ada, "maestro_set_student_access",
        p_student_app_id=student_id, p_settings={"enabled": False})
    assert rpc(url, key, aria, "maestro_student_portal_data") == []
    assert request(url, key, "/rest/v1/students?select=app_id", aria) == []
    assert request(url, key, "/rest/v1/lessons?select=app_id", aria) == []
    assert request(url, key, "/rest/v1/payments?select=app_id", aria) == []
    expect_denied(url, key, "/rest/v1/rpc/maestro_invite_student", ben,
                  body={"p_student_app_id": student_id,
                        "p_email": "aria.student@maestro.example"})

    invitation = rpc(url, key, ada, "maestro_invite_student",
                     p_student_app_id=student_id,
                     p_email="aria.student@maestro.example")
    expect_denied(url, key, "/rest/v1/rpc/maestro_accept_student_invitation",
                  nora, body={"p_token": invitation["token"]})
    rpc(url, key, aria, "maestro_accept_student_invitation",
        p_token=invitation["token"])
    expect_denied(url, key, "/rest/v1/rpc/maestro_accept_student_invitation",
                  aria, body={"p_token": invitation["token"]})

    data = rpc(url, key, aria, "maestro_student_portal_data")
    assert len(data) == 1 and data[0]["studentAppId"] == student_id
    assert data[0]["courses"] and data[0]["payments"] == []
    assert data[0]["balance"] is None
    assert all(note["comment"] is None for note in data[0]["notes"])
    assert rpc(url, key, nora, "maestro_student_portal_data") == []
    assert request(url, key, "/rest/v1/payments?select=app_id", aria) == []
    expect_denied(url, key, "/rest/v1/rpc/maestro_set_student_access", aria,
                  body={"p_student_app_id": student_id,
                        "p_settings": {"viewPayments": True}})
    expect_denied(url, key, "/rest/v1/rpc/maestro_unlink_student_access", aria,
                  body={"p_student_app_id": student_id})
    expect_denied(url, key, "/rest/v1/rpc/maestro_set_piece_progress", aria,
                  body={"p_piece_app_id": 999999, "p_status": "COMPLETE",
                        "p_instructions": "", "p_instructions_shared": True})
    assert request(url, key, "/rest/v1/teacher_piece_progress?select=piece_id", aria) == []

    # A fresh verified invitation cannot silently replace an account already
    # linked to this teacher/student relationship.
    replacement = rpc(url, key, ada, "maestro_invite_student",
                      p_student_app_id=student_id,
                      p_email="nora.student@maestro.example")
    expect_denied(url, key, "/rest/v1/rpc/maestro_accept_student_invitation",
                  nora, body={"p_token": replacement["token"]})
    assert rpc(url, key, nora, "maestro_student_portal_data") == []
    rpc(url, key, ada, "maestro_revoke_student_invitation",
        p_invitation_id=replacement["invitationId"])

    rpc(url, key, ada, "maestro_set_student_access",
        p_student_app_id=student_id,
        p_settings={"viewNotes": True, "viewPayments": True})
    assert all(note["comment"] is None for note in
               rpc(url, key, aria, "maestro_student_portal_data")[0]["notes"])
    rpc(url, key, ada, "maestro_set_note_shared",
        p_note_app_id=301, p_shared=True)
    data = rpc(url, key, aria, "maestro_student_portal_data")[0]
    assert data["notes"][0]["comment"] == "Practice slowly"
    assert len(data["payments"]) == 1
    assert data["balance"] is None
    # Direct table reads remain denied even when the projection permits them.
    assert request(url, key, "/rest/v1/lesson_notes?select=app_id", aria) == []
    assert request(url, key, "/rest/v1/payments?select=app_id", aria) == []

    rpc(url, key, ada, "maestro_set_student_access",
        p_student_app_id=student_id, p_settings={"viewBalance": True})
    finance = rpc(url, key, aria, "maestro_student_portal_data")[0]
    assert float(finance["balance"]) == 0, finance["balance"]
    assert finance["courseCredits"] == 5, finance["courseCredits"]

    rpc(url, key, ada, "maestro_set_note_shared",
        p_note_app_id=301, p_shared=False)
    rpc(url, key, ada, "maestro_set_student_access",
        p_student_app_id=student_id, p_settings={"enabled": False})
    assert rpc(url, key, aria, "maestro_student_portal_data") == []
    rpc(url, key, ada, "maestro_unlink_student_access",
        p_student_app_id=student_id)
    assert rpc(url, key, aria, "maestro_student_portal_data") == []
    print("PASS student portal: invitation, account linking, permissions, note privacy, revocation, direct REST isolation")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        traceback.print_exc()
        print(f"Student portal smoke test failed: {error}", file=sys.stderr)
        sys.exit(1)
