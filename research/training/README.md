# Hulka-managed research training

Offline binary-classification baseline for **approved de-identified tabular data** only. No blockchain or federated training. This script does not connect to Firebase or deploy models.

Install packages in an isolated environment with `pip install -r requirements.txt`. Provide a governance JSON manifest with boolean `approved`, `deidentified`, `lawful_basis_confirmed`, and `license_checked` plus `approval_reference`. Example: `python train_baseline.py --input approved.csv --target outcome --group hospital_region --approval-file approved_manifest.json --output artifacts`.

Group-held-out evaluation is preferred over random splitting for institution/geography transfer testing. Review class imbalance, confounding, calibration, fairness, dataset leakage, independent external validation and regulatory requirements before any patient-facing use. The generated joblib model must never be loaded from untrusted sources and is **not** released to production automatically.
