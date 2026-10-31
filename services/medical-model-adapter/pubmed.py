"""Live PubMed metadata discovery for clinician research; no patient data in searches.
Results are *discovered literature*, not clinically approved Hulka guidance.
"""
import json
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

BASE = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils"
def find_papers(query: str, max_results: int = 8):
    if not 3 <= len(query) <= 140 or any(c in query for c in ("@", "\n", "\r")):
        raise ValueError("Provide a non-identifying scientific topic")
    args = urllib.parse.urlencode({"db":"pubmed","term":query,"retmode":"json",
                                  "retmax":min(max_results,10),"tool":"hulka_research"})
    with urllib.request.urlopen(BASE+"/esearch.fcgi?"+args, timeout=12) as stream:
        ids = json.load(stream)["esearchresult"]["idlist"]
    if not ids: return []
    params = urllib.parse.urlencode({"db":"pubmed","id":",".join(ids),"retmode":"xml"})
    with urllib.request.urlopen(BASE+"/efetch.fcgi?"+params,timeout=12) as stream:
        root = ET.fromstring(stream.read())
    results=[]
    for article in root.findall(".//PubmedArticle"):
        pmid = article.findtext(".//MedlineCitation/PMID")
        title = " ".join("".join(t.itertext()) for t in article.findall(".//ArticleTitle")).strip()
        journal = article.findtext(".//Journal/Title") or ""
        if pmid and title:
            results.append({"pmid":pmid,"title":title[:300],"journal":journal[:180],
                "url":"https://pubmed.ncbi.nlm.nih.gov/"+pmid+"/",
                "reviewStatus":"discovered_not_clinically_approved"})
    return results
