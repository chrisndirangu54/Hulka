#!/usr/bin/env python3
"""Hulka-owned offline classifier baseline. Research use only; NOT clinical deployment.

Input: approved, de-identified CSV with target column and optional group column.
No patient IDs, personal data, network calls, tracking, or automatic model deployment.
Requires scikit-learn/pandas/joblib from requirements.txt.
"""
import argparse
import json
import re
from pathlib import Path

import joblib
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import classification_report, confusion_matrix, roc_auc_score
from sklearn.model_selection import GroupShuffleSplit, train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler

FORBIDDEN = re.compile(
    r"(^|_)(name|email|phone|address|dob|birth|national|passport|nhif|patient|"
    r"person|user|device|medical_record|identifier|uid|id)(_|$)", re.I
)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--target", required=True)
    parser.add_argument("--group", help="Institution or geography for held-out groups")
    parser.add_argument("--approval-file", required=True,
                        help="Signed/approved governance manifest JSON")
    args = parser.parse_args()
    approval = json.loads(Path(args.approval_file).read_text())
    requirements = ("approved", "deidentified", "lawful_basis_confirmed", "license_checked")
    if any(approval.get(k) is not True for k in requirements):
        raise ValueError("Governance manifest missing required approvals")
    df = pd.read_csv(args.input)
    if len(df) < 100:
        raise ValueError("Minimum 100 de-identified rows required for baseline")
    if args.target not in df or (args.group and args.group not in df):
        raise ValueError("Invalid target or group")
    if df.columns.duplicated().any():
        raise ValueError("Duplicate column names")
    excluded = {args.target} | ({args.group} if args.group else set())
    feature_cols = [c for c in df.columns if c not in excluded]
    if not feature_cols or any(FORBIDDEN.search(c) for c in feature_cols):
        raise ValueError("Potentially identifying or missing predictor columns")
    if df[args.target].nunique() != 2:
        raise ValueError("Binary outcome only for initial baseline")
    x, y = df[feature_cols], df[args.target]
    if args.group:
        split = GroupShuffleSplit(test_size=0.2, n_splits=1, random_state=42)
        tr, te = next(split.split(x, y, groups=df[args.group]))
    else:
        tr, te = train_test_split(range(len(df)), test_size=0.2,
                                  random_state=42, stratify=y)
    numeric = x.select_dtypes(include="number").columns.tolist()
    categorical = [c for c in x.columns if c not in numeric]
    preprocessing = ColumnTransformer([
        ("num", Pipeline([("impute", SimpleImputer(strategy="median")),
                          ("scale", StandardScaler())]), numeric),
        ("cat", Pipeline([("impute", SimpleImputer(strategy="most_frequent")),
                          ("onehot", OneHotEncoder(handle_unknown="ignore"))]), categorical)
    ])
    model = Pipeline([("preprocess", preprocessing),
                      ("classifier", LogisticRegression(max_iter=1000, class_weight="balanced"))])
    model.fit(x.iloc[tr], y.iloc[tr])
    predictions = model.predict(x.iloc[te])
    results = {
        "training_framework": "Hulka centralized offline research",
        "clinical_deployment_approved": False,
        "n_train": len(tr), "n_test": len(te),
        "split": "group_holdout" if args.group else "stratified_random",
        "classification_report": classification_report(y.iloc[te], predictions,
                                                      output_dict=True, zero_division=0),
        "confusion_matrix": confusion_matrix(y.iloc[te], predictions).tolist(),
        "approval_reference": approval.get("approval_reference", "unspecified")
    }
    if len(set(y.iloc[te])) == 2:
        results["roc_auc"] = float(roc_auc_score(
            y.iloc[te], model.predict_proba(x.iloc[te])[:, 1]))
    out = Path(args.output)
    out.mkdir(parents=True, exist_ok=True)
    joblib.dump(model, out / "research_model.joblib")
    (out / "evaluation.json").write_text(json.dumps(results, indent=2))
    print(json.dumps(results, indent=2))

if __name__ == "__main__":
    main()
