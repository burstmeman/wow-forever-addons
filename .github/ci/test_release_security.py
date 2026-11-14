"""Keep deployment credentials isolated from builds and untrusted shell inputs."""
from pathlib import Path
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[2]


class ReleaseWorkflowSecurityTests(unittest.TestCase):
    def test_release_workflow_security_boundaries(self):
        for name in ("release.yml", "next-release.yml"):
            workflow = yaml.load((ROOT / ".github/workflows" / name).read_text(encoding="utf-8"), Loader=yaml.BaseLoader)
            with self.subTest(workflow=name):
                self.assertEqual(workflow["permissions"], {"contents": "read"})
                self.assertNotIn("pull_request_target", workflow["on"])
                for job in workflow["jobs"].values():
                    self.assertNotIn("secrets.", str(job.get("env", {})))
                    self.assertNotIn("secrets.", str(workflow.get("env", {})))
                    for step in job["steps"]:
                        if "uses" in step:
                            self.assertRegex(step["uses"], r"^[\w-]+/[\w-]+@[0-9a-f]{40}$")
                        if step.get("uses", "").startswith("actions/checkout@"):
                            self.assertEqual(step["with"]["persist-credentials"], "false")
                        self.assertNotRegex(step.get("run", ""), r"\$\{\{\s*(?:inputs\.|github\.event\.|secrets\.)")
                        if "secrets." in str(step):
                            self.assertEqual(name, "release.yml")
                            self.assertEqual(step["run"], "python .github/ci/release.py publish")
                if name == "release.yml":
                    self.assertEqual(workflow["jobs"]["build"].get("permissions", workflow["permissions"]), {"contents": "read"})
                    self.assertNotIn("secrets.", str(workflow["jobs"]["build"]))
                    self.assertNotIn("github.token", str(workflow["jobs"]["build"]))
                    self.assertIn("github.ref == 'refs/heads/main'", workflow["jobs"]["publish"]["if"])
                for job_id, job in workflow["jobs"].items():
                    if name == "release.yml" and job_id == "build":
                        continue
                    installers = [step["run"] for step in job["steps"] if "pip install" in step.get("run", "")]
                    self.assertTrue(installers)
                    for command in installers:
                        self.assertIn("--require-hashes", command)
                        self.assertIn("--only-binary=:all:", command)
                        self.assertIn("deployment-requirements.txt", command)
