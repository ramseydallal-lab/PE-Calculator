from pathlib import Path
import csv
import math

BASE = Path("/Volumes/DallalMinix/ramseymini/Library/CloudStorage/OneDrive-ThomasJeffersonUniversityanditsAffiliates/_Enterprise/stats/Pulmonary Embolism/Locked/output")


def read_coefficients(filename):
    path = BASE / filename
    coefs = {}
    with path.open() as handle:
        for row in csv.DictReader(handle):
            coefs[row["term"]] = float(row["coef"])
    return coefs


def read_knots():
    knots = {}
    with (BASE / "106_calculator_knots.csv").open() as handle:
        for row in csv.DictReader(handle):
            knots[row["knot_name"]] = float(row["knot_value"])
    return knots


KNOWN_CPT3 = {
    191, 193, 225, 226, 234, 256, 271, 272, 274, 275, 278, 298, 326, 353,
    372, 432, 436, 437, 441, 442, 446, 449, 471, 475, 481, 495, 496, 505,
    522, 526, 558, 572, 581, 582, 585, 586, 595, 602, 605, 615, 630
}


def pooled_cpt3(code):
    cpt3 = int(str(code)[:3])
    return cpt3 if cpt3 in KNOWN_CPT3 else 999


def spline_basis(x, knots):
    k1 = knots["knot_25"]
    k2 = knots["knot_50"]
    k3 = knots["knot_75"]
    return {
        "wrvu_s1": min(x, k1),
        "wrvu_s2": max(min(x, k2) - k1, 0.0),
        "wrvu_s3": max(min(x, k3) - k2, 0.0),
        "wrvu_s4": max(x - k3, 0.0),
    }


def logistic(lp):
    return 1.0 / (1.0 + math.exp(-lp))


def add_common_terms(coefs, case, knots):
    lp = coefs["_cons"]
    if case["age"] > 1:
        lp += coefs.get(f"{case['age']}.age_cat", 0.0)
    if case["bmi"] > 1:
        lp += coefs.get(f"{case['bmi']}.bmi_cat", 0.0)
    if case["cancer"] == 1:
        lp += coefs.get("1.discancr_b", 0.0)
    if case["optime"] > 1:
        lp += coefs.get(f"{case['optime']}.optime_cat", 0.0)
    if case["los"] > 1:
        lp += coefs.get(f"{case['los']}.los3", 0.0)
    if case["asa"] > 1:
        lp += coefs.get(f"{case['asa']}.asaclas_id", 0.0)
    if case["inout"] > 1:
        lp += coefs.get(f"{case['inout']}.inout_id", 0.0)
    for term, value in spline_basis(case["wrvu"], knots).items():
        lp += coefs.get(term, 0.0) * value
    cpt3 = pooled_cpt3(case["cpt"])
    if cpt3 != 191:
        lp += coefs.get(f"{cpt3}.cpt3_pool", 0.0)
    return lp


if __name__ == "__main__":
    knots = read_knots()
    discharge = read_coefficients("106_calculator_coefficients_discharge.csv")
    update = read_coefficients("106_calculator_coefficients_update.csv")
    dvt = read_coefficients("106_calculator_coefficients_dvt.csv")
    vte = read_coefficients("106_calculator_coefficients_vte.csv")

    cases_path = BASE / "PE_Risk_Calculator_NSQIP_v3_validation_cases.csv"
    with cases_path.open() as handle:
        rows = list(csv.DictReader(handle))

    print("Loaded", len(rows), "validation cases from", cases_path)
    for row in rows:
        case = {
            "id": row["id"],
            "mode": row["mode"],
            "cpt": row["cpt"],
            "wrvu": float(row["wrvu"]),
            "age": int(row["age"]),
            "bmi": int(row["bmi"]),
            "asa": int(row["asa"]),
            "cancer": int(row["cancer"]),
            "optime": int(row["optime"]),
            "los": int(row["los"]),
            "inout": int(row["inout"]),
        }
        if case["mode"] == "discharge":
            pe = logistic(add_common_terms(discharge, case, knots))
            dvt_risk = logistic(add_common_terms(dvt, case, knots))
            vte_risk = logistic(add_common_terms(vte, case, knots))
            print(case["id"], "PE", f"{pe:.12f}", "DVT", f"{dvt_risk:.12f}", "VTE", f"{vte_risk:.12f}")
        else:
            case["readm"] = int(row["readm"])
            case["reop"] = int(row["reop"])
            lp = add_common_terms(update, case, knots)
            if case["readm"] > 0:
                lp += update.get(f"{case['readm']}.readm_when", 0.0)
            if case["reop"] > 0:
                lp += update.get(f"{case['reop']}.reop_when", 0.0)
            pe = logistic(lp)
            print(case["id"], "PE", f"{pe:.12f}")
