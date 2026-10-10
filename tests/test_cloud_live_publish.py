"""Offline release checks: no Roblox credentials, network calls or live mutations."""
import importlib
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
cloud = importlib.import_module("roblox_live_publish")


class CloudPublishSafetyTests(unittest.TestCase):
    def test_only_script_roots(self):
        with patch.object(cloud, "discover", return_value={
            ("Workspace", "Danger"): (Path(__file__), "ModuleScript")
        }):
            with self.assertRaisesRegex(ValueError, "outside approved"):
                cloud.spec_list()

    def test_safe_task_and_live_publish(self):
        source = "-- plain script\\nreturn {success=true}"
        script = cloud.make_script([
            (("ReplicatedStorage", "Shared", "Sample"), "ModuleScript", source)
        ])
        self.assertIn("SavePlaceAsync({ SaveWithoutPublish = false })", script)
        self.assertIn("Managed Studio root is missing", script)
        self.assertIn("Script class mismatch", script)
        self.assertNotIn("Destroy()", script)
        self.assertNotIn("versionType=Published", script)

    def test_post_publish_source_verification(self):
        script = cloud.make_script([
            (("ServerScriptService", "Server", "Sample"), "ModuleScript", "return 3")
        ], verify=True)
        self.assertIn("LIVE PUBLISH verification failed", script)
        self.assertNotIn("SavePlaceAsync", script)

    def test_reject_oversized_release(self):
        with self.assertRaisesRegex(ValueError, "too large"):
            cloud.make_script([
                (("ReplicatedStorage", "Shared", "Sample"), "ModuleScript", "x"*3001000)
            ])


if __name__ == "__main__":
    unittest.main()
