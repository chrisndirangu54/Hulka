# Hulka clinical model evaluation

Research tracks: **radiology/image understanding**, **microscopy**, and **antimicrobial susceptibility**. Each requires licensed representative datasets, split-by-patient and split-by-site holdouts, real clinician-adjudicated labels, sensitivity/specificity, subgroup analyses, failure-case review, calibration and prospective workflow evaluation. Confidence scores must not be presented as validated risk probabilities without calibration.

The `image_micro_eval.py` gate only checks evaluation documentation; it cannot certify an untested model or approve deployment. `evaluate_clinical.py` computes clinician acceptance, unsafe claim and fabricated citation rates from independently reviewed case files. These scripts are not proof of clinical-grade performance.

Google's MedGemma model card: https://developers.google.com/health-ai-developer-foundations/medgemma/model-card . MedGemma is a development foundation, not an approved clinical device. Use authorization-scoped FHIR R4 access with institutional agreements. Live PubMed discovery returns unreviewed bibliography only.
