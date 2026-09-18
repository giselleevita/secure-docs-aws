"""Offline security-boundary tests for the Lambda handlers.

These tests replace AWS SDK calls with in-memory fakes. They prove the handlers
take identity only from the validated JWT claim and deny a different user's
download or delete request without requiring an AWS account.
"""

from __future__ import annotations

import importlib.util
import json
import os
import sys
import types
import unittest
from pathlib import Path


APP_DIR = Path(__file__).resolve().parents[1] / "app"


class FakeTable:
    def __init__(self, item: dict | None = None, items: list[dict] | None = None):
        self.item = item
        self.items = items or []
        self.put_items: list[dict] = []
        self.deleted: list[dict] = []

    def put_item(self, *, Item: dict) -> None:
        self.put_items.append(Item)

    def get_item(self, *, Key: dict) -> dict:
        return {"Item": self.item} if self.item else {}

    def query(self, **_kwargs: object) -> dict:
        return {"Items": self.items}

    def delete_item(self, *, Key: dict) -> None:
        self.deleted.append(Key)


class FakeDynamoResource:
    def __init__(self, table: FakeTable):
        self.table = table

    def Table(self, _name: str) -> FakeTable:
        return self.table


class FakeS3:
    def __init__(self):
        self.presign_calls: list[tuple[str, dict, int]] = []
        self.delete_calls: list[dict] = []

    def generate_presigned_url(self, operation: str, *, Params: dict, ExpiresIn: int) -> str:
        self.presign_calls.append((operation, Params, ExpiresIn))
        return "https://example.invalid/presigned"

    def list_object_versions(self, **_kwargs: object) -> dict:
        return {}

    def delete_objects(self, **kwargs: object) -> None:
        self.delete_calls.append(kwargs)


class LambdaSecurityTests(unittest.TestCase):
    def setUp(self) -> None:
        os.environ.update(
            {"BUCKET_NAME": "test-bucket", "TABLE_NAME": "test-table", "KMS_KEY_ARN": "test-key"}
        )

    def load_handler(self, filename: str, table: FakeTable) -> tuple[types.ModuleType, FakeS3]:
        s3 = FakeS3()
        boto3 = types.ModuleType("boto3")
        boto3.client = lambda _service: s3
        boto3.resource = lambda _service: FakeDynamoResource(table)
        conditions = types.ModuleType("boto3.dynamodb.conditions")
        conditions.Key = lambda name: types.SimpleNamespace(eq=lambda value: (name, value))
        dynamodb = types.ModuleType("boto3.dynamodb")
        modules = {"boto3": boto3, "boto3.dynamodb": dynamodb, "boto3.dynamodb.conditions": conditions}
        previous = {name: sys.modules.get(name) for name in modules}
        sys.modules.update(modules)
        try:
            module_name = f"secure_docs_{filename}_{id(table)}"
            spec = importlib.util.spec_from_file_location(module_name, APP_DIR / filename)
            assert spec and spec.loader
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            return module, s3
        finally:
            for name, original in previous.items():
                if original is None:
                    sys.modules.pop(name, None)
                else:
                    sys.modules[name] = original

    @staticmethod
    def event(owner_id: str | None, *, body: dict | None = None, file_id: str | None = None) -> dict:
        event: dict = {"requestContext": {"authorizer": {"jwt": {"claims": {}}}}}
        if owner_id:
            event["requestContext"]["authorizer"]["jwt"]["claims"]["sub"] = owner_id
        if body is not None:
            event["body"] = json.dumps(body)
        if file_id is not None:
            event["pathParameters"] = {"id": file_id}
        return event

    def test_upload_uses_jwt_subject_not_client_owner_id(self) -> None:
        table = FakeTable()
        handler, s3 = self.load_handler("lambda_function__upload_presigned.py", table)

        response = handler.handler(self.event("user-a", body={"file_name": "report.pdf", "owner_id": "user-b"}), None)

        self.assertEqual(200, response["statusCode"])
        self.assertEqual("user-a", table.put_items[0]["owner_id"])
        self.assertEqual(1, len(s3.presign_calls))
        self.assertEqual(300, s3.presign_calls[0][2])

    def test_download_denies_cross_user_without_s3_access(self) -> None:
        table = FakeTable()
        handler, s3 = self.load_handler("lambda_function__download_file.py", table)

        response = handler.handler(self.event("user-b", file_id="user-a-file"), None)

        self.assertEqual(403, response["statusCode"])
        self.assertEqual([], s3.presign_calls)

    def test_delete_denies_cross_user_without_s3_or_database_mutation(self) -> None:
        table = FakeTable()
        handler, s3 = self.load_handler("lambda_function__delete_file.py", table)

        response = handler.handler(self.event("user-b", file_id="user-a-file"), None)

        self.assertEqual(403, response["statusCode"])
        self.assertEqual([], s3.delete_calls)
        self.assertEqual([], table.deleted)

    def test_list_hides_owner_identifier(self) -> None:
        table = FakeTable(items=[{"owner_id": "user-a", "object_key": "file-1", "file_name": "report.pdf"}])
        handler, _s3 = self.load_handler("lambda_function__list_files.py", table)

        response = handler.handler(self.event("user-a"), None)

        self.assertEqual(200, response["statusCode"])
        self.assertEqual({"files": [{"file_id": "file-1", "file_name": "report.pdf"}]}, json.loads(response["body"]))


if __name__ == "__main__":
    unittest.main()
