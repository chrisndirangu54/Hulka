import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]

class HulkaBoundaries(unittest.TestCase):
    def test_no_regen_in_runtime_integration(self):
        files = [
            ROOT / "functions/src/clinical_intelligence.ts",
            ROOT / "functions/src/clinical_domains.ts",
            ROOT / "functions/src/clinician_copilot.ts",
            ROOT / "functions/src/public_health_bulletins.ts",
            ROOT / "services/medical-model-adapter/app.py",
        ]
        for path in files:
            content=path.read_text().lower()
            self.assertNotIn("regeninsight", content, path.name)
            self.assertNotIn("regen_insight", content, path.name)
            self.assertNotIn("regen insight", content, path.name)
    def test_client_supplied_citations_not_trusted(self):
        content=(ROOT/"functions/src/clinician_copilot.ts").read_text()
        self.assertIn('collection("reviewedEvidence")', content)
        self.assertIn("sourceVerified !== true", content)
        self.assertIn("clinicalApproved !== true", content)
        self.assertNotIn("request.data?.evidence ?? []", content)
    def test_unvalidated_adapter_fails_closed(self):
        content=(ROOT/"services/medical-model-adapter/app.py").read_text()
        self.assertIn('raise HTTPException(503', content)
        self.assertNotIn("model.generate(", content)
if __name__ == "__main__":
    unittest.main()
