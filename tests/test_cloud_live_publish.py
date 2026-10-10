"""Offline release checks: no Roblox credentials, network calls or live mutations."""
import importlib
import shutil
import subprocess
import tempfile
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

    def test_engine_container_preflight(self):
        root = Path(__file__).resolve().parents[1]
        runner = next((p for p in (
            root / ".tools/luau/luau", root / ".tools/luau/luau.exe"
        ) if p.is_file()), None)
        if runner is None:
            runner = shutil.which("luau")
        if runner is None:
            self.skipTest("Luau runner unavailable")
        harness = r'''local function node(kind, children)
 local n = {ClassName=kind, children=children or {}}
 function n:FindFirstChild(name) return self.children[name] end
 function n:IsA(class) return self.ClassName==class or (class=="LuaSourceContainer" and self.ClassName=="ModuleScript") end
 return n
end
local services = {
 ServerScriptService=node("ServerScriptService", {Server=node("Folder")}),
 ReplicatedStorage=node("ReplicatedStorage", {Shared=node("Folder")}),
 StarterPlayer=node("StarterPlayer", {StarterPlayerScripts=node(%CONTAINER%, {
  Client=node(%CLIENT%, {Example=node("ModuleScript")})
 })})
}
game = {GetService=function(_, name) return services[name] end}
'''
        preamble = cloud.PREAMBLE.replace("%SPECS%", '{ {path={"StarterPlayer","StarterPlayerScripts","Client","Example"},kind="ModuleScript"} }')
        for container, client, passed in (
            ("StarterPlayerScripts", "Folder", True),
            ("StarterPlayerScripts", "ModuleScript", True),
            ("Model", "Folder", False),
            ("StarterPlayerScripts", "Model", False),
            ("StarterPlayerScripts", "StarterPlayerScripts", False),
        ):
            with self.subTest(container=container, client=client):
                source = harness.replace("%CONTAINER%", repr(container)).replace("%CLIENT%", repr(client)) + preamble
                with tempfile.TemporaryDirectory() as directory:
                    file = Path(directory) / "preflight.luau"
                    file.write_text(source, encoding="utf-8")
                    result = subprocess.run([str(runner), str(file)], capture_output=True, text=True)
                self.assertEqual(result.returncode == 0, passed, result.stderr)
                if not passed:
                    self.assertIn("Non-code ancestor collision", result.stderr)

    def test_reject_oversized_release(self):
        with self.assertRaisesRegex(ValueError, "too large"):
            cloud.make_script([
                (("ReplicatedStorage", "Shared", "Sample"), "ModuleScript", "x"*3001000)
            ])


if __name__ == "__main__":
    unittest.main()
